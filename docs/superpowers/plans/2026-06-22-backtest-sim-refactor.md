# 回测 / 模拟页面深度重构 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 `BacktestLabView` 从三列布局重做为单页纵向叙事流（九段），所有结果来自真实 backend run，禁止客户端伪造数据，并把运行参数到晋级实盘的链路串成一条主线。

**Architecture:** 后端最小改动（slippage_bps 字段、BacktestRunResponse 强类型化 equity_curve/trades、failure-clusters 接口加 strategy_uuid 别名）+ 前端重写 ViewModel/View/API service/L10n。前端用 `Phase` 状态机驱动九段解锁，Swift Charts 取代手绘 Path，mock 模式透明化。

**Tech Stack:** Python 3.12 / FastAPI / Pydantic v2 / SQLAlchemy（后端）；Swift 6.2 / SwiftUI / macOS 26 / Swift Charts（前端）；pytest / XCTest（测试）。

## Global Constraints

- 后端：Python 3.12，Pydantic v2，thin routers + logic in services，新 BFF 走 Redis → service → mock 三层回退。CI 门槛 `--cov-fail-under=30`。
- 前端：Swift 6.2，目标 macOS 26，无 SPM 依赖。设计 token 全走 `DesignSystem/DesignTokens.swift`（`PulseColors.*` / `PulseFonts.*` / `PulseSpacing.*` / `PulseRadii.*`）。`.glassEffect()` 直接作用于内容，不放 `.background` 里。所有用户可见字符串走 `L10n.BacktestLab.*`，中英双语。新 endpoint → `Services/API<Domain>.swift` 加 Codable response + method + mock factory 三件套。
- 回复语言：对话用中文，代码/标识符/文档用英文。
- 数据真实性：禁止任何客户端 PRNG 生成 equity curve；mock 模式必须显示 `MOCK` 徽章；mock 模式下历史列表返回空数组，不用假数据填充。
- 后端执行模式五档不变（backtest / dry_run / paper / live_small / live_full），本页只用 backtest + dry_run 两档。
- 本页不直接启动任何实盘；晋级 CTA 只跳转 `.liveReadiness`。

---

## File Structure

### 后端新增/修改

| 文件 | 责任 | 操作 |
|---|---|---|
| `backend/app/schemas/backtest_v2.py` | 加 `slippage_bps` 字段；新增 `EquityPoint` / `TradeRow`；`BacktestRunResponse` 强类型化 `equity_curve` / `trades` | Modify |
| `backend/app/services/backtest_runner.py` | `_build_config` 应用 `slippage_bps`（用 fee 近似）；`BacktestResult` 已有 `equity_curve` / `trades`，无需改 | Modify |
| `backend/app/routers/backtest.py` | `BacktestRunResponse` 序列化时从 `result` 提取 `equity_curve` / `trades` | Modify |
| `backend/app/routers/failure_clustering_bff.py` | `get_failure_clusters` 加 `strategy_uuid` 参数别名 | Modify |
| `backend/tests/test_backtest_v2_api.py` | slippage_bps 校验 + 序列化测试 | Create/Modify |
| `backend/tests/test_backtest_schema.py` | EquityPoint / TradeRow 序列化测试 | Create |
| `backend/tests/test_failure_clusters_api.py` | strategy_uuid 过滤测试 | Create |

### 前端新增/修改

| 文件 | 责任 | 操作 |
|---|---|---|
| `macos-app/AlphaLoop/Models/Types.swift` | 加 `EquityPoint` / `TradeRow` / `FailureClusterSummary`；`BacktestRunV2` 加强类型字段 | Modify |
| `macos-app/AlphaLoop/Services/APIBacktestV2.swift` | 新文件：v2 backtest API（start / status / list / get），强类型 response，mock factory | Create |
| `macos-app/AlphaLoop/Services/APIFailureClusters.swift` | 新文件：failure-clusters 接口，strategy_uuid 过滤 | Create |
| `macos-app/AlphaLoop/ViewModels/BacktestLabViewModel.swift` | 重写：Phase 状态机、轮询、对比缓存、聚类 | Modify (重写) |
| `macos-app/AlphaLoop/Views/BacktestAndDryrun/BacktestLabView.swift` | 重写：九段叙事流主视图 | Modify (重写) |
| `macos-app/AlphaLoop/Views/BacktestAndDryrun/Sections/ConfigPanel.swift` | ① 运行参数 | Create |
| `macos-app/AlphaLoop/Views/BacktestAndDryrun/Sections/StatusPanel.swift` | ② 回测+模拟状态双卡 | Create |
| `macos-app/AlphaLoop/Views/BacktestAndDryrun/Sections/SummaryPanel.swift` | ③ 四指标 | Create |
| `macos-app/AlphaLoop/Views/BacktestAndDryrun/Sections/CurvePanel.swift` | ④ equity + drawdown | Create |
| `macos-app/AlphaLoop/Views/BacktestAndDryrun/Sections/TradeListPanel.swift` | ⑤ trade list + run 内聚类 | Create |
| `macos-app/AlphaLoop/Views/BacktestAndDryrun/Sections/ComparePanel.swift` | ⑥ 对比 | Create |
| `macos-app/AlphaLoop/Views/BacktestAndDryrun/Sections/RiskPanel.swift` | ⑦ 策略级聚类 + 风险警告 | Create |
| `macos-app/AlphaLoop/Views/BacktestAndDryrun/Sections/PromotionPanel.swift` | ⑧ 晋级准入 | Create |
| `macos-app/AlphaLoop/Views/BacktestAndDryrun/Sections/DataSourceFooter.swift` | ⑨ 数据源说明 | Create |
| `macos-app/AlphaLoop/Views/BacktestAndDryrun/NewRunSheet.swift` | 重写：DatePicker / NumberFormatter / 多选交易对 | Modify (重写) |
| `macos-app/AlphaLoop/Views/BacktestAndDryrun/RunFailureClustering.swift` | 纯函数：run 内聚类 | Create |
| `macos-app/AlphaLoop/Views/BacktestAndDryrun/RiskWarningRules.swift` | 纯函数：风险警告规则表 | Create |
| `macos-app/AlphaLoop/Localization/L10n+Backtest.swift` | 加新 key | Modify |
| `macos-app/Tests/BacktestLabViewModelTests.swift` | phase / 轮询 / 错误恢复测试 | Create |
| `macos-app/Tests/RunFailureClusteringTests.swift` | 纯函数聚类测试 | Create |
| `macos-app/Tests/RiskWarningRulesTests.swift` | 纯函数规则测试 | Create |

### 文档

| 文件 | 操作 |
|---|---|
| `docs/user-guide/content/zh/pages/strategy/backtest-simulation.html` | 重写 |
| `docs/user-guide/content/en/pages/strategy/backtest-simulation.html` | 重写 |
| `docs/README.md` | 索引更新 |
| `CLAUDE.md` | macOS app 段 BacktestLabView 描述更新 |

---

## Task 1: 后端 — `StartBacktestRequest` 加 `slippage_bps` 字段

**Files:**
- Modify: `backend/app/schemas/backtest_v2.py:11-22`
- Test: `backend/tests/test_backtest_v2_api.py`

**Interfaces:**
- Produces: `StartBacktestRequest.slippage_bps: Optional[float] = Field(default=None, ge=0, le=100)`

- [ ] **Step 1: Write the failing test**

Create `backend/tests/test_backtest_v2_api.py` (or append if exists):

```python
import pytest
from pydantic import ValidationError
from app.schemas.backtest_v2 import StartBacktestRequest


def test_slippage_bps_default_none():
    req = StartBacktestRequest(
        dsl={"version": "2.5"},
        timerange="20240101-20240601",
        symbols=["BTC/USDT"],
    )
    assert req.slippage_bps is None


def test_slippage_bps_accepts_valid():
    req = StartBacktestRequest(
        dsl={"version": "2.5"},
        timerange="20240101-20240601",
        symbols=["BTC/USDT"],
        slippage_bps=5.0,
    )
    assert req.slippage_bps == 5.0


def test_slippage_bps_rejects_negative():
    with pytest.raises(ValidationError):
        StartBacktestRequest(
            dsl={"version": "2.5"},
            timerange="20240101-20240601",
            symbols=["BTC/USDT"],
            slippage_bps=-1.0,
        )


def test_slippage_bps_rejects_over_100():
    with pytest.raises(ValidationError):
        StartBacktestRequest(
            dsl={"version": "2.5"},
            timerange="20240101-20240601",
            symbols=["BTC/USDT"],
            slippage_bps=101.0,
        )
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && python3 -m pytest tests/test_backtest_v2_api.py -q`
Expected: FAIL with `ImportError` or `AttributeError` for `slippage_bps`.

- [ ] **Step 3: Write minimal implementation**

Edit `backend/app/schemas/backtest_v2.py`, in `StartBacktestRequest` add after `fee`:

```python
    slippage_bps: Optional[float] = Field(default=None, ge=0, le=100,
        description="Slippage in basis points; applied by adjusting effective fee")
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && python3 -m pytest tests/test_backtest_v2_api.py -q`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add backend/app/schemas/backtest_v2.py backend/tests/test_backtest_v2_api.py
git commit -m "feat(backtest): add slippage_bps to StartBacktestRequest"
```

---

## Task 2: 后端 — `FreqtradeBacktestRunner` 应用 slippage

**Files:**
- Modify: `backend/app/services/backtest_runner.py` (`_build_config` 方法，约 line 113-160)
- Test: `backend/tests/test_backtest_runner.py`

**Interfaces:**
- Consumes: `StartBacktestRequest.slippage_bps` (Task 1)
- Produces: `FreqtradeBacktestRunner.run(slippage_bps: float | None = None)` 参数；`BacktestResult` 的 `data_source` 记录 slippage 模型

- [ ] **Step 1: Write the failing test**

Append to `backend/tests/test_backtest_runner.py`:

```python
import json
from pathlib import Path
from unittest.mock import patch
from app.services.backtest_runner import FreqtradeBacktestRunner


def test_build_config_applies_slippage_to_fee(tmp_path):
    runner = FreqtradeBacktestRunner(freqtrade_dir=tmp_path)
    config_path = runner._build_config(
        symbols=["BTC/USDT"],
        initial_capital=10000,
        stake_amount=100,
        max_open_trades=5,
        exchange="binance",
        fee=0.0005,
        slippage_bps=3.0,
        run_id="test",
    )
    config = json.loads(Path(config_path).read_text())
    # 0.0005 + 3/10000 = 0.0008
    assert abs(config["fee"] - 0.0008) < 1e-9


def test_build_config_without_slippage_keeps_fee(tmp_path):
    runner = FreqtradeBacktestRunner(freqtrade_dir=tmp_path)
    config_path = runner._build_config(
        symbols=["BTC/USDT"],
        initial_capital=10000,
        stake_amount=100,
        max_open_trades=5,
        exchange="binance",
        fee=0.0005,
        slippage_bps=None,
        run_id="test",
    )
    config = json.loads(Path(config_path).read_text())
    assert config["fee"] == 0.0005
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && python3 -m pytest tests/test_backtest_runner.py::test_build_config_applies_slippage_to_fee -q`
Expected: FAIL with `TypeError: unexpected keyword argument 'slippage_bps'`.

- [ ] **Step 3: Write minimal implementation**

Edit `backend/app/services/backtest_runner.py`. In `_build_config` signature add `slippage_bps: float | None = None`. Compute effective fee:

```python
    def _build_config(
        self,
        *,
        symbols: list[str],
        initial_capital: float,
        stake_amount: float | int,
        max_open_trades: int,
        exchange: str,
        fee: float | None,
        run_id: str,
        slippage_bps: float | None = None,
    ) -> Path:
        effective_fee = fee if fee is not None else 0.0005
        if slippage_bps is not None:
            effective_fee = effective_fee + slippage_bps / 10000.0
        # ... existing config build, use effective_fee where fee was used
```

Also update `run()` signature to accept `slippage_bps: float | None = None` and pass it through to `_build_config`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && python3 -m pytest tests/test_backtest_runner.py -q -k slippage`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add backend/app/services/backtest_runner.py backend/tests/test_backtest_runner.py
git commit -m "feat(backtest): apply slippage_bps as fee adjustment in runner"
```

---

## Task 3: 后端 — `BacktestRunResponse` 强类型化 `equity_curve` / `trades`

**Files:**
- Modify: `backend/app/schemas/backtest_v2.py` (加 `EquityPoint` / `TradeRow`，改 `BacktestRunResponse`)
- Modify: `backend/app/routers/backtest.py` (序列化时从 `result` 提取)
- Test: `backend/tests/test_backtest_schema.py`

**Interfaces:**
- Produces: `EquityPoint(timestamp: str, equity: float, drawdown: float)`, `TradeRow(open_time, close_time, pair, side, open_price, close_price, quantity, profit, duration, mtf_state)`, `BacktestRunResponse.equity_curve: list[EquityPoint]`, `BacktestRunResponse.trades: list[TradeRow]`

- [ ] **Step 1: Write the failing test**

Create `backend/tests/test_backtest_schema.py`:

```python
from app.schemas.backtest_v2 import (
    BacktestRunResponse, EquityPoint, TradeRow,
)


def test_equity_point_serialization():
    pt = EquityPoint(timestamp="2024-01-01T00:00:00Z", equity=10000.0, drawdown=0.0)
    assert pt.model_dump()["equity"] == 10000.0


def test_trade_row_serialization():
    t = TradeRow(
        open_time="2024-01-01T00:00:00Z",
        close_time="2024-01-01T01:00:00Z",
        pair="BTC/USDT",
        side="long",
        open_price=40000.0,
        close_price=40500.0,
        quantity=0.1,
        profit=50.0,
        duration="1h",
        mtf_state="confirmed",
    )
    assert t.model_dump()["pair"] == "BTC/USDT"


def test_backtest_run_response_extracts_equity_and_trades_from_result():
    run = BacktestRunResponse(
        id=1, strategy_id=1, status="completed",
        start_date="20240101", end_date="20240601", initial_capital=10000,
        result={
            "equity_curve": [
                {"timestamp": "2024-01-01", "equity": 10000, "drawdown": 0},
                {"timestamp": "2024-01-02", "equity": 10100, "drawdown": 0},
            ],
            "trades": [
                {"open_time": "2024-01-01", "close_time": "2024-01-01",
                 "pair": "BTC/USDT", "side": "long",
                 "open_price": 40000, "close_price": 40500,
                 "quantity": 0.1, "profit": 50, "duration": "1h",
                 "mtf_state": "confirmed"},
            ],
        },
    )
    assert len(run.equity_curve) == 2
    assert run.equity_curve[0].equity == 10000
    assert len(run.trades) == 1
    assert run.trades[0].profit == 50.0
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && python3 -m pytest tests/test_backtest_schema.py -q`
Expected: FAIL with `AttributeError: 'BacktestRunResponse' has no attribute 'equity_curve'` or ImportError.

- [ ] **Step 3: Write minimal implementation**

Edit `backend/app/schemas/backtest_v2.py`, add before `BacktestRunResponse`:

```python
class EquityPoint(BaseModel):
    timestamp: str
    equity: float
    drawdown: float = 0


class TradeRow(BaseModel):
    open_time: str
    close_time: str
    pair: str
    side: str
    open_price: float
    close_price: float
    quantity: float
    profit: float
    duration: str
    mtf_state: Optional[str] = None
```

In `BacktestRunResponse`, add fields and a model_validator that extracts from `result`:

```python
class BacktestRunResponse(BaseModel):
    id: int
    strategy_id: int
    strategy_version_id: Optional[str] = None
    command_id: Optional[str] = None
    dsl_hash: Optional[str] = None
    status: str
    start_date: str
    end_date: str
    initial_capital: float
    symbols: list[str] = []
    config: dict[str, Any] = {}
    result: dict[str, Any] = {}
    equity_curve: list[EquityPoint] = []
    trades: list[TradeRow] = []
    sharpe_ratio: float = 0
    max_drawdown: float = 0
    win_rate: float = 0
    total_return: float = 0
    profit_factor: float = 0
    total_trades: int = 0
    error_message: Optional[str] = None
    created_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None

    model_config = {"from_attributes": True}

    @model_validator(mode="after")
    def _extract_result_fields(self):
        if self.result and not self.equity_curve:
            raw_eq = self.result.get("equity_curve", [])
            self.equity_curve = [EquityPoint(**p) for p in raw_eq if isinstance(p, dict)]
        if self.result and not self.trades:
            raw_tr = self.result.get("trades", [])
            self.trades = [TradeRow(**t) for t in raw_tr if isinstance(t, dict)]
        return self
```

Add `from pydantic import model_validator` to imports.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && python3 -m pytest tests/test_backtest_schema.py -q`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add backend/app/schemas/backtest_v2.py backend/tests/test_backtest_schema.py
git commit -m "feat(backtest): strong-type equity_curve and trades in response"
```

---

## Task 4: 后端 — `failure-clusters` 接口加 `strategy_uuid` 参数

**Files:**
- Modify: `backend/app/routers/failure_clustering_bff.py:135-166`
- Test: `backend/tests/test_failure_clusters_api.py`

**Interfaces:**
- Produces: `GET /api/growth/failure-clusters?strategy_uuid=<uuid>` 与现有 `?strategy_id=` 等价（load_clusters 已接受 uuid 字符串）

- [ ] **Step 1: Write the failing test**

Create `backend/tests/test_failure_clusters_api.py`:

```python
import uuid
from unittest.mock import patch
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_failure_clusters_accepts_strategy_uuid():
    u = uuid.uuid4()
    with patch("app.services.failure_clustering.load_clusters", return_value=[]):
        resp = client.get(f"/api/growth/failure-clusters?strategy_uuid={u}")
    assert resp.status_code == 200
    data = resp.json()
    assert "clusters" in data


def test_failure_clusters_strategy_uuid_passes_through():
    u = uuid.uuid4()
    captured = {}
    def fake_load(db, strategy_id=None, status="active"):
        captured["strategy_id"] = strategy_id
        return []
    with patch("app.services.failure_clustering.load_clusters", side_effect=fake_load):
        client.get(f"/api/growth/failure-clusters?strategy_uuid={u}")
    assert str(captured["strategy_id"]) == str(u)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && python3 -m pytest tests/test_failure_clusters_api.py -q`
Expected: FAIL with 422 — `strategy_uuid` not a recognized query param (or 200 but strategy_id not passed).

- [ ] **Step 3: Write minimal implementation**

Edit `backend/app/routers/failure_clustering_bff.py`, in `get_failure_clusters`:

```python
@router.get("/failure-clusters")
async def get_failure_clusters(
    strategy_id: str | None = Query(None),
    strategy_uuid: str | None = Query(None, description="Alias for strategy_id; accepts UUID string"),
    db: Session = Depends(get_db),
):
    effective_strategy_id = strategy_id or strategy_uuid
    try:
        from app.services.failure_clustering import load_clusters
        records = load_clusters(db, strategy_id=effective_strategy_id)
        if records:
            clusters = _db_records_to_cluster_responses(records)
            return {
                "state": "healthy",
                "reason_codes": [],
                "clusters": [c.model_dump() for c in clusters],
            }
    except Exception as e:
        logger.warning("[failure-clusters] DB load failed: %s", e)
    # ... existing fallback unchanged
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && python3 -m pytest tests/test_failure_clusters_api.py -q`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add backend/app/routers/failure_clustering_bff.py backend/tests/test_failure_clusters_api.py
git commit -m "feat(growth): add strategy_uuid query alias to failure-clusters"
```

---

## Task 5: 后端 — 全量回归测试

**Files:**
- Test: `backend/tests/`

- [ ] **Step 1: Run full backend test suite**

Run: `cd backend && python3 -m pytest tests/ -q`
Expected: All tests pass, no regressions. Coverage ≥ 30%.

- [ ] **Step 2: If failures, fix and re-run**

Common likely issues: existing tests that construct `StartBacktestRequest` without `slippage_bps` (should still work, it's optional); existing tests that check `BacktestRunResponse.result` (should still work, `result` field kept).

- [ ] **Step 3: Commit any fixes**

```bash
git add -A
git commit -m "test(backtest): regression fixes for schema changes"
```

(Only if there were fixes. Otherwise skip.)

---

## Task 6: 前端 — Models 加 `EquityPoint` / `TradeRow` / `FailureClusterSummary`

**Files:**
- Modify: `macos-app/AlphaLoop/Models/Types.swift`
- Test: `macos-app/Tests/BacktestModelTests.swift` (create)

**Interfaces:**
- Produces: `EquityPoint`, `TradeRow`, `FailureClusterSummary` Swift structs; `BacktestRunV2` 加 `equityCurve: [EquityPoint]` 和 `trades: [TradeRow]` 强类型字段（保留 `result: [String: AnyCodable]` 兼容）

- [ ] **Step 1: Write the failing test**

Create `macos-app/Tests/BacktestModelTests.swift`:

```swift
import XCTest
@testable import AlphaLoop

final class BacktestModelTests: XCTestCase {
    func testEquityPointDecodes() throws {
        let json = #"{"timestamp":"2024-01-01","equity":10000.0,"drawdown":0.0}"#
        let pt = try JSONDecoder().decode(EquityPoint.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(pt.equity, 10000.0)
    }

    func testTradeRowDecodes() throws {
        let json = #"{"open_time":"2024-01-01","close_time":"2024-01-01","pair":"BTC/USDT","side":"long","open_price":40000.0,"close_price":40500.0,"quantity":0.1,"profit":50.0,"duration":"1h","mtf_state":"confirmed"}"#
        let t = try JSONDecoder().decode(TradeRow.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(t.pair, "BTC/USDT")
        XCTAssertEqual(t.profit, 50.0)
    }

    func testBacktestRunV2ExtractsEquityCurveFromResult() throws {
        let json = """
        {"id":1,"strategy_id":1,"status":"completed","start_date":"20240101","end_date":"20240601","initial_capital":10000,
         "result":{"equity_curve":[{"timestamp":"2024-01-01","equity":10000,"drawdown":0}],
                   "trades":[{"open_time":"2024-01-01","close_time":"2024-01-01","pair":"BTC/USDT","side":"long","open_price":40000,"close_price":40500,"quantity":0.1,"profit":50,"duration":"1h"}]}}
        """
        let run = try JSONDecoder().decode(BacktestRunV2.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(run.equityCurve.count, 1)
        XCTAssertEqual(run.trades.count, 1)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd macos-app && swift test --filter BacktestModelTests`
Expected: FAIL — `EquityPoint` / `TradeRow` undefined.

- [ ] **Step 3: Write minimal implementation**

Edit `macos-app/AlphaLoop/Models/Types.swift`. Add structs:

```swift
public struct EquityPoint: Codable, Identifiable, Hashable {
    public let timestamp: String
    public let equity: Double
    public let drawdown: Double
    public var id: String { timestamp }
}

public struct TradeRow: Codable, Identifiable, Hashable {
    public let openTime: String
    public let closeTime: String
    public let pair: String
    public let side: String
    public let openPrice: Double
    public let closePrice: Double
    public let quantity: Double
    public let profit: Double
    public let duration: String
    public let mtfState: String?
    public var id: String { "\(openTime)-\(pair)-\(side)" }

    enum CodingKeys: String, CodingKey {
        case openTime = "open_time"
        case closeTime = "close_time"
        case pair, side
        case openPrice = "open_price"
        case closePrice = "close_price"
        case quantity, profit, duration
        case mtfState = "mtf_state"
    }
}

public struct FailureClusterSummary: Codable, Identifiable, Hashable {
    public let id: String
    public let label: String
    public let sampleSize: Int
    public let totalLoss: Double
    public let avgLoss: Double
    public let commonFeatures: [String]
}
```

In `BacktestRunV2`, add fields and custom decoder that extracts from `result` if the strong-type fields are empty:

```swift
public struct BacktestRunV2: Codable, Identifiable, Hashable {
    // ... existing fields ...
    public var equityCurve: [EquityPoint] = []
    public var trades: [TradeRow] = []
    public var result: [String: AnyCodable] = [:]

    // ... existing CodingKeys ...
    enum CodingKeys: String, CodingKey {
        // existing keys +
        case equityCurve = "equity_curve"
        case trades, result
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // decode existing fields...
        // ...
        self.equityCurve = (try? c.decode([EquityPoint].self, forKey: .equityCurve)) ?? []
        self.trades = (try? c.decode([TradeRow].self, forKey: .trades)) ?? []
        self.result = (try? c.decode([String: AnyCodable].self, forKey: .result)) ?? [:]
        if self.equityCurve.isEmpty, let raw = self.result["equity_curve"]?.value as? [[String: Any]] {
            self.equityCurve = raw.compactMap { try? EquityPoint(from: AnyCodableDecoder(dict: $0)) }
        }
        if self.trades.isEmpty, let raw = self.result["trades"]?.value as? [[String: Any]] {
            self.trades = raw.compactMap { try? TradeRow(from: AnyCodableDecoder(dict: $0)) }
        }
    }
}
```

Note: `AnyCodableDecoder` is a helper that decodes from a `[String: Any]` dict. If it doesn't exist, add a small helper in the same file.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd macos-app && swift test --filter BacktestModelTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add macos-app/AlphaLoop/Models/Types.swift macos-app/Tests/BacktestModelTests.swift
git commit -m "feat(macos): add EquityPoint/TradeRow/FailureClusterSummary models"
```

---

## Task 7: 前端 — `APIBacktestV2.swift` 强类型 API service

**Files:**
- Create: `macos-app/AlphaLoop/Services/APIBacktestV2.swift`
- Modify: `macos-app/AlphaLoop/Services/APIStrategiesV2.swift` (把现有 backtest v2 方法标记 deprecated，指向新文件)
- Test: manual (compiled via `swift build`)

**Interfaces:**
- Consumes: `BacktestRunV2` (Task 6)
- Produces: `APIStrategiesV2.startBacktestV2(...)`, `backtestStatusV2(...)`, `listBacktestsV2(...)`, `getBacktestV2(id:)` — all on `NetworkClientProtocol`; mock factories in same file

- [ ] **Step 1: Write the failing test**

Create `macos-app/Tests/APIBacktestV2Tests.swift`:

```swift
import XCTest
@testable import AlphaLoop

final class APIBacktestV2Tests: XCTestCase {
    func testStartBacktestBuildsRequest() async throws {
        let client = MockNetworkClient()
        let resp = try await client.startBacktestV2(
            dsl: ["version": "2.5"],
            timerange: "20240101-20240601",
            symbols: ["BTC/USDT"],
            initialCapital: 10000,
            slippageBps: 5.0
        )
        XCTAssertNotNil(resp.commandId)
    }

    func testGetBacktestDecodesEquityCurve() async throws {
        let client = MockNetworkClient()
        let run = try await client.getBacktestV2(id: 1)
        XCTAssertEqual(run.status, "completed")
        XCTAssertFalse(run.equityCurve.isEmpty)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd macos-app && swift test --filter APIBacktestV2Tests`
Expected: FAIL — method doesn't exist.

- [ ] **Step 3: Write minimal implementation**

Create `macos-app/AlphaLoop/Services/APIBacktestV2.swift`:

```swift
import Foundation

public struct StartBacktestV2Request: Encodable {
    public let dsl: [String: AnyCodable]
    public let timerange: String
    public let symbols: [String]
    public let initial_capital: Double
    public let stake_amount: Double
    public let max_open_trades: Int
    public let exchange: String
    public let fee: Double?
    public let slippage_bps: Double?
    public let strategy_id: Int
    public let strategy_version_id: String?
}

public struct BacktestCommandResponseV2: Decodable {
    public let commandId: UUID
    public let status: String
    public let message: String
    public let idempotencyKey: String
    enum CodingKeys: String, CodingKey {
        case commandId = "command_id"
        case status, message
        case idempotencyKey = "idempotency_key"
    }
}

public struct BacktestStatusResponseV2: Decodable {
    public let commandId: UUID
    public let commandStatus: String
    public let backtestRun: BacktestRunV2?
    public let errorMessage: String?
    enum CodingKeys: String, CodingKey {
        case commandId = "command_id"
        case commandStatus = "command_status"
        case backtestRun = "backtest_run"
        case errorMessage = "error_message"
    }
}

extension NetworkClientProtocol {
    public func startBacktestV2(
        dsl: [String: AnyCodable],
        timerange: String,
        symbols: [String],
        initialCapital: Double,
        stakeAmount: Double = 100,
        maxOpenTrades: Int = 5,
        exchange: String = "binance",
        fee: Double? = nil,
        slippageBps: Double? = nil,
        strategyId: Int = 0,
        strategyVersionId: String? = nil
    ) async throws -> BacktestCommandResponseV2 {
        if let mock = self as? MockNetworkClient {
            return try await mock.mockStartBacktestV2()
        }
        let req = StartBacktestV2Request(
            dsl: dsl, timerange: timerange, symbols: symbols,
            initial_capital: initialCapital, stake_amount: stakeAmount,
            max_open_trades: maxOpenTrades, exchange: exchange,
            fee: fee, slippage_bps: slippageBps,
            strategy_id: strategyId, strategy_version_id: strategyVersionId
        )
        return try await livePost("/api/v2/backtest", body: req, as: BacktestCommandResponseV2.self)
    }

    public func backtestStatusV2(commandId: UUID) async throws -> BacktestStatusResponseV2 {
        if let mock = self as? MockNetworkClient {
            return try await mock.mockBacktestStatusV2()
        }
        return try await liveGet("/api/v2/backtest/status/\(commandId)", as: BacktestStatusResponseV2.self)
    }

    public func listBacktestsV2(strategyUuid: UUID?, limit: Int = 20) async throws -> [BacktestRunV2] {
        if let mock = self as? MockNetworkClient {
            return []  // mock 模式历史列表为空
        }
        var path = "/api/v2/backtest?limit=\(limit)"
        if let u = strategyUuid { path += "&strategy_uuid=\(u)" }
        return try await liveGet(path, as: [BacktestRunV2].self)
    }

    public func getBacktestV2(id: Int) async throws -> BacktestRunV2 {
        if let mock = self as? MockNetworkClient {
            return MockDataV2.mockBacktestRunV2(id: id)
        }
        return try await liveGet("/api/v2/backtest/\(id)", as: BacktestRunV2.self)
    }
}
```

Add mock factory in `MockNetworkClient` extension (in same file):

```swift
extension MockNetworkClient {
    func mockStartBacktestV2() async throws -> BacktestCommandResponseV2 {
        try await Task.sleep(nanoseconds: 200_000_000)
        return BacktestCommandResponseV2(
            commandId: UUID(), status: "queued",
            message: "mock", idempotencyKey: UUID().uuidString
        )
    }
    func mockBacktestStatusV2() async throws -> BacktestStatusResponseV2 {
        BacktestStatusResponseV2(commandId: UUID(), commandStatus: "completed",
                                  backtestRun: MockDataV2.mockBacktestRunV2(id: 1), errorMessage: nil)
    }
}

extension MockDataV2 {
    static func mockBacktestRunV2(id: Int) -> BacktestRunV2 {
        // 返回单条 run 用于"新建 run 后本地回显"；历史列表不调用此方法
        BacktestRunV2(
            id: id, strategyId: 1, strategyVersionId: nil, commandId: nil,
            dslHash: "mock", status: "completed",
            startDate: "20240101", endDate: "20240601",
            initialCapital: 10000, symbols: ["BTC/USDT"],
            config: [:], result: [:],
            equityCurve: [
                EquityPoint(timestamp: "2024-01-01", equity: 10000, drawdown: 0),
                EquityPoint(timestamp: "2024-06-01", equity: 11200, drawdown: -0.05),
            ],
            trades: [],
            sharpeRatio: 1.8, maxDrawdown: -0.12, winRate: 0.55,
            totalReturn: 0.12, profitFactor: 1.6, totalTrades: 42,
            errorMessage: nil, createdAt: Date(), completedAt: Date()
        )
    }
}
```

Note: adjust constructor of `BacktestRunV2` to match what Task 6 produced. If `BacktestRunV2` is a struct with memberwise init, this works. If it has let properties without custom init, may need to add an internal init.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd macos-app && swift test --filter APIBacktestV2Tests`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add macos-app/AlphaLoop/Services/APIBacktestV2.swift macos-app/Tests/APIBacktestV2Tests.swift
git commit -m "feat(macos): add strong-typed v2 backtest API service"
```

---

## Task 8: 前端 — `APIFailureClusters.swift`

**Files:**
- Create: `macos-app/AlphaLoop/Services/APIFailureClusters.swift`
- Test: `macos-app/Tests/APIFailureClustersTests.swift`

**Interfaces:**
- Produces: `NetworkClientProtocol.getFailureClusters(strategyUuid:) async throws -> [FailureClusterSummary]`

- [ ] **Step 1: Write the failing test**

Create `macos-app/Tests/APIFailureClustersTests.swift`:

```swift
import XCTest
@testable import AlphaLoop

final class APIFailureClustersTests: XCTestCase {
    func testGetFailureClustersMockReturnsEmpty() async throws {
        let client = MockNetworkClient()
        let clusters = try await client.getFailureClusters(strategyUuid: UUID())
        XCTAssertEqual(clusters, [])  // mock 模式无历史
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd macos-app && swift test --filter APIFailureClustersTests`
Expected: FAIL — method not defined.

- [ ] **Step 3: Write minimal implementation**

Create `macos-app/AlphaLoop/Services/APIFailureClusters.swift`:

```swift
import Foundation

public struct FailureClustersResponse: Decodable {
    public let state: String
    public let clusters: [FailureClusterDTO]
}

public struct FailureClusterDTO: Decodable {
    public let clusterName: String
    public let tradeCount: Int
    public let totalLoss: Double
    public let avgLossPct: Double
    public let exampleTradeIds: [String]
    public let suggestedFix: String
    enum CodingKeys: String, CodingKey {
        case clusterName = "cluster_name"
        case tradeCount = "trade_count"
        case totalLoss = "total_loss"
        case avgLossPct = "avg_loss_pct"
        case exampleTradeIds = "example_trade_ids"
        case suggestedFix = "suggested_fix"
    }
}

extension NetworkClientProtocol {
    public func getFailureClusters(strategyUuid: UUID) async throws -> [FailureClusterSummary] {
        if let mock = self as? MockNetworkClient {
            return []  // mock 模式无历史聚类
        }
        let resp: FailureClustersResponse = try await liveGet(
            "/api/growth/failure-clusters?strategy_uuid=\(strategyUuid)", as: FailureClustersResponse.self
        )
        return resp.clusters.map {
            FailureClusterSummary(
                id: $0.clusterName,
                label: $0.clusterName,
                sampleSize: $0.tradeCount,
                totalLoss: $0.totalLoss,
                avgLoss: $0.avgLossPct,
                commonFeatures: $0.suggestedFix.split(separator: ";").map(String.init)
            )
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd macos-app && swift test --filter APIFailureClustersTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add macos-app/AlphaLoop/Services/APIFailureClusters.swift macos-app/Tests/APIFailureClustersTests.swift
git commit -m "feat(macos): add failure-clusters API service"
```

---

## Task 9: 前端 — `RiskWarningRules.swift` 纯函数

**Files:**
- Create: `macos-app/AlphaLoop/Views/BacktestAndDryrun/RiskWarningRules.swift`
- Test: `macos-app/Tests/RiskWarningRulesTests.swift`

**Interfaces:**
- Produces: `func riskWarnings(for metrics: BacktestMetrics) -> [RiskWarning]`

- [ ] **Step 1: Write the failing test**

Create `macos-app/Tests/RiskWarningRulesTests.swift`:

```swift
import XCTest
@testable import AlphaLoop

final class RiskWarningRulesTests: XCTestCase {
    func testMaxDrawdownBeyond25TriggersRed() {
        let m = BacktestMetrics(totalReturn: 0.1, sharpeRatio: 1.5, maxDrawdown: -0.30,
                                winRate: 0.55, profitFactor: 1.6, totalTrades: 100,
                                avgTradeDuration: "1h", bestTrade: 0.05, worstTrade: -0.03)
        let ws = riskWarnings(for: m)
        XCTAssertTrue(ws.contains { $0.level == .red && $0.id == "max_drawdown" })
    }

    func testLowTradesTriggersYellow() {
        let m = BacktestMetrics(totalReturn: 0.1, sharpeRatio: 1.5, maxDrawdown: -0.05,
                                winRate: 0.55, profitFactor: 1.6, totalTrades: 20,
                                avgTradeDuration: "1h", bestTrade: 0.05, worstTrade: -0.03)
        let ws = riskWarnings(for: m)
        XCTAssertTrue(ws.contains { $0.level == .yellow && $0.id == "low_trades" })
    }

    func testNoWarningsForHealthyMetrics() {
        let m = BacktestMetrics(totalReturn: 0.2, sharpeRatio: 2.0, maxDrawdown: -0.10,
                                winRate: 0.55, profitFactor: 1.8, totalTrades: 200,
                                avgTradeDuration: "1h", bestTrade: 0.05, worstTrade: -0.02)
        XCTAssertEqual(riskWarnings(for: m), [])
    }

    func testWarningsSortedBySeverity() {
        let m = BacktestMetrics(totalReturn: -0.1, sharpeRatio: -0.5, maxDrawdown: -0.30,
                                winRate: 0.30, profitFactor: 0.8, totalTrades: 20,
                                avgTradeDuration: "1h", bestTrade: 0.01, worstTrade: -0.05)
        let ws = riskWarnings(for: m)
        XCTAssertEqual(ws.first?.level, .red)
    }

    func testAtMost5Warnings() {
        let m = BacktestMetrics(totalReturn: -0.1, sharpeRatio: -0.5, maxDrawdown: -0.30,
                                winRate: 0.30, profitFactor: 0.8, totalTrades: 10,
                                avgTradeDuration: "1h", bestTrade: 0.01, worstTrade: -0.05)
        let ws = riskWarnings(for: m)
        XCTAssertLessThanOrEqual(ws.count, 5)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd macos-app && swift test --filter RiskWarningRulesTests`
Expected: FAIL — `riskWarnings` undefined.

- [ ] **Step 3: Write minimal implementation**

Create `macos-app/AlphaLoop/Views/BacktestAndDryrun/RiskWarningRules.swift`:

```swift
import Foundation

public enum RiskWarningLevel: String, Codable {
    case red, yellow
}

public struct RiskWarning: Identifiable, Hashable {
    public let id: String
    public let level: RiskWarningLevel
    public let message: String
}

public func riskWarnings(for m: BacktestMetrics) -> [RiskWarning] {
    var ws: [RiskWarning] = []
    if m.maxDrawdown <= -0.25 {
        ws.append(.init(id: "max_drawdown", level: .red,
                        message: L10n.BacktestLab.warnMaxDrawdown))
    }
    if m.profitFactor < 1.0 {
        ws.append(.init(id: "profit_factor", level: .red,
                        message: L10n.BacktestLab.warnProfitFactor))
    }
    if m.totalTrades < 30 {
        ws.append(.init(id: "low_trades", level: .yellow,
                        message: L10n.BacktestLab.warnLowTrades))
    }
    if m.winRate < 0.35 {
        ws.append(.init(id: "low_winrate", level: .yellow,
                        message: L10n.BacktestLab.warnLowWinrate))
    }
    if m.sharpeRatio < 0 {
        ws.append(.init(id: "negative_sharpe", level: .yellow,
                        message: L10n.BacktestLab.warnNegativeSharpe))
    }
    // red 排前，yellow 排后；同 level 保持插入顺序
    let reds = ws.filter { $0.level == .red }
    let yellows = ws.filter { $0.level == .yellow }
    return Array((reds + yellows).prefix(5))
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd macos-app && swift test --filter RiskWarningRulesTests`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add macos-app/AlphaLoop/Views/BacktestAndDryrun/RiskWarningRules.swift macos-app/Tests/RiskWarningRulesTests.swift
git commit -m "feat(macos): risk warning rules pure function"
```

---

## Task 10: 前端 — `RunFailureClustering.swift` 纯函数

**Files:**
- Create: `macos-app/AlphaLoop/Views/BacktestAndDryrun/RunFailureClustering.swift`
- Test: `macos-app/Tests/RunFailureClusteringTests.swift`

**Interfaces:**
- Produces: `func clusterFailures(in trades: [TradeRow]) -> [RunFailureCluster]`

- [ ] **Step 1: Write the failing test**

Create `macos-app/Tests/RunFailureClusteringTests.swift`:

```swift
import XCTest
@testable import AlphaLoop

final class RunFailureClusteringTests: XCTestCase {
    private func trade(profit: Double, duration: String = "1h", pair: String = "BTC/USDT",
                       side: String = "long", openTime: String = "2024-01-01T00:00:00Z",
                       mtfState: String? = "confirmed") -> TradeRow {
        TradeRow(openTime: openTime, closeTime: openTime, pair: pair, side: side,
                 openPrice: 40000, closePrice: 40500, quantity: 0.1, profit: profit,
                 duration: duration, mtfState: mtfState)
    }

    func testReturnsEmptyWhenFewerThan5Losses() {
        let trades = [
            trade(profit: -10), trade(profit: -10), trade(profit: -10), trade(profit: -10),
        ]
        XCTAssertEqual(clusterFailures(in: trades), [])
    }

    func testClustersByDurationBucket() {
        let trades: [TradeRow] = [
            trade(profit: -10, duration: "0.5h"), trade(profit: -10, duration: "0.5h"),
            trade(profit: -10, duration: "0.5h"), trade(profit: -10, duration: "0.5h"),
            trade(profit: -10, duration: "0.5h"),
            trade(profit: -10, duration: "24h"), trade(profit: -10, duration: "24h"),
            trade(profit: -10, duration: "24h"), trade(profit: -10, duration: "24h"),
            trade(profit: -10, duration: "24h"),
        ]
        let clusters = clusterFailures(in: trades)
        XCTAssertEqual(clusters.count, 2)
    }

    func testIgnoresProfitableTrades() {
        let trades: [TradeRow] = [
            trade(profit: 100), trade(profit: 100), trade(profit: 100),
            trade(profit: -10), trade(profit: -10), trade(profit: -10),
            trade(profit: -10), trade(profit: -10),
        ]
        let clusters = clusterFailures(in: trades)
        XCTAssertEqual(clusters.count, 1)
        XCTAssertEqual(clusters[0].sampleSize, 5)
    }

    func testAtMost5Clusters() {
        var trades: [TradeRow] = []
        for bucket in ["0.5h", "1h", "2h", "4h", "12h", "24h", "48h"] {
            for _ in 0..<5 {
                trades.append(trade(profit: -10, duration: bucket))
            }
        }
        let clusters = clusterFailures(in: trades)
        XCTAssertLessThanOrEqual(clusters.count, 5)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd macos-app && swift test --filter RunFailureClusteringTests`
Expected: FAIL — `clusterFailures` undefined.

- [ ] **Step 3: Write minimal implementation**

Create `macos-app/AlphaLoop/Views/BacktestAndDryrun/RunFailureClustering.swift`:

```swift
import Foundation

public struct RunFailureCluster: Identifiable, Hashable {
    public let id: String
    public let label: String
    public let sampleSize: Int
    public let totalLoss: Double
    public let avgLoss: Double
    public let commonFeatures: [String]
}

private func durationBucket(_ d: String) -> String {
    // 简单分桶：< 1h, 1-4h, 4-12h, 12-24h, > 24h
    let lower = d.lowercased()
    if lower.contains("m") && !lower.contains("h") { return "<1h" }
    if let h = Double(lower.replacingOccurrences(of: "h", with: "")) {
        switch h {
        case ..<1: return "<1h"
        case 1..<4: return "1-4h"
        case 4..<12: return "4-12h"
        case 12..<24: return "12-24h"
        default: return ">24h"
        }
    }
    return "unknown"
}

private func hourBucket(_ openTime: String) -> String {
    // 从 ISO 时间取小时，分 4 桶：0-6, 6-12, 12-18, 18-24
    if let t = ISO8601DateFormatter().date(from: openTime) {
        let h = Calendar.current.component(.hour, from: t)
        switch h {
        case 0..<6: return "00-06"
        case 6..<12: return "06-12"
        case 12..<18: return "12-18"
        default: return "18-24"
        }
    }
    return "unknown"
}

public func clusterFailures(in trades: [TradeRow]) -> [RunFailureCluster] {
    let losses = trades.filter { $0.profit < 0 }
    if losses.count < 5 { return [] }

    // 按 duration bucket 聚类（最稳定的特征）
    var buckets: [String: [TradeRow]] = [:]
    for t in losses {
        let key = durationBucket(t.duration)
        buckets[key, default: []].append(t)
    }

    let clusters = buckets.map { (key, items) -> RunFailureCluster in
        let total = items.reduce(0.0) { $0 + $1.profit }
        let sides = Set(items.map { $0.side })
        let pairs = Set(items.map { $0.pair })
        let hours = Set(items.map { hourBucket($0.openTime) })
        var features: [String] = ["duration: \(key)"]
        if sides.count == 1 { features.append("side: \(sides.first!)") }
        if pairs.count == 1 { features.append("pair: \(pairs.first!)") }
        if hours.count == 1 { features.append("hour: \(hours.first!)") }
        return RunFailureCluster(
            id: key, label: key, sampleSize: items.count,
            totalLoss: total, avgLoss: total / Double(items.count),
            commonFeatures: features
        )
    }.sorted { $0.sampleSize > $1.sampleSize }

    return Array(clusters.prefix(5))
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd macos-app && swift test --filter RunFailureClusteringTests`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add macos-app/AlphaLoop/Views/BacktestAndDryrun/RunFailureClustering.swift macos-app/Tests/RunFailureClusteringTests.swift
git commit -m "feat(macos): run-level failure clustering pure function"
```

---

## Task 11: 前端 — `BacktestLabViewModel` 重写（Phase 状态机 + 轮询）

**Files:**
- Modify: `macos-app/AlphaLoop/ViewModels/BacktestLabViewModel.swift` (重写)
- Test: `macos-app/Tests/BacktestLabViewModelTests.swift`

**Interfaces:**
- Consumes: Task 7 / 8 API methods
- Produces: `BacktestLabViewModel` with `@Observable` properties: `phase`, `selectedStrategy`, `selectedRun`, `comparedRuns`, `strategyFailureClusters`, `errorMessage`, `pollingTask`

- [ ] **Step 1: Write the failing test**

Create `macos-app/Tests/BacktestLabViewModelTests.swift`:

```swift
import XCTest
@testable import AlphaLoop

@MainActor
final class BacktestLabViewModelTests: XCTestCase {
    func testInitialPhaseIsIdle() {
        let vm = BacktestLabViewModel()
        XCTAssertEqual(vm.phase, .idle)
    }

    func testSelectingStrategyTransitionsToConfiguring() async {
        let vm = BacktestLabViewModel()
        let strategy = Strategy(id: 1, uuid: UUID(), name: "Test", version: "1.0",
                                status: .draft, dsl: [:], createdAt: Date())
        await vm.selectStrategy(strategy)
        XCTAssertEqual(vm.phase, .configuring)
    }

    func testStartingBacktestTransitionsToRunning() async throws {
        let vm = BacktestLabViewModel()
        vm.useMockClient = true
        let strategy = Strategy(id: 1, uuid: UUID(), name: "Test", version: "1.0",
                                status: .draft, dsl: ["version": "2.5"], createdAt: Date())
        await vm.selectStrategy(strategy)
        try await vm.startBacktest(timerange: "20240101-20240601",
                                    symbols: ["BTC/USDT"], capital: 10000)
        XCTAssertEqual(vm.phase, .running)
    }

    func testFailedRunTransitionsToFailed() async {
        let vm = BacktestLabViewModel()
        vm.injectPhaseForTest(.failed)
        XCTAssertEqual(vm.phase, .failed)
    }

    func testCancellingStrategyStopsPolling() async {
        let vm = BacktestLabViewModel()
        vm.injectPhaseForTest(.running)
        vm.cancelPolling()
        XCTAssertNil(vm.pollingTask)
    }
}
```

Note: `Strategy` struct shape must match existing `Models/Types.swift`. If `Strategy` doesn't have these fields, use the existing constructor.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd macos-app && swift test --filter BacktestLabViewModelTests`
Expected: FAIL — `phase`, `selectStrategy` etc. don't exist or signature mismatch.

- [ ] **Step 3: Write minimal implementation**

Rewrite `macos-app/AlphaLoop/ViewModels/BacktestLabViewModel.swift`:

```swift
import Foundation
import SwiftUI
import Combine

@Observable
@MainActor
public final class BacktestLabViewModel {
    public enum Phase: Equatable {
        case idle, configuring, running, completed, failed
    }

    public var phase: Phase = .idle
    public var selectedStrategy: Strategy?
    public var selectedRun: BacktestRunV2?
    public var recentBacktests: [BacktestRunV2] = []
    public var recentDryruns: [StrategyRunV2] = []
    public var comparedRuns: [BacktestRunV2] = []
    public var comparedRunIds: Set<Int> = []
    public var strategyFailureClusters: [FailureClusterSummary] = []
    public var readiness: PerStrategyReadinessResponse?
    public var errorMessage: String?
    public var isMockMode: Bool = false

    var pollingTask: Task<Void, Never>?
    var pollStartTime: Date?
    private let pollTimeout: TimeInterval = 15 * 60  // 15 分钟硬上限

    public var networkClient: NetworkClientProtocol = MockNetworkClient()
    public var useMockClient: Bool = true {
        didSet { networkClient = useMockClient ? MockNetworkClient() : LiveNetworkClient() }
    }

    public init() {}

    // Test helper
    public func injectPhaseForTest(_ p: Phase) { self.phase = p }

    public func selectStrategy(_ s: Strategy) async {
        cancelPolling()
        selectedStrategy = s
        selectedRun = nil
        comparedRuns = []
        comparedRunIds = []
        strategyFailureClusters = []
        readiness = nil
        phase = .configuring
        await loadWorkspaceSnapshot()
    }

    public func loadWorkspaceSnapshot() async {
        guard let s = selectedStrategy else { return }
        do {
            let snap = try await networkClient.getWorkspaceSnapshot(strategyId: s.id)
            self.recentBacktests = snap.recentBacktests
            self.recentDryruns = snap.recentDryruns
            self.readiness = snap.readiness
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    public func startBacktest(timerange: String, symbols: [String], capital: Double,
                               slippageBps: Double? = nil) async throws {
        guard let s = selectedStrategy else { return }
        let resp = try await networkClient.startBacktestV2(
            dsl: s.dsl, timerange: timerange, symbols: symbols,
            initialCapital: capital, slippageBps: slippageBps,
            strategyId: s.id, strategyVersionId: s.currentVersionId
        )
        phase = .running
        pollStartTime = Date()
        startPolling(commandId: resp.commandId)
    }

    func startPolling(commandId: UUID) {
        cancelPolling()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if let start = self.pollStartTime, Date().timeIntervalSince(start) > self.pollTimeout {
                    await MainActor.run { self.phase = .failed; self.errorMessage = "运行超时" }
                    return
                }
                do {
                    let status = try await self.networkClient.backtestStatusV2(commandId: commandId)
                    if status.commandStatus == "completed", let run = status.backtestRun {
                        await MainActor.run {
                            self.selectedRun = run
                            self.phase = .completed
                        }
                        await self.loadFailureClusters()
                        return
                    }
                    if ["failed", "error", "cancelled"].contains(status.commandStatus) {
                        await MainActor.run {
                            self.phase = .failed
                            self.errorMessage = status.errorMessage ?? "运行失败"
                        }
                        return
                    }
                } catch {
                    // 网络瞬时错误继续轮询
                }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    public func cancelPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    public func selectRun(_ run: BacktestRunV2) async {
        selectedRun = run
        if phase != .running { phase = .completed }
        await loadFailureClusters()
    }

    public func toggleCompare(runId: Int) async {
        if comparedRunIds.contains(runId) {
            comparedRunIds.remove(runId)
            comparedRuns.removeAll { $0.id == runId }
        } else {
            guard comparedRunIds.count < 3 else { return }
            comparedRunIds.insert(runId)
            do {
                let r = try await networkClient.getBacktestV2(id: runId)
                comparedRuns.append(r)
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func loadFailureClusters() async {
        guard let s = selectedStrategy, let u = s.uuid else { return }
        do {
            self.strategyFailureClusters = try await networkClient.getFailureClusters(strategyUuid: u)
        } catch {
            // 静默失败，聚类 section 显示空状态
        }
    }

    public func onDisappear() {
        cancelPolling()
    }
}
```

Note: `Strategy.uuid`, `Strategy.currentVersionId`, `NetworkClientProtocol.getWorkspaceSnapshot` must exist or be added. If `getWorkspaceSnapshot` doesn't exist, add it to `APIStrategiesV2.swift` (it already exists per explore — `GET /{strategy_id}/workspace`). Adjust to match actual signature.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd macos-app && swift test --filter BacktestLabViewModelTests`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add macos-app/AlphaLoop/ViewModels/BacktestLabViewModel.swift macos-app/Tests/BacktestLabViewModelTests.swift
git commit -m "feat(macos): rewrite BacktestLabViewModel with Phase state machine"
```

---

## Task 12: 前端 — L10n 新增 key

**Files:**
- Modify: `macos-app/AlphaLoop/Localization/L10n+Backtest.swift`

**Interfaces:**
- Produces: 所有九段 + 风险警告 + 空状态 + 错误文案的 L10n.BacktestLab.* key

- [ ] **Step 1: Add all new keys**

Edit `macos-app/AlphaLoop/Localization/L10n+Backtest.swift`, add inside `extension L10n.BacktestLab`:

```swift
        // MARK: - Phase / unlock hints
        static var phaseIdle: String { zh("请选择策略", en: "Select a strategy") }
        static var phaseConfiguring: String { zh("配置并运行回测", en: "Configure and run backtest") }
        static var phaseRunning: String { zh("运行中…", en: "Running…") }
        static var phaseWaitingComplete: String { zh("等待运行完成", en: "Waiting for run to complete") }

        // MARK: - Section titles
        static var sectionConfig: String { zh("运行参数", en: "Run Parameters") }
        static var sectionStatus: String { zh("运行状态", en: "Run Status") }
        static var sectionSummary: String { zh("收益摘要", en: "Return Summary") }
        static var sectionCurve: String { zh("权益曲线", en: "Equity Curve") }
        static var sectionTradeList: String { zh("交易列表", en: "Trade List") }
        static var sectionCompare: String { zh("历史对比", en: "Historical Compare") }
        static var sectionRisk: String { zh("风险诊断", en: "Risk Diagnostics") }
        static var sectionPromotion: String { zh("晋级实盘", en: "Promotion to Live") }
        static var sectionDataSource: String { zh("数据源", en: "Data Source") }

        // MARK: - ConfigPanel fields
        static var fieldTimeframe: String { zh("时间周期", en: "Timeframe") }
        static var fieldDateRange: String { zh("日期区间", en: "Date Range") }
        static var fieldSymbols: String { zh("交易对", en: "Symbols") }
        static var fieldCapital: String { zh("初始资金", en: "Initial Capital") }
        static var fieldFee: String { zh("手续费模型", en: "Fee Model") }
        static var fieldSlippage: String { zh("滑点模型", en: "Slippage") }
        static var fieldSlippageNone: String { zh("无", en: "None") }
        static var fieldSlippageBps: String { zh("固定 bps", en: "Fixed bps") }
        static var fieldSlippagePct: String { zh("百分比", en: "Percentage") }
        static var feeExchangeDefault: String { zh("交易所默认 (0.05%)", en: "Exchange default (0.05%)") }
        static var feeCustom: String { zh("自定义", en: "Custom") }

        // MARK: - StatusPanel
        static var statusBacktestCard: String { zh("回测", en: "Backtest") }
        static var statusDryrunCard: String { zh("模拟 (dry_run)", en: "Simulation (dry_run)") }
        static var statusPending: String { zh("待发起", en: "Idle") }
        static var statusRunning: String { zh("运行中", en: "Running") }
        static var statusCompleted: String { zh("已完成", en: "Completed") }
        static var statusFailed: String { zh("失败", en: "Failed") }
        static var statusNoRun: String { zh("尚无运行记录", en: "No runs yet") }
        static var statusViewLog: String { zh("查看日志", en: "View Log") }
        static var statusTimeout: String { zh("运行超时", en: "Run timed out") }

        // MARK: - SummaryPanel
        static var metricReturn: String { zh("收益", en: "Return") }
        static var metricMaxDrawdown: String { zh("最大回撤", en: "Max Drawdown") }
        static var metricWinRate: String { zh("胜率", en: "Win Rate") }
        static var metricProfitFactor: String { zh("盈亏比", en: "Profit Factor") }
        static var metricVsLast: String { zh("vs 上次", en: "vs last") }

        // MARK: - CurvePanel
        static var curveEquity: String { zh("权益", en: "Equity") }
        static var curveDrawdown: String { zh("回撤", en: "Drawdown") }
        static var curveEmpty: String { zh("本次运行未导出 equity curve 数据", en: "No equity curve exported for this run") }

        // MARK: - TradeListPanel
        static var colTime: String { zh("时间", en: "Time") }
        static var colPair: String { zh("交易对", en: "Pair") }
        static var colSide: String { zh("方向", en: "Side") }
        static var colEntry: String { zh("入场价", en: "Entry") }
        static var colExit: String { zh("出场价", en: "Exit") }
        static var colQty: String { zh("数量", en: "Qty") }
        static var colPnl: String { zh("盈亏", en: "PnL") }
        static var colDuration: String { zh("持仓时长", en: "Duration") }
        static var colMtf: String { zh("MTF 状态", en: "MTF State") }
        static var tradesEmpty: String { zh("本次运行无成交", en: "No trades in this run") }
        static var runClusterTitle: String { zh("本次 run 失败聚类", en: "In-run Failure Clusters") }
        static var runClusterTooFew: String { zh("亏损样本不足，无法聚类", en: "Too few losses to cluster") }

        // MARK: - ComparePanel
        static var compareEmpty: String { zh("在 Run Rail 勾选 run 启用对比", en: "Select runs in the rail to compare") }
        static var compareBest: String { zh("最佳", en: "Best") }

        // MARK: - RiskPanel
        static var strategyClusterTitle: String { zh("策略级失败聚类", en: "Strategy-level Failure Clusters") }
        static var strategyClusterEmpty: String { zh("暂无策略级失败聚类记录", en: "No strategy-level clusters") }
        static var generateShadow: String { zh("生成 shadow strategy", en: "Generate shadow strategy") }
        static var warnMaxDrawdown: String { zh("最大回撤超过 25%，风险过高", en: "Max drawdown exceeds 25%, too risky") }
        static var warnProfitFactor: String { zh("盈亏比 < 1，策略负期望", en: "Profit factor < 1, negative expectancy") }
        static var warnLowTrades: String { zh("样本不足，统计意义有限", en: "Sample too small, limited statistical significance") }
        static var warnLowWinrate: String { zh("胜率偏低", en: "Win rate low") }
        static var warnNegativeSharpe: String { zh("夏普为负，风险调整收益为负", en: "Negative Sharpe, risk-adjusted return negative") }
        static var runFailedNoResult: String { zh("本次运行失败，无结果可分析", en: "Run failed, no result to analyze") }

        // MARK: - PromotionPanel
        static var promotionTitle: String { zh("晋级实盘准入", en: "Live Promotion Gate") }
        static var promotionGrandStatus: String { zh("总状态", en: "Grand Status") }
        static var promotionGates: String { zh("闸门", en: "Gates") }
        static var promotionGateBacktest: String { zh("回测", en: "Backtest") }
        static var promotionGateDryrun: String { zh("模拟", en: "Dry-run") }
        static var ctaViewReadiness: String { zh("查看 Live Readiness 面板", en: "Open Live Readiness") }
        static var ctaGoLiveSmall: String { zh("前往启动 live_small", en: "Proceed to live_small") }
        static var promotionUnavailable: String { zh("准入评估暂不可用", en: "Promotion evaluation unavailable") }
        static var retry: String { zh("重试", en: "Retry") }

        // MARK: - DataSourceFooter
        static var dsEngine: String { zh("回测引擎", en: "Engine") }
        static var dsFreqtrade: String { zh("Freqtrade backtesting", en: "Freqtrade backtesting") }
        static var dsSource: String { zh("数据源", en: "Data source") }
        static var dsExecTime: String { zh("执行时间", en: "Exec time") }
        static var dsDslHash: String { zh("DSL hash", en: "DSL hash") }
        static var dsConfigSnapshot: String { zh("查看完整配置", en: "View full config") }

        // MARK: - MOCK
        static var mockBadge: String { zh("MOCK", en: "MOCK") }
        static var mockNoHistory: String { zh("mock 模式不提供历史数据", en: "Mock mode provides no historical data") }

        // MARK: - NewRunSheet
        static var sheetTitleBacktest: String { zh("新建回测", en: "New Backtest") }
        static var sheetTitleDryrun: String { zh("新建模拟", en: "New Dry-run") }
        static var sheetSubmit: String { zh("发起", en: "Start") }
        static var sheetCancel: String { zh("取消", en: "Cancel") }
        static var sheetSubmitting: String { zh("提交中…", en: "Submitting…") }
        static var sheetInvalidDate: String { zh("请选择有效的日期区间", en: "Select a valid date range") }
        static var sheetInvalidCapital: String { zh("初始资金必须大于 0", en: "Capital must be > 0") }
        static var sheetNoSymbols: String { zh("至少选择一个交易对", en: "Select at least one symbol") }
```

- [ ] **Step 2: Build to verify it compiles**

Run: `cd macos-app && swift build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add macos-app/AlphaLoop/Localization/L10n+Backtest.swift
git commit -m "feat(macos): add L10n keys for backtest lab nine sections"
```

---

## Task 13: 前端 — `NewRunSheet.swift` 重写

**Files:**
- Modify: `macos-app/AlphaLoop/Views/BacktestAndDryrun/NewRunSheet.swift` (重写)

**Interfaces:**
- Consumes: `BacktestLabViewModel` (Task 11), L10n keys (Task 12)
- Produces: `NewRunSheet` view with DatePicker / NumberFormatter / 多选交易对

- [ ] **Step 1: Write the view**

Replace contents of `macos-app/AlphaLoop/Views/BacktestAndDryrun/NewRunSheet.swift`:

```swift
import SwiftUI

struct NewRunSheet: View {
    @Environment(\.networkClient) private var networkClient
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: BacktestLabViewModel

    enum Mode: String, CaseIterable, Identifiable {
        case backtest, dryrun
        var id: String { rawValue }
        var label: String {
            switch self {
            case .backtest: return L10n.BacktestLab.sheetTitleBacktest
            case .dryrun: return L10n.BacktestLab.sheetTitleDryrun
            }
        }
    }

    @State private var mode: Mode = .backtest
    @State private var startDate: Date = Calendar.current.date(byAdding: -.month, to: Date()) ?? Date()
    @State private var endDate: Date = Date()
    @State private var capital: Double = 10000
    @State private var feeModel: String = "default"  // default | custom
    @State private var customFee: Double = 0.05
    @State private var slippageModel: String = "none"  // none | bps | pct
    @State private var slippageBps: Double = 3
    @State private var slippagePct: Double = 0.03
    @State private var selectedSymbols: Set<String> = []
    @State private var stakeAmount: Double = 100
    @State private var maxOpenTrades: Int = 5
    @State private var submitting = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.md) {
            Text(mode == .backtest ? L10n.BacktestLab.sheetTitleBacktest : L10n.BacktestLab.sheetTitleDryrun)
                .font(PulseFonts.title3)
            Picker("Mode", selection: $mode) {
                ForEach(Mode.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)

            Form {
                Section(L10n.BacktestLab.fieldSymbols) {
                    ForEach(availableSymbols, id: \.self) { s in
                        Toggle(s, isOn: Binding(
                            get: { selectedSymbols.contains(s) },
                            set: { v in if v { selectedSymbols.insert(s) } else { selectedSymbols.remove(s) } }
                        ))
                    }
                }
                if mode == .backtest {
                    Section(L10n.BacktestLab.fieldDateRange) {
                        DatePicker(L10n.BacktestLab.fieldDateRange, selection: $startDate, displayedComponents: .date)
                        DatePicker("—", selection: $endDate, in: startDate..., displayedComponents: .date)
                    }
                }
                Section(L10n.BacktestLab.fieldCapital) {
                    TextField(L10n.BacktestLab.fieldCapital, value: $capital, format: .number)
                        .textFieldStyle(.roundedBorder)
                }
                Section(L10n.BacktestLab.fieldFee) {
                    Picker(L10n.BacktestLab.fieldFee, selection: $feeModel) {
                        Text(L10n.BacktestLab.feeExchangeDefault).tag("default")
                        Text(L10n.BacktestLab.feeCustom).tag("custom")
                    }
                    if feeModel == "custom" {
                        TextField("fee %", value: $customFee, format: .number)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                Section(L10n.BacktestLab.fieldSlippage) {
                    Picker(L10n.BacktestLab.fieldSlippage, selection: $slippageModel) {
                        Text(L10n.BacktestLab.fieldSlippageNone).tag("none")
                        Text(L10n.BacktestLab.fieldSlippageBps).tag("bps")
                        Text(L10n.BacktestLab.fieldSlippagePct).tag("pct")
                    }
                    if slippageModel == "bps" {
                        TextField("bps", value: $slippageBps, format: .number)
                            .textFieldStyle(.roundedBorder)
                    } else if slippageModel == "pct" {
                        TextField("%", value: $slippagePct, format: .number)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                if mode == .dryrun {
                    Section("Stake") {
                        TextField("stake_amount", value: $stakeAmount, format: .number)
                        TextField("max_open_trades", value: $maxOpenTrades, format: .number)
                    }
                }
            }
            .formStyle(.grouped)

            if let error {
                Text(error).foregroundStyle(.red).font(PulseFonts.caption)
            }

            HStack {
                Button(L10n.BacktestLab.sheetCancel) { dismiss() }
                Spacer()
                Button(L10n.BacktestLab.sheetSubmit) {
                    Task { await submit() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(submitting || !isValid)
            }
        }
        .padding()
        .frame(minWidth: 480, minHeight: 560)
        .onAppear {
            if let s = viewModel.selectedStrategy {
                selectedSymbols = Set(s.symbols)
            }
        }
    }

    private var availableSymbols: [String] {
        viewModel.selectedStrategy?.symbols ?? []
    }

    private var isValid: Bool {
        guard !selectedSymbols.isEmpty else { return false }
        if capital <= 0 { return false }
        if mode == .backtest && startDate >= endDate { return false }
        return true
    }

    private func submit() async {
        submitting = true
        error = nil
        defer { submitting = false }
        do {
            let timerange = stringTimerange()
            let fee: Double? = feeModel == "custom" ? customFee / 100 : nil
            let slipBps: Double? = slippageModel == "bps" ? slippageBps
                                  : slippageModel == "pct" ? slippagePct * 100 : nil
            try await viewModel.startBacktest(
                timerange: timerange,
                symbols: Array(selectedSymbols),
                capital: capital,
                slippageBps: slipBps
            )
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func stringTimerange() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMdd"
        return "\(fmt.string(from: startDate))-\(fmt.string(from: endDate))"
    }
}
```

Note: `Strategy.symbols` must exist on the model. If it doesn't, derive from DSL (`dsl["symbols"]`).

- [ ] **Step 2: Build to verify it compiles**

Run: `cd macos-app && swift build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add macos-app/AlphaLoop/Views/BacktestAndDryrun/NewRunSheet.swift
git commit -m "feat(macos): rewrite NewRunSheet with real form controls"
```

---

## Task 14: 前端 — Section views (ConfigPanel + StatusPanel + SummaryPanel)

**Files:**
- Create: `macos-app/AlphaLoop/Views/BacktestAndDryrun/Sections/ConfigPanel.swift`
- Create: `macos-app/AlphaLoop/Views/BacktestAndDryrun/Sections/StatusPanel.swift`
- Create: `macos-app/AlphaLoop/Views/BacktestAndDryrun/Sections/SummaryPanel.swift`

**Interfaces:**
- Consumes: `BacktestLabViewModel`, L10n keys

- [ ] **Step 1: Write ConfigPanel**

Create `macos-app/AlphaLoop/Views/BacktestAndDryrun/Sections/ConfigPanel.swift`:

```swift
import SwiftUI

struct ConfigPanel: View {
    @Bindable var viewModel: BacktestLabViewModel

    var body: some View {
        SectionCard(title: L10n.BacktestLab.sectionConfig, locked: viewModel.phase == .running) {
            if let s = viewModel.selectedStrategy {
                LabeledContent(L10n.BacktestLab.fieldTimeframe, value: s.timeframe ?? "—")
                LabeledContent(L10n.BacktestLab.fieldSymbols, value: (s.symbols).joined(separator: ", "))
                LabeledContent(L10n.BacktestLab.fieldCapital, value: String(format: "%.0f", viewModel.selectedRun?.initialCapital ?? 0))
            } else {
                Text(L10n.BacktestLab.phaseIdle).foregroundStyle(.secondary)
            }
        }
    }
}
```

Note: `Strategy.timeframe` may need to be a computed property reading `dsl["timeframe"]`. If it doesn't exist, add it.

- [ ] **Step 2: Write StatusPanel**

Create `macos-app/AlphaLoop/Views/BacktestAndDryrun/Sections/StatusPanel.swift`:

```swift
import SwiftUI

struct StatusPanel: View {
    @Bindable var viewModel: BacktestLabViewModel

    var body: some View {
        SectionCard(title: L10n.BacktestLab.sectionStatus) {
            HStack(spacing: PulseSpacing.md) {
                statusCard(title: L10n.BacktestLab.statusBacktestCard,
                           status: viewModel.selectedRun?.status,
                           errorMessage: viewModel.selectedRun?.errorMessage)
                Divider().frame(height: 60)
                statusCard(title: L10n.BacktestLab.statusDryrunCard,
                           status: viewModel.recentDryruns.first?.status,
                           errorMessage: viewModel.recentDryruns.first?.errorMessage)
            }
        }
    }

    private func statusCard(title: String, status: String?, errorMessage: String?) -> some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            Text(title).font(PulseFonts.caption).foregroundStyle(.secondary)
            if let status {
                HStack {
                    Circle().fill(statusColor(status)).frame(width: 8, height: 8)
                    Text(statusLabel(status)).font(PulseFonts.body)
                }
                if let errorMessage, status == "failed" || status == "error" {
                    Text(errorMessage).font(PulseFonts.caption).foregroundStyle(.red)
                    Button(L10n.BacktestLab.statusViewLog) { /* navigate to ExecutionRecordsView */ }
                        .font(PulseFonts.caption)
                }
            } else {
                Text(L10n.BacktestLab.statusNoRun).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statusColor(_ s: String) -> Color {
        switch s {
        case "completed": return .green
        case "running": return .blue
        case "failed", "error": return .red
        default: return .gray
        }
    }

    private func statusLabel(_ s: String) -> String {
        switch s {
        case "pending", "starting": return L10n.BacktestLab.statusPending
        case "running": return L10n.BacktestLab.statusRunning
        case "completed": return L10n.BacktestLab.statusCompleted
        case "failed", "error": return L10n.BacktestLab.statusFailed
        default: return s
        }
    }
}
```

- [ ] **Step 3: Write SummaryPanel**

Create `macos-app/AlphaLoop/Views/BacktestAndDryrun/Sections/SummaryPanel.swift`:

```swift
import SwiftUI

struct SummaryPanel: View {
    @Bindable var viewModel: BacktestLabViewModel

    var body: some View {
        SectionCard(title: L10n.BacktestLab.sectionSummary,
                    locked: viewModel.phase != .completed) {
            if viewModel.phase != .completed {
                Text(L10n.BacktestLab.phaseWaitingComplete).foregroundStyle(.secondary)
            } else if let r = viewModel.selectedRun {
                HStack(spacing: PulseSpacing.lg) {
                    metricCard(L10n.BacktestLab.metricReturn,
                               value: r.totalReturn, context: vsLastContext(r))
                    metricCard(L10n.BacktestLab.metricMaxDrawdown,
                               value: r.maxDrawdown, context: nil, alwaysNegative: true)
                    metricCard(L10n.BacktestLab.metricWinRate,
                               value: r.winRate, context: "\(r.totalTrades) trades", asPercent: true)
                    metricCard(L10n.BacktestLab.metricProfitFactor,
                               value: r.profitFactor, context: nil)
                }
            }
        }
    }

    private func vsLastContext(_ r: BacktestRunV2) -> String? {
        guard let prev = viewModel.recentBacktests.first(where: { $0.id != r.id }) else { return nil }
        let diff = r.totalReturn - prev.totalReturn
        let sign = diff >= 0 ? "+" : ""
        return "\(L10n.BacktestLab.metricVsLast) \(sign)\(String(format: "%.2f%%", diff * 100))"
    }

    private func metricCard(_ title: String, value: Double, context: String?,
                            alwaysNegative: Bool = false, asPercent: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            Text(title).font(PulseFonts.caption).foregroundStyle(.secondary)
            Text(asPercent ? String(format: "%.1f%%", value * 100) : String(format: "%.3f", value))
                .font(PulseFonts.title2.monospacedDigit())
                .foregroundStyle(alwaysNegative ? .red : (value >= 0 ? PulseColors.success : PulseColors.danger))
            if let context {
                Text(context).font(PulseFonts.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
```

Note: `SectionCard` is a reusable wrapper — if it doesn't exist, create `macos-app/AlphaLoop/Views/BacktestAndDryrun/Sections/SectionCard.swift`:

```swift
import SwiftUI

struct SectionCard<Content: View>: View {
    let title: String
    var locked: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            HStack {
                Text(title).font(PulseFonts.headline)
                Spacer()
                if locked {
                    Image(systemName: "lock.fill").foregroundStyle(.secondary).font(.caption)
                }
            }
            content
        }
        .padding(PulseSpacing.md)
        .glassEffect()
        .opacity(locked ? 0.4 : 1.0)
    }
}
```

- [ ] **Step 4: Build to verify it compiles**

Run: `cd macos-app && swift build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add macos-app/AlphaLoop/Views/BacktestAndDryrun/Sections/
git commit -m "feat(macos): add ConfigPanel/StatusPanel/SummaryPanel sections"
```

---

## Task 15: 前端 — CurvePanel + TradeListPanel

**Files:**
- Create: `macos-app/AlphaLoop/Views/BacktestAndDryrun/Sections/CurvePanel.swift`
- Create: `macos-app/AlphaLoop/Views/BacktestAndDryrun/Sections/TradeListPanel.swift`

**Interfaces:**
- Consumes: `EquityPoint` / `TradeRow` (Task 6), `clusterFailures` (Task 10)

- [ ] **Step 1: Write CurvePanel**

Create `macos-app/AlphaLoop/Views/BacktestAndDryrun/Sections/CurvePanel.swift`:

```swift
import SwiftUI
import Charts

struct CurvePanel: View {
    @Bindable var viewModel: BacktestLabViewModel

    var body: some View {
        SectionCard(title: L10n.BacktestLab.sectionCurve, locked: viewModel.phase != .completed) {
            if viewModel.phase != .completed {
                Text(L10n.BacktestLab.phaseWaitingComplete).foregroundStyle(.secondary)
            } else if let r = viewModel.selectedRun {
                if r.equityCurve.isEmpty {
                    Text(L10n.BacktestLab.curveEmpty).foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: PulseSpacing.md) {
                        Chart {
                            ForEach(r.equityCurve) { pt in
                                LineMark(x: .value("Time", pt.timestamp), y: .value("Equity", pt.equity))
                                    .foregroundStyle(PulseColors.primary)
                                AreaMark(x: .value("Time", pt.timestamp), y: .value("Equity", pt.equity))
                                    .foregroundStyle(.linearGradient(colors: [PulseColors.primary.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))
                            }
                        }
                        .chartYAxis { AxisMarks(position: .leading) }
                        .frame(height: 180)

                        Chart {
                            ForEach(r.equityCurve) { pt in
                                BarMark(x: .value("Time", pt.timestamp), y: .value("Drawdown", pt.drawdown))
                                    .foregroundStyle(.red)
                            }
                        }
                        .frame(height: 80)
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 2: Write TradeListPanel**

Create `macos-app/AlphaLoop/Views/BacktestAndDryrun/Sections/TradeListPanel.swift`:

```swift
import SwiftUI

struct TradeListPanel: View {
    @Bindable var viewModel: BacktestLabViewModel

    var body: some View {
        SectionCard(title: L10n.BacktestLab.sectionTradeList, locked: viewModel.phase != .completed) {
            if viewModel.phase != .completed {
                Text(L10n.BacktestLab.phaseWaitingComplete).foregroundStyle(.secondary)
            } else if let r = viewModel.selectedRun {
                if r.trades.isEmpty {
                    Text(L10n.BacktestLab.tradesEmpty).foregroundStyle(.secondary)
                } else {
                    tradesTable(r.trades)
                    runClusters(r.trades)
                }
            }
        }
    }

    @ViewBuilder
    private func tradesTable(_ trades: [TradeRow]) -> some View {
        Table(trades) {
            TableColumn(L10n.BacktestLab.colTime) { Text($0.openTime) }
            TableColumn(L10n.BacktestLab.colPair) { Text($0.pair) }
            TableColumn(L10n.BacktestLab.colSide) { Text($0.side) }
            TableColumn(L10n.BacktestLab.colEntry) { Text(String(format: "%.2f", $0.openPrice)) }
            TableColumn(L10n.BacktestLab.colExit) { Text(String(format: "%.2f", $0.closePrice)) }
            TableColumn(L10n.BacktestLab.colQty) { Text(String(format: "%.4f", $0.quantity)) }
            TableColumn(L10n.BacktestLab.colPnl) { row in
                Text(String(format: "%.2f", row.profit))
                    .foregroundStyle(row.profit >= 0 ? PulseColors.success : PulseColors.danger)
            }
            TableColumn(L10n.BacktestLab.colDuration) { Text($0.duration) }
            TableColumn(L10n.BacktestLab.colMtf) { Text($0.mtfState ?? "—") }
        }
        .frame(minHeight: 240)
    }

    @ViewBuilder
    private func runClusters(_ trades: [TradeRow]) -> some View {
        let clusters = clusterFailures(in: trades)
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            Text(L10n.BacktestLab.runClusterTitle).font(PulseFonts.headline)
            if clusters.isEmpty {
                Text(L10n.BacktestLab.runClusterTooFew).foregroundStyle(.secondary)
            } else {
                ForEach(clusters) { c in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(c.label).font(PulseFonts.body)
                            Text(c.commonFeatures.joined(separator: " · ")).font(PulseFonts.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("n=\(c.sampleSize)").font(PulseFonts.caption)
                            Text(String(format: "%.2f", c.totalLoss))
                                .foregroundStyle(.red).font(PulseFonts.caption)
                        }
                    }
                    .padding(PulseSpacing.xs)
                    .background(Color.red.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
                }
            }
        }
    }
}
```

- [ ] **Step 3: Build to verify it compiles**

Run: `cd macos-app && swift build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add macos-app/AlphaLoop/Views/BacktestAndDryrun/Sections/CurvePanel.swift macos-app/AlphaLoop/Views/BacktestAndDryrun/Sections/TradeListPanel.swift
git commit -m "feat(macos): add CurvePanel with Swift Charts and TradeListPanel"
```

---

## Task 16: 前端 — ComparePanel + RiskPanel + PromotionPanel + DataSourceFooter

**Files:**
- Create: `macos-app/AlphaLoop/Views/BacktestAndDryrun/Sections/ComparePanel.swift`
- Create: `macos-app/AlphaLoop/Views/BacktestAndDryrun/Sections/RiskPanel.swift`
- Create: `macos-app/AlphaLoop/Views/BacktestAndDryrun/Sections/PromotionPanel.swift`
- Create: `macos-app/AlphaLoop/Views/BacktestAndDryrun/Sections/DataSourceFooter.swift`

- [ ] **Step 1: Write ComparePanel**

Create `macos-app/AlphaLoop/Views/BacktestAndDryrun/Sections/ComparePanel.swift`:

```swift
import SwiftUI
import Charts

struct ComparePanel: View {
    @Bindable var viewModel: BacktestLabViewModel

    var body: some View {
        if !viewModel.comparedRunIds.isEmpty {
            SectionCard(title: L10n.BacktestLab.sectionCompare) {
                matrix
                if !viewModel.comparedRuns.isEmpty {
                    overlayChart
                }
            }
        } else {
            SectionCard(title: L10n.BacktestLab.sectionCompare) {
                Text(L10n.BacktestLab.compareEmpty).foregroundStyle(.secondary)
            }
        }
    }

    private var matrix: some View {
        let runs = viewModel.comparedRuns
        return Table(runs) {
            TableColumn("Run") { Text("#\($0.id)") }
            TableColumn(L10n.BacktestLab.metricReturn) { Text(String(format: "%.2f%%", $0.totalReturn * 100)) }
            TableColumn("Sharpe") { Text(String(format: "%.2f", $0.sharpeRatio)) }
            TableColumn(L10n.BacktestLab.metricMaxDrawdown) { Text(String(format: "%.2f%%", $0.maxDrawdown * 100)) }
            TableColumn(L10n.BacktestLab.metricWinRate) { Text(String(format: "%.1f%%", $0.winRate * 100)) }
            TableColumn(L10n.BacktestLab.metricProfitFactor) { Text(String(format: "%.2f", $0.profitFactor)) }
            TableColumn("Trades") { Text("\($0.totalTrades)") }
        }
        .frame(minHeight: CGFloat(max(80, runs.count * 36)))
    }

    private var overlayChart: some View {
        let colors: [Color] = [.blue, .green, .orange]
        return Chart {
            ForEach(Array(viewModel.comparedRuns.enumerated()), id: \.element.id) { idx, run in
                ForEach(run.equityCurve) { pt in
                    LineMark(x: .value("Time", pt.timestamp), y: .value("Equity", pt.equity))
                        .foregroundStyle(colors[idx % colors.count])
                }
            }
        }
        .frame(height: 180)
    }
}
```

- [ ] **Step 2: Write RiskPanel**

Create `macos-app/AlphaLoop/Views/BacktestAndDryrun/Sections/RiskPanel.swift`:

```swift
import SwiftUI

struct RiskPanel: View {
    @Bindable var viewModel: BacktestLabViewModel

    var body: some View {
        SectionCard(title: L10n.BacktestLab.sectionRisk) {
            if viewModel.phase == .failed {
                Text(L10n.BacktestLab.runFailedNoResult).foregroundStyle(.red)
            } else if let r = viewModel.selectedRun {
                let m = BacktestMetrics(totalReturn: r.totalReturn, sharpeRatio: r.sharpeRatio,
                                        maxDrawdown: r.maxDrawdown, winRate: r.winRate,
                                        profitFactor: r.profitFactor, totalTrades: r.totalTrades,
                                        avgTradeDuration: "", bestTrade: 0, worstTrade: 0)
                let ws = riskWarnings(for: m)
                if !ws.isEmpty {
                    VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                        ForEach(ws) { w in
                            HStack {
                                Circle().fill(w.level == .red ? .red : .yellow).frame(width: 8, height: 8)
                                Text(w.message).font(PulseFonts.body)
                                Spacer()
                            }
                            .padding(PulseSpacing.xs)
                            .background((w.level == .red ? Color.red : Color.yellow).opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
                        }
                    }
                }
                strategyClusters
            }
        }
    }

    @ViewBuilder
    private var strategyClusters: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            Text(L10n.BacktestLab.strategyClusterTitle).font(PulseFonts.headline)
            if viewModel.strategyFailureClusters.isEmpty {
                Text(L10n.BacktestLab.strategyClusterEmpty).foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.strategyFailureClusters) { c in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(c.label).font(PulseFonts.body)
                            Text(c.commonFeatures.joined(separator: " · ")).font(PulseFonts.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("n=\(c.sampleSize)").font(PulseFonts.caption)
                            Text(String(format: "%.2f", c.totalLoss)).foregroundStyle(.red).font(PulseFonts.caption)
                        }
                        Button(L10n.BacktestLab.generateShadow) { /* navigate to shadow strategy flow */ }
                            .font(PulseFonts.caption)
                    }
                    .padding(PulseSpacing.xs)
                    .background(Color.red.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
                }
            }
        }
    }
}
```

- [ ] **Step 3: Write PromotionPanel**

Create `macos-app/AlphaLoop/Views/BacktestAndDryrun/Sections/PromotionPanel.swift`:

```swift
import SwiftUI

struct PromotionPanel: View {
    @Bindable var viewModel: BacktestLabViewModel
    @Environment(AppState.self) private var appState

    var body: some View {
        SectionCard(title: L10n.BacktestLab.sectionPromotion) {
            if let r = viewModel.readiness {
                VStack(alignment: .leading, spacing: PulseSpacing.md) {
                    HStack {
                        Text(L10n.BacktestLab.promotionGrandStatus).font(PulseFonts.caption).foregroundStyle(.secondary)
                        Text(r.grandStatus).font(PulseFonts.body.weight(.semibold))
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                        ForEach(r.gates) { g in
                            HStack {
                                Circle().fill(g.status == "pass" ? .green : (g.status == "fail" ? .red : .gray))
                                    .frame(width: 8, height: 8)
                                Text(g.name)
                                Spacer()
                                if g.name.lowercased().contains("backtest") || g.name.lowercased().contains("dry") {
                                    Text(g.status).font(PulseFonts.caption.weight(.semibold))
                                } else {
                                    Text(g.status).font(PulseFonts.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    Button {
                        appState.selectedRoute = .liveReadiness
                    } label: {
                        Text(r.grandStatus == "ready_for_live"
                             ? L10n.BacktestLab.ctaGoLiveSmall
                             : L10n.BacktestLab.ctaViewReadiness)
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                Text(L10n.BacktestLab.promotionUnavailable).foregroundStyle(.secondary)
                Button(L10n.BacktestLab.retry) { Task { await viewModel.loadWorkspaceSnapshot() } }
            }
        }
    }
}
```

Note: `PerStrategyReadinessResponse` shape must match existing `Services/APIStrategiesV2.swift`. Adjust field names (`grandStatus`, `gates`) to match actual Swift property names.

- [ ] **Step 4: Write DataSourceFooter**

Create `macos-app/AlphaLoop/Views/BacktestAndDryrun/Sections/DataSourceFooter.swift`:

```swift
import SwiftUI

struct DataSourceFooter: View {
    @Bindable var viewModel: BacktestLabViewModel
    @State private var showConfig = false

    var body: some View {
        if let r = viewModel.selectedRun, viewModel.phase == .completed {
            VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                HStack(spacing: PulseSpacing.md) {
                    Label("\(L10n.BacktestLab.dsEngine): \(L10n.BacktestLab.dsFreqtrade)", systemImage: "cpu")
                    Label("\(L10n.BacktestLab.dsSource): \(r.symbols.first ?? "—")", systemImage: "chart.bar")
                    if let c = r.completedAt, let cr = r.createdAt {
                        Label("\(L10n.BacktestLab.dsExecTime): \(formatDuration(c.timeIntervalSince(cr)))", systemImage: "clock")
                    }
                    if let h = r.dslHash {
                        Label("\(L10n.BacktestLab.dsDslHash): \(h.prefix(8))", systemImage: "number")
                    }
                }
                .font(PulseFonts.caption)
                .foregroundStyle(.secondary)
                Button(L10n.BacktestLab.dsConfigSnapshot) { showConfig = true }
                    .font(PulseFonts.caption)
            }
            .sheet(isPresented: $showConfig) {
                ScrollView {
                    Text(String(describing: r.config)).font(PulseFonts.body.monospaced())
                        .padding()
                }
            }
        }
    }

    private func formatDuration(_ s: TimeInterval) -> String {
        let m = Int(s / 60); let sec = Int(s) % 60
        return "\(m)m\(sec)s"
    }
}
```

- [ ] **Step 5: Build to verify it compiles**

Run: `cd macos-app && swift build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 6: Commit**

```bash
git add macos-app/AlphaLoop/Views/BacktestAndDryrun/Sections/ComparePanel.swift macos-app/AlphaLoop/Views/BacktestAndDryrun/Sections/RiskPanel.swift macos-app/AlphaLoop/Views/BacktestAndDryrun/Sections/PromotionPanel.swift macos-app/AlphaLoop/Views/BacktestAndDryrun/Sections/DataSourceFooter.swift
git commit -m "feat(macos): add ComparePanel/RiskPanel/PromotionPanel/DataSourceFooter"
```

---

## Task 17: 前端 — `BacktestLabView` 主视图重写（九段装配）

**Files:**
- Modify: `macos-app/AlphaLoop/Views/BacktestAndDryrun/BacktestLabView.swift` (重写)

- [ ] **Step 1: Write the view**

Replace contents of `macos-app/AlphaLoop/Views/BacktestAndDryrun/BacktestLabView.swift`:

```swift
import SwiftUI

struct BacktestLabView: View {
    @State private var viewModel = BacktestLabViewModel()
    @State private var showingNewRunSheet = false
    @Environment(\.networkClient) private var networkClient
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 0) {
            runRail
                .frame(width: 240)
                .background(Color.black.opacity(0.2))
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: PulseSpacing.lg) {
                    ConfigPanel(viewModel: viewModel)
                    StatusPanel(viewModel: viewModel)
                    SummaryPanel(viewModel: viewModel)
                    CurvePanel(viewModel: viewModel)
                    TradeListPanel(viewModel: viewModel)
                    ComparePanel(viewModel: viewModel)
                    RiskPanel(viewModel: viewModel)
                    PromotionPanel(viewModel: viewModel)
                    DataSourceFooter(viewModel: viewModel)
                }
                .padding(PulseSpacing.lg)
            }
        }
        .navigationTitle(L10n.BacktestLab.title)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                strategyPicker
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack {
                    if networkClient is MockNetworkClient {
                        Text(L10n.BacktestLab.mockBadge)
                            .font(PulseFonts.caption.weight(.bold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.red).foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    Button { showingNewRunSheet = true } label: { Image(systemName: "plus") }
                        .disabled(viewModel.phase == .running)
                }
            }
        }
        .sheet(isPresented: $showingNewRunSheet) {
            NewRunSheet(viewModel: viewModel)
        }
        .task {
            viewModel.networkClient = networkClient
        }
        .onDisappear { viewModel.onDisappear() }
    }

    private var runRail: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            Text(L10n.BacktestLab.runRail).font(PulseFonts.headline).padding(PulseSpacing.sm)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: PulseSpacing.xs) {
                    ForEach(viewModel.recentBacktests) { run in
                        RunRailRow(run: run, isSelected: viewModel.selectedRun?.id == run.id,
                                   isCompared: viewModel.comparedRunIds.contains(run.id)) {
                            Task { await viewModel.selectRun(run) }
                        } onCompare: {
                            Task { await viewModel.toggleCompare(runId: run.id) }
                        }
                    }
                    if viewModel.recentBacktests.isEmpty {
                        Text(L10n.BacktestLab.runEmpty).foregroundStyle(.secondary).padding()
                    }
                }
            }
        }
    }

    private var strategyPicker: some View {
        Picker(L10n.BacktestLab.strategyPicker, selection: Binding(
            get: { viewModel.selectedStrategy },
            set: { s in if let s { Task { await viewModel.selectStrategy(s) } } }
        )) {
            Text(L10n.BacktestLab.noStrategy).tag(nil as Strategy?)
            ForEach(strategies) { Text($0.name).tag(Optional($0)) }
        }
    }

    private var strategies: [Strategy] {
        // 同步从 viewModel 缓存或 environment 取；此处简化为 viewModel 持有
        viewModel.availableStrategies
    }
}

struct RunRailRow: View {
    let run: BacktestRunV2
    let isSelected: Bool
    let isCompared: Bool
    let onTap: () -> Void
    let onCompare: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Button(action: onTap) {
                    Text("#\(run.id)").font(PulseFonts.body.weight(isSelected ? .bold : .regular))
                }.buttonStyle(.plain)
                Spacer()
                Button(action: onCompare) {
                    Image(systemName: isCompared ? "checkmark.square.fill" : "square")
                }.buttonStyle(.plain)
            }
            Text(String(format: "%.2f%%", run.totalReturn * 100))
                .font(PulseFonts.caption.monospacedDigit())
                .foregroundStyle(run.totalReturn >= 0 ? .green : .red)
            Text(run.startDate + " → " + run.endDate).font(PulseFonts.caption2).foregroundStyle(.secondary)
        }
        .padding(PulseSpacing.xs)
        .background(isSelected ? PulseColors.primary.opacity(0.15) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
    }
}
```

Note: `viewModel.availableStrategies` must be added to the ViewModel — fetch via `APIStrategiesV2.list()` on `task` modifier. Add it as a property + load in `.task`.

- [ ] **Step 2: Build to verify it compiles**

Run: `cd macos-app && swift build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Run app and smoke test**

Run: `cd macos-app && swift run`
Manually verify:
- 页面打开显示 Run Rail + 九段（灰阶占位）
- 选策略后 ① 可编辑
- 点 + 弹 NewRunSheet
- 提交后 ② 显示 running
- mock 模式 TopBar 显示 MOCK 徽章

- [ ] **Step 4: Commit**

```bash
git add macos-app/AlphaLoop/Views/BacktestAndDryrun/BacktestLabView.swift
git commit -m "feat(macos): rewrite BacktestLabView as 9-section narrative flow"
```

---

## Task 18: 前端 — ViewModel 加 `availableStrategies` 加载

**Files:**
- Modify: `macos-app/AlphaLoop/ViewModels/BacktestLabViewModel.swift`

- [ ] **Step 1: Add property and loader**

In `BacktestLabViewModel`, add:

```swift
    public var availableStrategies: [Strategy] = []

    public func loadStrategies() async {
        do {
            self.availableStrategies = try await networkClient.listStrategiesV2()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
```

Call `loadStrategies()` in `.task` of `BacktestLabView`.

Note: `listStrategiesV2` must exist on `NetworkClientProtocol` (likely already in `APIStrategiesV2.swift`). If not, add it.

- [ ] **Step 2: Update BacktestLabView.task**

In `BacktestLabView.swift`:

```swift
        .task {
            viewModel.networkClient = networkClient
            await viewModel.loadStrategies()
        }
```

- [ ] **Step 3: Build + test**

Run: `cd macos-app && swift build && swift test --filter BacktestLabViewModelTests`
Expected: BUILD SUCCEEDED, tests PASS.

- [ ] **Step 4: Commit**

```bash
git add macos-app/AlphaLoop/ViewModels/BacktestLabViewModel.swift macos-app/AlphaLoop/Views/BacktestAndDryrun/BacktestLabView.swift
git commit -m "feat(macos): load available strategies in BacktestLabViewModel"
```

---

## Task 19: 前端 — 全量前端测试 + 回归

**Files:**
- Test: `macos-app/Tests/`

- [ ] **Step 1: Run full test suite**

Run: `cd macos-app && swift test`
Expected: All tests pass.

- [ ] **Step 2: If failures, fix**

Likely issues: mock factory field mismatches; `Strategy` constructor; `AppState` route name `.liveReadiness` vs `.liveReadinessView`. Fix inline.

- [ ] **Step 3: Commit fixes**

```bash
git add -A
git commit -m "test(macos): regression fixes for backtest lab rewrite"
```

(Only if there were fixes.)

---

## Task 20: 文档 — user-guide 双语章节重写

**Files:**
- Modify: `docs/user-guide/content/zh/pages/strategy/backtest-simulation.html`
- Modify: `docs/user-guide/content/en/pages/strategy/backtest-simulation.html`
- Modify: `docs/README.md` (if index references the chapter)

- [ ] **Step 1: Rewrite zh chapter**

Open `docs/user-guide/content/zh/pages/strategy/backtest-simulation.html` and replace body content with nine-section narrative matching the new UI: 运行参数 / 运行状态 / 收益摘要 / 权益曲线 / 交易列表与失败聚类 / 历史对比 / 风险诊断与策略级聚类 / 晋级实盘准入 / 数据源说明. Cover:
- 各段在什么 phase 解锁。
- 失败聚类分 run 内 + 策略级两层。
- 晋级 CTA 只跳转 Live Readiness，本页不直接启动实盘。
- mock 模式标识。
- 风险警告规则。

- [ ] **Step 2: Rewrite en chapter**

Mirror the zh content in `docs/user-guide/content/en/pages/strategy/backtest-simulation.html`.

- [ ] **Step 3: Update docs/README.md index if needed**

Check `docs/README.md` for any reference to backtest-sim chapter and ensure the description matches the new page.

- [ ] **Step 4: Commit**

```bash
git add docs/user-guide/content/zh/pages/strategy/backtest-simulation.html docs/user-guide/content/en/pages/strategy/backtest-simulation.html docs/README.md
git commit -m "docs(user-guide): rewrite backtest-simulation chapter for nine-section flow"
```

---

## Task 21: 文档 — 更新 `CLAUDE.md` BacktestLabView 描述

**Files:**
- Modify: `CLAUDE.md` (macOS app section, around the line describing `BacktestLabView`)

- [ ] **Step 1: Locate the current description**

Run: `grep -n "BacktestLabView" CLAUDE.md`

- [ ] **Step 2: Replace the description**

Change the line from the 3-column description to:

```markdown
- **`Views/BacktestAndDryrun/BacktestLabView`** — Backtest & simulation page as single-page nine-section narrative flow (ConfigPanel → StatusPanel → SummaryPanel → CurvePanel → TradeListPanel → ComparePanel → RiskPanel → PromotionPanel → DataSourceFooter). Driven by `BacktestLabViewModel` with `Phase` state machine (idle/configuring/running/completed/failed). Real backend data only; no client-side PRNG equity curve. Mock mode shows `MOCK` badge and empty history list.
```

Also update the line mentioning `DryrunMonitorView` if present (it doesn't exist — remove that mention).

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs(claude.md): update BacktestLabView description for narrative flow"
```

---

## Task 22: 终态验收 — 手工清单核对

**Files:** none

- [ ] **Step 1: Start backend + frontend**

```bash
cd backend && python3 run.py &
cd macos-app && swift run
```

- [ ] **Step 2: Walk the acceptance checklist from spec §8**

For each item, verify manually in the running app. Document any failures as a follow-up task. Key items:
- [ ] 链路：选策略 → 配置 → 运行 → ② 进度 → ③-⑧ 解锁 → ⑧ 闸门状态
- [ ] equity curve = 后端 `result.equity_curve`，断网不伪造
- [ ] mock 模式显示 MOCK 徽章 + 历史空
- [ ] 运行失败时 ② 错误 + ③-⑥ 隐藏 + ⑦ 失败提示 + ⑧ 闸门未通过
- [ ] 对比勾选 2-3 个 run → ⑥ 展开
- [ ] run 内聚类 ≥5 亏损 trades 时展示
- [ ] 策略级聚类展示 + 生成 shadow strategy 跳转
- [ ] 晋级 CTA 跳 `.liveReadiness`，本页不发实盘请求
- [ ] i18n 中英切换实时
- [ ] `max_drawdown <= -25%` 红色警告条

- [ ] **Step 3: If any item fails, file follow-up tasks**

Don't mark this task complete until the golden path (backtest happy path) works end-to-end with real backend.

- [ ] **Step 4: Final commit (if any fixes)**

```bash
git add -A
git commit -m "fix(backtest-lab): acceptance checklist follow-ups"
```

---

## Self-Review

**Spec coverage:**
- §1 范围 → Task 1-22 全覆盖，明确排除项在文档 task 中遵守。
- §2 整体架构 → Task 17 (主视图) + Task 11 (ViewModel Phase 状态机) + Task 14-16 (各 section)。
- §3 组件细化 → Task 12 (L10n) + Task 13 (NewRunSheet) + Task 14-16 (九段) + Task 18 (strategies loader)。
- §4 后端改动 → Task 1-4 (slippage / 强类型 / failure-clusters) + Task 5 (回归)。
- §5 数据流与轮询 → Task 11 (ViewModel.startPolling / cancelPolling / 15 分钟超时)。
- §6 错误处理与空状态 → Task 14-16 (各 section 空状态) + Task 11 (错误恢复)。
- §7 测试 → Task 1-5 (后端) + Task 6-11 (前端单测) + Task 19 (回归) + Task 22 (验收)。
- §8 验收清单 → Task 22。
- §9 文档 → Task 20-21。

**Placeholder scan:** 无 TBD/TODO；每个 step 都有具体代码或命令。

**Type consistency:** `EquityPoint` / `TradeRow` / `FailureClusterSummary` 在 Task 6 定义，Task 7/8/10/11/15/16 使用，字段名一致。`BacktestRunV2.equityCurve` / `.trades` 跨任务一致。`BacktestLabViewModel.Phase` enum case (idle/configuring/running/completed/failed) 在 Task 11 定义、Task 14-17 使用一致。`riskWarnings(for:)` 在 Task 9 定义、Task 16 使用一致。`clusterFailures(in:)` 在 Task 10 定义、Task 15 使用一致。

**Known follow-ups baked into tasks:**
- Task 6 依赖 `AnyCodableDecoder` helper，若不存在需在同 task 内补。
- Task 11 依赖 `Strategy.uuid` / `currentVersionId` / `symbols` / `timeframe` 属性，若缺需在 Task 6 顺带补。
- Task 16 依赖 `PerStrategyReadinessResponse.grandStatus` / `.gates` 属性名，需对齐现有 `APIStrategiesV2.swift` 实际属性名。
- Task 17 依赖 `appState.selectedRoute = .liveReadiness`，需对齐 `AppRoute` 实际 case 名。
