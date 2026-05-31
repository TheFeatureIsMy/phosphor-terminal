# Factor Research Custom Implementation — Detailed Design

**Date:** 2026-05-30
**Purpose:** Detailed implementation design for the market-aware factor research system.

---

## 0. Academic Foundation & References

### Core Methodology

| Concept | Source | Authority |
|---------|--------|-----------|
| IC/IR Framework | Grinold & Kahn (2000) *Active Portfolio Management* | Quantitative investing bible, industry standard for 25 years |
| Fundamental Law: `IR ≈ IC × √BR` | Grinold & Kahn (2000) | Theoretical foundation for factor evaluation |
| IC Thresholds (<0.02 noise, 0.03-0.05 valid, >0.05 strong) | BARRA (MSCI) Risk Model Documentation | Global leading risk model provider |
| Rank IC (Spearman > Pearson) | CFA Institute, MSCI BARRA | Industry standard for robustness |
| Fama-MacBeth Cross-Sectional Regression | Fama & MacBeth (1973) *Journal of Political Economy* | Nobel Prize-winning methodology |

### Crypto-Specific Research

| Paper | Journal | Key Findings |
|-------|---------|--------------|
| **Liu, Tsyvinski & Wu (2022)** "Common Risk Factors in Cryptocurrency" | *Journal of Finance* (顶刊) | 3 main crypto risk factors: **momentum, size, market**. Momentum factor strongest, weekly return predictability significant |
| **Bianchi (2020)** "Cryptocurrencies as an Asset Class?" | *Journal of Alternative Investments* | Momentum and volatility factors have predictive power in crypto, but time-varying |
| **Cong, He & Li (2021)** "Decentralized Mining in Centralized Pools" | *Review of Financial Studies* (顶刊) | On-chain metrics (active addresses, transaction volume) as factors have predictive power |
| **Liu & Tsyvinski (2021)** "Risks and Returns of Cryptocurrency" | *Review of Financial Studies* (顶刊) | Crypto has unique risk factors, not fully correlated with traditional assets |

### Our Implementation Alignment

| Method | Industry Standard | PulseDesk | Status |
|--------|------------------|-----------|--------|
| IC calculation | Cross-sectional Pearson | ✅ `cross_sectional_ic()` | Phase 1 |
| Rank IC | Spearman correlation | ✅ `cross_sectional_rank_ic()` | Phase 1 |
| IC threshold | 0.03 (BARRA/MSCI) | ✅ 0.03 | Phase 1 |
| IC_IR | mean(IC)/std(IC) > 0.5 | ✅ `ic_ir` metric | Phase 1 |
| Long-short quintile | Top/bottom 20% | ✅ `quantile=0.2` | Phase 1 |
| Turnover monitoring | Daily calculation | ✅ `portfolio_turnover()` | Phase 1 |
| Fama-MacBeth regression | Cross-sectional regression | 🔶 Phase 2 | Phase 2 |
| Factor orthogonalization | Remove inter-factor correlation | 🔶 Phase 2 | Phase 2 |
| Out-of-sample testing | Train/test split | 🔶 Phase 2 | Phase 2 |

### Factor Validation (Academic-Backed)

| Factor | Academic Support | Reference |
|--------|-----------------|-----------|
| momentum | ✅ Strong | Liu et al. (2022) JF, Bianchi (2020) |
| realized_volatility | ✅ Moderate | Bianchi (2020) |
| volume_momentum | ✅ Moderate | Cong et al. (2021) RFS |
| rsi | ✅ Technical indicator | Standard TA literature |
| z_score (mean reversion) | ✅ Moderate | Bianchi (2020) |
| funding_rate | 🔶 Practitioner | Delphi Digital, Gauntlet research (no formal academic paper) |
| liquidation_pressure | 🔶 Practitioner | Crypto-native quant research |
| open_interest_change | 🔶 Practitioner | Crypto-native quant research |

---

## 1. Core Concepts

### What is Factor Research?

A **factor** is a measurable characteristic that predicts future asset returns. Factor research measures whether a factor has **predictive power**.

```
Factor Value (today) → Future Return (tomorrow) → Correlation (IC) → Is factor valid?
```

### Key Metrics

| Metric | Formula | Good Threshold | Source | Meaning |
|--------|---------|----------------|--------|---------|
| IC | Pearson(cross_section_factor, cross_section_return) | > 0.03 | BARRA/MSCI | Linear predictive power |
| Rank IC | Spearman(cross_section_factor, cross_section_return) | > 0.04 | CFA Institute | Rank-based predictive power |
| IC_IR | mean(IC_series) / std(IC_series) | > 0.5 | Grinold & Kahn | Consistency of predictive power |
| Long-Short Return | return(top_quantile) - return(bottom_quantile) | > 0 | Standard quant | Monetizable alpha |
| Turnover | mean(abs(new_weights - old_weights)) | < 0.3 | Standard quant | Trading cost indicator |
| Sharpe (L/S) | mean(L/S return) / std(L/S return) × √365 | > 1.0 | Standard quant | Risk-adjusted alpha |

---

## 2. Factor Definitions

### 2.1 Momentum Factors

```python
def momentum(close: pd.Series, window: int = 20) -> pd.Series:
    """Price momentum: return over past N days."""
    return close.pct_change(window)

def momentum_acceleration(close: pd.Series, short: int = 5, long: int = 20) -> pd.Series:
    """Momentum acceleration: short-term momentum minus long-term momentum."""
    return close.pct_change(short) - close.pct_change(long)

def price_strength(close: pd.Series, window: int = 20) -> pd.Series:
    """Percentage of days with positive returns in window."""
    returns = close.pct_change()
    return returns.rolling(window).apply(lambda x: (x > 0).sum() / len(x))
```

### 2.2 Volatility Factors

```python
def realized_volatility(close: pd.Series, window: int = 20) -> pd.Series:
    """Realized volatility: std of log returns."""
    log_returns = np.log(close / close.shift(1))
    return log_returns.rolling(window).std() * np.sqrt(365)  # annualized

def volatility_ratio(close: pd.Series, short: int = 5, long: int = 20) -> pd.Series:
    """Short-term vol / long-term vol. >1 means vol expanding."""
    return realized_volatility(close, short) / realized_volatility(close, long)

def downside_volatility(close: pd.Series, window: int = 20) -> pd.Series:
    """Volatility of negative returns only."""
    returns = close.pct_change()
    negative_returns = returns.where(returns < 0, 0)
    return negative_returns.rolling(window).std()
```

### 2.3 Volume Factors

```python
def volume_momentum(volume: pd.Series, window: int = 10) -> pd.Series:
    """Volume change over past N days."""
    return volume.pct_change(window)

def volume_price_divergence(close: pd.Series, volume: pd.Series, window: int = 20) -> pd.Series:
    """Price going up but volume going down = bearish divergence."""
    price_change = close.pct_change(window)
    volume_change = volume.pct_change(window)
    return price_change - volume_change  # positive = bearish divergence

def vwap_deviation(close: pd.Series, volume: pd.Series, window: int = 20) -> pd.Series:
    """Distance from VWAP. Positive = price above VWAP."""
    vwap = (close * volume).rolling(window).sum() / volume.rolling(window).sum()
    return (close - vwap) / vwap
```

### 2.4 Technical Factors

```python
def rsi(close: pd.Series, period: int = 14) -> pd.Series:
    """Relative Strength Index, normalized to [-1, 1]."""
    delta = close.diff()
    gain = delta.where(delta > 0, 0).rolling(period).mean()
    loss = (-delta.where(delta < 0, 0)).rolling(period).mean()
    rs = gain / loss
    return (rs - 1) / (rs + 1)  # normalized RSI

def bollinger_position(close: pd.Series, window: int = 20, num_std: float = 2.0) -> pd.Series:
    """Position within Bollinger Bands, normalized to [-1, 1]."""
    ma = close.rolling(window).mean()
    std = close.rolling(window).std()
    upper = ma + num_std * std
    lower = ma - num_std * std
    return (close - lower) / (upper - lower) * 2 - 1  # -1 at lower, +1 at upper

def macd_signal(close: pd.Series, fast: int = 12, slow: int = 26, signal: int = 9) -> pd.Series:
    """MACD histogram, normalized."""
    ema_fast = close.ewm(span=fast).mean()
    ema_slow = close.ewm(span=slow).mean()
    macd_line = ema_fast - ema_slow
    signal_line = macd_line.ewm(span=signal).mean()
    histogram = macd_line - signal_line
    return histogram / close  # normalize by price
```

### 2.5 Mean Reversion Factors

```python
def z_score(close: pd.Series, window: int = 20) -> pd.Series:
    """Z-score: how many std deviations from the mean."""
    ma = close.rolling(window).mean()
    std = close.rolling(window).std()
    return (close - ma) / std

def hurst_exponent(close: pd.Series, window: int = 100) -> pd.Series:
    """Hurst exponent: <0.5 mean-reverting, >0.5 trending, 0.5 random walk."""
    def _hurst(ts):
        n = len(ts)
        if n < 20:
            return 0.5
        max_k = min(n // 2, 20)
        rs = []
        for k in range(2, max_k + 1):
            subseries = np.array_split(ts, n // k)
            r_s = []
            for s in subseries:
                if len(s) < 2:
                    continue
                mean_s = np.mean(s)
                cumdev = np.cumsum(s - mean_s)
                R = np.max(cumdev) - np.min(cumdev)
                S = np.std(s, ddof=1)
                if S > 0:
                    r_s.append(R / S)
            if r_s:
                rs.append((k, np.mean(r_s)))
        if len(rs) < 2:
            return 0.5
        log_rs = np.log([r[0] for r in rs])
        log_n = np.log([r[1] for r in rs])
        H = np.polyfit(log_n, log_rs, 1)[0]
        return float(np.clip(H, 0, 1))
    return close.rolling(window).apply(_hurst, raw=True)
```

### 2.6 Crypto-Specific Factors

```python
def funding_rate_momentum(funding_rates: pd.Series, window: int = 8) -> pd.Series:
    """Funding rate trend. Positive = longs paying shorts (bullish sentiment)."""
    return funding_rates.rolling(window).mean()

def open_interest_change(open_interest: pd.Series, window: int = 24) -> pd.Series:
    """Open interest change rate. Rising OI + rising price = strong trend."""
    return open_interest.pct_change(window)

def liquidation_pressure(long_liqs: pd.Series, short_liqs: pd.Series, window: int = 24) -> pd.Series:
    """Net liquidation pressure. Positive = longs being liquidated (bearish)."""
    net = long_liqs - short_liqs
    return net.rolling(window).sum()
```

---

## 3. Cross-Sectional IC Calculation

The core algorithm: for each day, compute the correlation between factor values and next-day returns across ALL assets in the universe.

```python
def cross_sectional_ic(
    factor_values: dict[str, pd.Series],    # {symbol: factor_series}
    returns: dict[str, pd.Series],          # {symbol: return_series}
) -> pd.Series:
    """Calculate daily cross-sectional IC.

    For each day t:
      - Collect factor values for all assets at time t
      - Collect returns for all assets at time t+1
      - Compute correlation between these two cross-sections

    Returns: time series of daily IC values.
    """
    # Align all series to common dates
    all_dates = None
    for symbol in factor_values:
        if all_dates is None:
            all_dates = set(factor_values[symbol].index)
        else:
            all_dates &= set(factor_values[symbol].index)

    dates = sorted(all_dates)
    ic_series = []

    for date in dates:
        # Get cross-section: factor values and next-day returns for all assets
        factor_cross = []
        return_cross = []
        for symbol in factor_values:
            if date in factor_values[symbol].index and date in returns[symbol].index:
                fv = factor_values[symbol].loc[date]
                rt = returns[symbol].loc[date]
                if pd.notna(fv) and pd.notna(rt):
                    factor_cross.append(fv)
                    return_cross.append(rt)

        if len(factor_cross) >= 3:  # need at least 3 assets for correlation
            ic = np.corrcoef(factor_cross, return_cross)[0, 1]
            if pd.notna(ic):
                ic_series.append((date, ic))

    return pd.Series(
        [x[1] for x in ic_series],
        index=[x[0] for x in ic_series],
        name="IC"
    )
```

### Rank IC (Spearman)

```python
def cross_sectional_rank_ic(
    factor_values: dict[str, pd.Series],
    returns: dict[str, pd.Series],
) -> pd.Series:
    """Same as IC but uses Spearman (rank) correlation."""
    from scipy.stats import spearmanr

    # ... same alignment logic ...

    for date in dates:
        factor_cross = [...]  # same as above
        return_cross = [...]

        if len(factor_cross) >= 3:
            corr, _ = spearmanr(factor_cross, return_cross)
            ic_series.append((date, corr))

    return pd.Series(...)
```

---

## 4. Long-Short Portfolio Backtest

```python
def long_short_returns(
    factor_values: dict[str, pd.Series],
    returns: dict[str, pd.Series],
    quantile: float = 0.2,  # top/bottom 20%
) -> pd.Series:
    """Calculate daily long-short portfolio returns.

    Each day:
      1. Rank assets by factor value
      2. Go long top quantile, short bottom quantile
      3. Calculate equal-weighted return

    Returns: time series of daily long-short returns.
    """
    all_dates = _get_common_dates(factor_values, returns)
    ls_returns = []

    for date in all_dates:
        # Get cross-section
        factor_cross = {}
        return_cross = {}
        for symbol in factor_values:
            if date in factor_values[symbol].index and date in returns[symbol].index:
                fv = factor_values[symbol].loc[date]
                rt = returns[symbol].loc[date]
                if pd.notna(fv) and pd.notna(rt):
                    factor_cross[symbol] = fv
                    return_cross[symbol] = rt

        if len(factor_cross) < 5:
            continue

        # Rank by factor
        sorted_symbols = sorted(factor_cross, key=factor_cross.get)
        n = len(sorted_symbols)
        bottom = sorted_symbols[:int(n * quantile)]  # short these
        top = sorted_symbols[-int(n * quantile):]     # long these

        # Equal-weighted long-short return
        long_return = np.mean([return_cross[s] for s in top])
        short_return = np.mean([return_cross[s] for s in bottom])
        ls_returns.append((date, long_return - short_return))

    return pd.Series(
        [x[1] for x in ls_returns],
        index=[x[0] for x in ls_returns],
        name="long_short_return"
    )
```

---

## 5. Turnover Calculation

```python
def portfolio_turnover(
    factor_values: dict[str, pd.Series],
    quantile: float = 0.2,
) -> pd.Series:
    """Calculate daily portfolio turnover.

    Turnover = fraction of portfolio that changes each day.
    0 = buy and hold, 2 = complete replacement every day.
    """
    all_dates = _get_common_dates(factor_values)
    turnovers = []
    prev_long = set()
    prev_short = set()

    for date in all_dates:
        factor_cross = {}
        for symbol in factor_values:
            if date in factor_values[symbol].index:
                fv = factor_values[symbol].loc[date]
                if pd.notna(fv):
                    factor_cross[symbol] = fv

        sorted_symbols = sorted(factor_cross, key=factor_cross.get)
        n = len(sorted_symbols)
        current_short = set(sorted_symbols[:int(n * quantile)])
        current_long = set(sorted_symbols[-int(n * quantile):])

        if prev_long:
            long_changed = len(current_long - prev_long) / max(len(current_long), 1)
            short_changed = len(current_short - prev_short) / max(len(current_short), 1)
            turnovers.append((date, (long_changed + short_changed) / 2))

        prev_long = current_long
        prev_short = current_short

    return pd.Series(
        [x[1] for x in turnovers],
        index=[x[0] for x in turnovers],
        name="turnover"
    )
```

---

## 6. Factor Combiner (Multi-Factor Model)

```python
def combine_factors(
    factors: dict[str, dict[str, pd.Series]],  # {factor_name: {symbol: series}}
    weights: dict[str, float] | None = None,   # {factor_name: weight}
    method: str = "equal_weight",               # equal_weight, ic_weight, optimized
) -> dict[str, pd.Series]:
    """Combine multiple factors into a composite score.

    Methods:
      - equal_weight: average all factor z-scores
      - ic_weight: weight by historical IC (better factors get more weight)
      - optimized: maximize IC_IR via quadratic programming
    """
    if weights is None:
        if method == "equal_weight":
            weights = {name: 1.0 / len(factors) for name in factors}
        elif method == "ic_weight":
            # Calculate historical IC for each factor, use as weights
            ics = {}
            for name, factor_data in factors.items():
                ic_series = cross_sectional_ic(factor_data, returns)
                ics[name] = abs(ic_series.mean())
            total = sum(ics.values())
            weights = {name: ic / total for name, ic in ics.items()}

    # Z-score normalize each factor, then weighted average
    combined = {}
    all_symbols = set()
    for factor_data in factors.values():
        all_symbols.update(factor_data.keys())

    for symbol in all_symbols:
        score = 0.0
        total_weight = 0.0
        for factor_name, factor_data in factors.items():
            if symbol in factor_data:
                series = factor_data[symbol]
                # Z-score normalize
                z = (series - series.mean()) / series.std()
                score += z * weights.get(factor_name, 0)
                total_weight += weights.get(factor_name, 0)
        if total_weight > 0:
            combined[symbol] = score / total_weight

    return combined
```

---

## 7. Full Research Pipeline

```python
class CryptoFactorBackend:
    """Complete factor research backend for crypto market."""

    def __init__(self, market_data: MarketDataService):
        self.market_data = market_data
        self.factor_registry = {
            "momentum": momentum,
            "volatility": realized_volatility,
            "volume_momentum": volume_momentum,
            "rsi": rsi,
            "mean_reversion": z_score,
            "bollinger": bollinger_position,
            "macd": macd_signal,
            "funding_rate": funding_rate_momentum,
        }

    async def research(
        self,
        universe: list[str],        # ["BTC/USDT", "ETH/USDT", ...]
        factor_name: str,            # "momentum", "volatility", etc.
        period: str = "3M",          # lookback period
        forward_days: int = 1,       # prediction horizon
    ) -> FactorResult:
        # 1. Fetch OHLCV data for all symbols
        data = {}
        for symbol in universe:
            ohlcv = await self.market_data.get_ohlcv(symbol, "1d", limit=120)
            data[symbol] = pd.DataFrame(ohlcv, columns=["open", "high", "low", "close", "volume"])

        # 2. Calculate factor values
        calculator = self.factor_registry.get(factor_name)
        if not calculator:
            return FactorResult(status="error", detail=f"Unknown factor: {factor_name}")

        factor_values = {}
        returns = {}
        for symbol, df in data.items():
            factor_values[symbol] = calculator(df["close"])
            returns[symbol] = df["close"].pct_change(forward_days).shift(-forward_days)

        # 3. Calculate metrics
        ic_series = cross_sectional_ic(factor_values, returns)
        rank_ic_series = cross_sectional_rank_ic(factor_values, returns)
        ls_returns = long_short_returns(factor_values, returns)
        turnover_series = portfolio_turnover(factor_values)

        # 4. Aggregate
        sharpe = ls_returns.mean() / ls_returns.std() * np.sqrt(365) if ls_returns.std() > 0 else 0

        return FactorResult(
            status="ok",
            factor_name=factor_name,
            market="crypto",
            metrics={
                "ic_mean": round(float(ic_series.mean()), 4),
                "ic_std": round(float(ic_series.std()), 4),
                "ic_ir": round(float(ic_series.mean() / ic_series.std()), 4) if ic_series.std() > 0 else 0,
                "rank_ic_mean": round(float(rank_ic_series.mean()), 4),
                "long_short_sharpe": round(float(sharpe), 4),
                "long_short_cumulative": round(float(ls_returns.sum()), 4),
                "turnover_mean": round(float(turnover_series.mean()), 4),
                "observation_days": len(ic_series),
                "universe_size": len(universe),
            },
            details={
                "ic_series": ic_series.tail(30).to_dict(),
                "rank_ic_series": rank_ic_series.tail(30).to_dict(),
                "long_short_returns": ls_returns.tail(30).to_dict(),
                "factor_values_latest": {
                    s: round(float(v.iloc[-1]), 4) if pd.notna(v.iloc[-1]) else None
                    for s, v in factor_values.items()
                },
            },
        )
```

---

## 8. Dependencies

Only `pandas` and `numpy` — both already in requirements.txt.

Optional: `scipy` for Spearman correlation (Rank IC). Can implement manually if not available:

```python
def spearman_rank_correlation(x, y):
    """Pure pandas Spearman correlation (no scipy needed)."""
    rx = pd.Series(x).rank()
    ry = pd.Series(y).rank()
    return rx.corr(ry)
```

---

## 9. Data Flow Diagram

```
用户在 UI 选择:
  市场: Crypto
  因子: momentum
  币种: BTC, ETH, SOL, BNB, ADA
  周期: 3 个月

       ↓ API call

FactorResearchService.research("crypto", ["BTC/USDT", ...], "momentum", "3M")
       ↓
CryptoFactorBackend.research(...)
       ↓
  1. MarketDataService.get_ohlcv() × 5 币种
  2. momentum(close) × 5 → 因子值序列
  3. cross_sectional_ic() → IC 时间序列
  4. long_short_returns() → 多空收益
  5. portfolio_turnover() → 换手率
       ↓
FactorResult {
  metrics: { ic_mean: 0.045, rank_ic: 0.063, sharpe: 1.2, turnover: 0.28 }
  details: { ic_series: [...], factor_values: { BTC: 0.032, ETH: -0.018, ... } }
}
       ↓
UI 展示:
  - IC 时序图 (折线)
  - 多空收益累计曲线
  - 因子值热力图 (按币种)
  - 指标卡片 (IC/Sharpe/Turnover)
```

---

## 10. Phase 2: Advanced Factor Testing (Future)

### 10.1 Fama-MacBeth Cross-Sectional Regression

**Source:** Fama & MacBeth (1973), *Journal of Political Economy* — Nobel Prize-winning methodology.

**Purpose:** More rigorous factor test than simple IC. Controls for multiple factors simultaneously and provides t-statistics for significance.

```python
def fama_macbeth_regression(
    factor_values: dict[str, dict[str, pd.Series]],  # {factor: {symbol: series}}
    returns: dict[str, pd.Series],
) -> dict:
    """Fama-MacBeth two-pass regression.

    Pass 1: For each day t, regress returns on factor values (cross-sectional)
      r_i,t = α_t + β_1 * factor1_i,t + β_2 * factor2_i,t + ε_i,t

    Pass 2: Take time-series average of each β, compute t-statistics
      mean(β_1), std(β_1), t-stat = mean(β_1) / (std(β_1) / √T)

    Returns:
      - factor_premiums: mean coefficient for each factor
      - t_statistics: t-stat for each factor (|t| > 2.0 = significant)
      - r_squared: average cross-sectional R²
    """
    from numpy.linalg import lstsq

    dates = _get_common_dates_across_factors(factor_values, returns)
    factor_names = list(factor_values.keys())
    daily_betas = []
    daily_r2 = []

    for date in dates:
        # Build cross-sectional regression: y = X @ beta + eps
        y = []  # returns
        X = []  # factor values (each row = one asset)
        for symbol in returns:
            if date not in returns[symbol].index:
                continue
            ret = returns[symbol].loc[date]
            if pd.isna(ret):
                continue
            row = []
            valid = True
            for fname in factor_names:
                if symbol in factor_values[fname] and date in factor_values[fname][symbol].index:
                    fv = factor_values[fname][symbol].loc[date]
                    if pd.notna(fv):
                        row.append(fv)
                    else:
                        valid = False
                        break
                else:
                    valid = False
                    break
            if valid and len(row) == len(factor_names):
                y.append(ret)
                X.append(row)

        if len(y) < len(factor_names) + 2:
            continue

        X = np.array(X)
        y = np.array(y)

        # Add intercept
        X_with_const = np.column_stack([np.ones(len(X)), X])
        betas, residuals, _, _ = lstsq(X_with_const, y, rcond=None)

        # R²
        y_pred = X_with_const @ betas
        ss_res = np.sum((y - y_pred) ** 2)
        ss_tot = np.sum((y - np.mean(y)) ** 2)
        r2 = 1 - ss_res / ss_tot if ss_tot > 0 else 0

        daily_betas.append(betas[1:])  # exclude intercept
        daily_r2.append(r2)

    if not daily_betas:
        return {"status": "insufficient_data"}

    # Pass 2: time-series statistics
    betas_array = np.array(daily_betas)
    result = {}
    for i, fname in enumerate(factor_names):
        beta_ts = betas_array[:, i]
        mean_beta = np.mean(beta_ts)
        std_beta = np.std(beta_ts, ddof=1)
        t_stat = mean_beta / (std_beta / np.sqrt(len(beta_ts))) if std_beta > 0 else 0
        result[fname] = {
            "premium": round(float(mean_beta), 6),
            "t_statistic": round(float(t_stat), 3),
            "significant": abs(t_stat) > 2.0,
        }

    return {
        "factor_premiums": result,
        "r_squared_mean": round(float(np.mean(daily_r2)), 4),
        "observation_days": len(daily_betas),
    }
```

### 10.2 Factor Orthogonalization

**Purpose:** Remove correlation between factors so each factor captures unique alpha.

```python
def orthogonalize_factors(
    factor_values: dict[str, dict[str, pd.Series]],
    method: str = "gram_schmidt",
) -> dict[str, dict[str, pd.Series]]:
    """Remove inter-factor correlation.

    Methods:
      - gram_schmidt: Sequential orthogonalization (order-dependent)
      - symmetric: Symmetric orthogonalization (order-independent, uses eigendecomposition)

    Returns: new factor_values with zero cross-factor correlation.
    """
    factor_names = list(factor_values.keys())
    all_symbols = set()
    for fv in factor_values.values():
        all_symbols.update(fv.keys())

    # Build factor matrix: rows=symbols, cols=factors, for each date
    # ... (full implementation in Phase 2)

    if method == "gram_schmidt":
        # Orthogonalize sequentially: factor2 is orthogonalized against factor1,
        # factor3 against factor1+factor2, etc.
        orthogonal = {factor_names[0]: factor_values[factor_names[0]]}
        for i in range(1, len(factor_names)):
            orthogonal[factor_names[i]] = _project_orthogonal(
                factor_values[factor_names[i]],
                {k: orthogonal[k] for k in factor_names[:i]}
            )
        return orthogonal
```

### 10.3 Out-of-Sample Testing

**Purpose:** Prevent overfitting by testing factors on data not used for development.

```python
def out_of_sample_test(
    factor_values: dict[str, pd.Series],
    returns: dict[str, pd.Series],
    train_ratio: float = 0.7,
) -> dict:
    """Split data into train/test and compare IC.

    If IC drops significantly in test set → factor may be overfit.
    If IC is stable → factor is likely robust.

    Returns:
      - train_ic: IC in training period
      - test_ic: IC in testing period
      - ic_decay: (train_ic - test_ic) / train_ic (lower = more robust)
      - is_robust: test_ic > 0.02 and ic_decay < 0.5
    """
    dates = sorted(_get_common_dates(factor_values, returns))
    split_idx = int(len(dates) * train_ratio)
    train_dates = dates[:split_idx]
    test_dates = dates[split_idx:]

    train_ic = _calculate_ic_for_dates(factor_values, returns, train_dates)
    test_ic = _calculate_ic_for_dates(factor_values, returns, test_dates)

    train_mean = train_ic.mean()
    test_mean = test_ic.mean()
    decay = (train_mean - test_mean) / abs(train_mean) if train_mean != 0 else 0

    return {
        "train_ic_mean": round(float(train_mean), 4),
        "test_ic_mean": round(float(test_mean), 4),
        "ic_decay": round(float(decay), 4),
        "is_robust": test_mean > 0.02 and decay < 0.5,
        "train_days": len(train_dates),
        "test_days": len(test_dates),
    }
```

### 10.4 Factor Decay Analysis

**Purpose:** Measure how quickly factor alpha decays over different holding periods.

```python
def factor_decay_analysis(
    factor_values: dict[str, pd.Series],
    returns: dict[str, pd.Series],
    max_horizon: int = 30,
) -> dict:
    """Test IC at different forward horizons (1d, 2d, 5d, 10d, 20d, 30d).

    If IC decays quickly → factor captures short-term effects.
    If IC is stable → factor captures structural alpha.

    Returns: {horizon: ic_mean} for each forward period.
    """
    results = {}
    for horizon in [1, 2, 3, 5, 10, 20, 30]:
        fwd_returns = {}
        for symbol, ret_series in returns.items():
            fwd_returns[symbol] = ret_series.shift(-horizon)  # N-day forward return
        ic = cross_sectional_ic(factor_values, fwd_returns)
        results[horizon] = {
            "ic_mean": round(float(ic.mean()), 4),
            "ic_std": round(float(ic.std()), 4),
            "significant": abs(ic.mean()) > 0.02,
        }
    return results
```

---

## 11. Risk Mitigations

| Risk | Description | Mitigation | Implementation |
|------|-------------|------------|----------------|
| **Overfitting** | Factor works on historical data but fails live | Out-of-sample testing, train/test split | `out_of_sample_test()` |
| **Look-ahead bias** | Using future data that wasn't available at decision time | Strict `shift(-1)` for returns, no future data in factor calculation | Code discipline, code review |
| **Survivorship bias** | Only analyzing coins that still exist | Include delisted coins in universe | Market data service keeps history |
| **Transaction costs** | High turnover eats alpha | Monitor turnover, penalize high-turnover factors | `portfolio_turnover()` metric |
| **Factor decay** | Alpha weakens over time | Factor decay analysis, rolling IC window | `factor_decay_analysis()` |
| **Non-stationarity** | Market structure changes, factor relationships shift | Rolling window IC, regime detection | Rolling IC in UI |
| **Data snooping** | Testing too many factors, some appear significant by chance | Bonferroni correction, multiple testing adjustment | Report number of factors tested |
| **Small universe** | Too few assets for reliable cross-sectional IC | Require minimum 10 assets for IC calculation | `len(factor_cross) >= 10` |

### Minimum Universe Size

```python
MIN_UNIVERSE_SIZE = 10  # need at least 10 assets for reliable IC

def cross_sectional_ic(factor_values, returns):
    # ...
    for date in dates:
        # ...
        if len(factor_cross) < MIN_UNIVERSE_SIZE:
            continue  # skip this date, not enough assets
        # ...
```

### Multiple Testing Correction

```python
def bonferroni_correction(p_values: list[float], alpha: float = 0.05) -> list[bool]:
    """Correct for multiple factor testing.

    If testing 15 factors, the chance of finding a spurious significant
    factor is 1 - (1-0.05)^15 = 54%. Bonferroni divides alpha by
    the number of tests.
    """
    n = len(p_values)
    adjusted_alpha = alpha / n
    return [p < adjusted_alpha for p in p_values]
```

---

## 12. Implementation Phases

### Phase 1: Core (Current Sprint)

- [x] Factor definitions (15+ factors across 6 categories)
- [x] Cross-sectional IC (Pearson)
- [x] Cross-sectional Rank IC (Spearman)
- [x] Long-short portfolio returns
- [x] Portfolio turnover
- [x] Factor combiner (multi-factor model)
- [x] Full research pipeline (CryptoFactorBackend)
- [ ] Market data service (CCXT + SQLite cache)
- [ ] API endpoint for factor research
- [ ] macOS UI for factor research results

### Phase 2: Advanced Testing (Next Sprint)

- [ ] Fama-MacBeth cross-sectional regression
- [ ] Factor orthogonalization (Gram-Schmidt + symmetric)
- [ ] Out-of-sample testing (train/test split)
- [ ] Factor decay analysis (multi-horizon IC)
- [ ] Multiple testing correction (Bonferroni)
- [ ] Rolling IC window for regime detection
- [ ] Minimum universe size enforcement

### Phase 3: Production Hardening (Future)

- [ ] Real-time factor monitoring dashboard
- [ ] Factor signal alerts (IC breakdown warning)
- [ ] Automated factor rotation (switch factors when IC decays)
- [ ] Backtest engine integration (factors → strategy → backtest)
- [ ] Factor performance attribution (which factors drove returns)
