from __future__ import annotations

import asyncio
from datetime import datetime, timezone


def _engineer_features(df):
    """Create ML features from OHLCV data."""
    import pandas as pd

    features = pd.DataFrame(index=df.index)

    # Returns at different horizons
    features["return_1d"] = df["close"].pct_change(1)
    features["return_3d"] = df["close"].pct_change(3)
    features["return_7d"] = df["close"].pct_change(7)

    # Volatility
    features["volatility_5d"] = df["close"].pct_change().rolling(5).std()
    features["volatility_20d"] = df["close"].pct_change().rolling(20).std()

    # RSI
    delta = df["close"].diff()
    gain = delta.where(delta > 0, 0).rolling(14).mean()
    loss = (-delta.where(delta < 0, 0)).rolling(14).mean()
    rs = gain / (loss + 1e-10)
    features["rsi_14"] = 100 - (100 / (1 + rs))

    # MACD
    ema12 = df["close"].ewm(span=12).mean()
    ema26 = df["close"].ewm(span=26).mean()
    features["macd"] = (ema12 - ema26) / df["close"]
    features["macd_signal"] = features["macd"].ewm(span=9).mean()

    # Bollinger position
    ma20 = df["close"].rolling(20).mean()
    std20 = df["close"].rolling(20).std()
    features["bb_position"] = (df["close"] - ma20) / (std20 * 2 + 1e-10)

    # Volume features
    features["volume_ratio"] = df["volume"] / df["volume"].rolling(20).mean()
    features["volume_change"] = df["volume"].pct_change(5)

    # Price vs moving averages
    features["price_vs_ma20"] = (df["close"] - ma20) / (ma20 + 1e-10)
    features["price_vs_ma50"] = (df["close"] - df["close"].rolling(50).mean()) / (df["close"].rolling(50).mean() + 1e-10)

    # High-low range
    features["hl_range"] = (df["high"] - df["low"]) / (df["close"] + 1e-10)

    return features.dropna()


async def _real_training(run, db) -> None:
    """Train a real LightGBM model on market data."""
    import lightgbm as lgb
    import numpy as np
    import pandas as pd
    from pathlib import Path
    import joblib

    cfg = run.training_config or {}
    model_name = run.model_name or "lightgbm"
    symbol = cfg.get("symbol", "BTC/USDT")
    timeframe = cfg.get("timeframe", "1h")
    training_candles = cfg.get("training_candles", 1000)
    epochs = cfg.get("epochs", 100)

    # 1. Fetch data
    from app.services.market_data import market_data_service
    ohlcv = await market_data_service.get_ohlcv(symbol, timeframe, training_candles)

    if len(ohlcv) < 100:
        raise ValueError(f"Insufficient data: only {len(ohlcv)} candles (need 100+)")

    df = pd.DataFrame(ohlcv)

    # 2. Progress: 25%
    run.metrics = {"progress": 25, "status": "engineering_features", "model_name": model_name}
    db.commit()

    # 3. Engineer features
    features = _engineer_features(df)

    # 4. Create labels (next candle direction)
    labels = (df["close"].shift(-1) > df["close"]).astype(int)
    labels = labels.loc[features.index]
    features = features.loc[labels.index]

    # Remove last row (no future return)
    features = features.iloc[:-1]
    labels = labels.iloc[:-1]

    if len(features) < 50:
        raise ValueError(f"Insufficient features after engineering: {len(features)}")

    # 5. Train/test split (80/20)
    split_idx = int(len(features) * 0.8)
    X_train, X_test = features.iloc[:split_idx], features.iloc[split_idx:]
    y_train, y_test = labels.iloc[:split_idx], labels.iloc[split_idx:]

    # 6. Progress: 50%
    run.metrics = {"progress": 50, "status": "training", "model_name": model_name, "samples": len(X_train)}
    db.commit()

    # 7. Train LightGBM
    train_data = lgb.Dataset(X_train, label=y_train)
    valid_data = lgb.Dataset(X_test, label=y_test, reference=train_data)

    params = {
        "objective": "binary",
        "metric": "binary_logloss",
        "verbosity": -1,
        "num_leaves": 31,
        "feature_fraction": 0.8,
        "bagging_fraction": 0.8,
        "bagging_freq": 5,
        "learning_rate": 0.05,
    }

    callbacks = [
        lgb.log_evaluation(period=0),  # silent
    ]

    model = lgb.train(
        params,
        train_data,
        num_boost_round=epochs,
        valid_sets=[valid_data],
        callbacks=callbacks,
    )

    # 8. Progress: 75%
    run.metrics = {"progress": 75, "status": "evaluating", "model_name": model_name}
    db.commit()

    # 9. Evaluate
    y_pred_prob = model.predict(X_test)
    y_pred = (y_pred_prob > 0.5).astype(int)

    accuracy = float(np.mean(y_pred == y_test.values))
    logloss = float(-np.mean(
        y_test.values * np.log(y_pred_prob + 1e-10) +
        (1 - y_test.values) * np.log(1 - y_pred_prob + 1e-10)
    ))

    # Precision/recall
    tp = int(np.sum((y_pred == 1) & (y_test.values == 1)))
    fp = int(np.sum((y_pred == 1) & (y_test.values == 0)))
    fn = int(np.sum((y_pred == 0) & (y_test.values == 1)))

    precision = tp / (tp + fp + 1e-10)
    recall = tp / (tp + fn + 1e-10)
    f1 = 2 * precision * recall / (precision + recall + 1e-10)

    # Feature importance
    importance = model.feature_importance(importance_type="gain")
    total_imp = importance.sum()
    feature_importance = {
        name: round(float(imp / total_imp), 4)
        for name, imp in zip(features.columns, importance)
    }

    # 10. Save model
    model_dir = Path("data/freqai_models")
    model_dir.mkdir(parents=True, exist_ok=True)
    model_path = model_dir / f"run_{run.id}.pkl"
    joblib.dump(model, str(model_path))

    # 11. Write final metrics
    run.metrics = {
        "accuracy": round(accuracy, 4),
        "loss": round(logloss, 4),
        "precision": round(precision, 4),
        "recall": round(recall, 4),
        "f1_score": round(f1, 4),
        "epochs": epochs,
        "training_samples": len(X_train),
        "test_samples": len(X_test),
        "feature_importance": feature_importance,
        "model_path": str(model_path),
        "symbol": symbol,
        "timeframe": timeframe,
    }
    db.commit()


async def freqai_worker_loop(engine) -> None:
    from sqlalchemy.orm import sessionmaker
    from app.models.ai import FreqAIRun

    SessionLocal = sessionmaker(bind=engine)
    while True:
        await asyncio.sleep(5)
        db = SessionLocal()
        try:
            run = db.query(FreqAIRun).filter(FreqAIRun.status == "queued").order_by(FreqAIRun.created_at.asc()).first()
            if not run:
                continue
            run.status = "running"
            run.started_at = datetime.now(timezone.utc)
            db.commit()
            try:
                await _real_training(run, db)

                run.status = "completed"
                run.completed_at = datetime.now(timezone.utc)
                db.commit()
            except Exception as exc:
                run.status = "failed"
                run.completed_at = datetime.now(timezone.utc)
                run.metrics = {"error": str(exc)}
                db.commit()
        except Exception:
            pass
        finally:
            db.close()
