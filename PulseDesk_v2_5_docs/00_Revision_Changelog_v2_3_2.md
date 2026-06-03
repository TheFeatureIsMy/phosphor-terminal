# 00. Revision Changelog v2.3.2

## Summary

v2.3.2 是深度代码实现前的工程加固版本，主要解决 3 个隐藏但严重的实现风险：

1. Freqtrade UniversalStrategy 动态读取 StrategyRuleDSL 的同步 I/O 阻塞风险；
2. Signal 分区归档后 `trade_intents.source_signal_ids` 变成死链的证据链断裂风险；
3. PulseDesk / Freqtrade 失连恢复时 `reconciliating` 状态机未定义原子对账导致仓位冲突的风险。

## New document

- `09_Code_Implementation_Hardening_v2_3_2.md`

## Updated phase files

- `Phase_01_Signal_Center.md`
- `Phase_02_Freqtrade_Adapter.md`
- `Phase_06_Growth_Engine.md`
- `Phase_07_Live_Small_Safety.md`

## New hard requirements

### UniversalStrategy rule loading

- `PulseDeskUniversalStrategy.py` must not read JSON rule files inside every candle calculation.
- Must use cached DSL rules plus mtime/hash/version based reload.
- Rule update must use atomic file replacement.
- Invalid rule update must keep last known good rules.

### Data Federation Layer

- All Signal lookup must go through `SignalRepository`.
- Hot PostgreSQL, SQLite archive, Parquet archive must be queried behind one unified interface.
- Referenced signals must be snapshotted before archive or deletion.

### Reconciliation state machine

- `reconciliating` must block all outbound TradeIntent.
- Freqtrade current state is the truth source.
- PulseDesk local DB must be corrected from Freqtrade / exchange state.
- Unresolved mismatch must enter `manual_review_required`, never auto-healthy.
