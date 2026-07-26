# 页面数据规格 · Signal Center 信号中枢（PRD 7.4 + §4.5）

> 这是 PulseDesk 的**绝对中枢**。PRD：所有 AI/模型/研究/情绪/因子/操控雷达结果统一生成 Signal 汇入这里，再由此决定进入回测/dry-run/实盘。
> Signal 不是 UI 卡片，是模块间传递交易观点的基础对象。

## 页面单一职责
一眼看清：有哪些交易观点在场、各自多可信、处于什么生命周期、彼此有无冲突、哪些该发布到策略。

## 布局骨架（各风格自行用自己的母题演绎，但信息块要齐）
1. **顶栏**：页面名「Signal Center / 信号中枢」+ 全局统计(在场 Signal 总数 47 · active 23 · pending 12 · 冲突 3)
2. **筛选栏**：来源筛选、标的筛选、方向筛选、生命周期状态筛选、评分排序。做成可见的 chips/segmented（可点击视觉态，不要求真实过滤逻辑，但要有 hover/active 视觉）
3. **冲突检测横幅**（signature 数据）：3 组冲突，如「BTC/USDT：breakout_v3 看多(0.82) ⚔ sol_short_guard 看空(0.71) — 需人工裁决」
4. **Signal 列表**（主体，数据密集）：≥10 条，每条展示 PRD §4.5 必填字段：来源类型+来源名、标的+周期、方向、置信度(0-1)、评分(0-5 星或数字)、风险等级、有效期倒计时、生命周期状态、一句 reasoning 摘要。行尾放操作：发布到策略 / 加入 dry-run 观察 / 生成 StrategyDraft / 归档
5. **Signal 详情抽屉/面板**（点列表行展开，可用纯 CSS/JS toggle 一个即可）：展示完整 8 问——谁产生的、看什么标的、什么方向、多可信、为什么(reasoning+evidence 证据列表)、何时有效、能做什么(permission: 可回测✓/可模拟✓/可实盘✗)、生命周期事件时间线

## 真实数据（10 条 Signal，务必全用）
| # | 来源类型/名称 | 标的/周期 | 方向 | 置信度 | 评分 | 风险 | 有效期 | 状态 | reasoning 摘要 |
|---|---|---|---|---|---|---|---|---|---|
| 1 | technical / breakout_v3 | BTC/USDT 15m | long | 0.82 | 4.6 | medium | 5h 12m | active | 结构突破颈线，量能确认，HTF 守卫放行 |
| 2 | sentiment / FinBERT | ETH/USDT 1h | long | 0.67 | 3.8 | low | 11h | active | 新闻情绪转多，社媒热度上行 |
| 3 | tradingagents / 投研委员会 | SOL/USDT 4h | short | 0.71 | 4.1 | high | 3h 40m | active | 多 Agent 辩论后偏空，链上流出加速 |
| 4 | freqai / FreqAI-LGB | AVAX/USDT 1h | long | 0.58 | 3.2 | medium | 8h | pending | 模型预测短期反弹，待确认 |
| 5 | prediction / TimesFM | LINK/USDT 1d | hold | 0.44 | 2.4 | low | 20h | pending | 预测区间震荡，无明确方向 |
| 6 | manipulation / 操控雷达 | PEPE/USDT 5m | risk | 0.88 | 4.9 | extreme | 1h 20m | active | 检出 M3 拉盘出货特征，高集中度预警 |
| 7 | technical / range_bottom | DOGE/USDT 1h | long | 0.63 | 3.5 | medium | 6h | active | 近 3 月低点分批建仓区间 |
| 8 | tradingagents / 投研委员会 | BTC/USDT 1h | short | 0.71 | 4.0 | medium | 4h | active | 空头观点：与 #1 方向冲突，需裁决 |
| 9 | sentiment / FinBERT | SOL/USDT 15m | long | 0.55 | 3.0 | medium | 2h | active | 情绪偏多：与 #3 方向冲突 |
| 10 | factor / 因子研究 | ARB/USDT 4h | long | 0.49 | 2.8 | high | 9h | rejected | 因子失效，已被人工驳回 |

## 冲突组（3 组，冲突检测横幅用）
- **BTC/USDT**：#1 breakout_v3 看多(0.82) ⚔ #8 投研委员会 看空(0.71) — 需人工裁决
- **SOL/USDT**：#3 投研委员会 看空(0.71) ⚔ #9 FinBERT 看多(0.55) — 需人工裁决
- **PEPE/USDT**：#6 操控雷达 extreme 风险预警 — 建议 block 所有该标的多头信号

## 全局统计
在场 Signal 47 · active 23 · pending 12 · expired 9 · rejected 3 · **冲突 3 组待裁决**

## permission 默认安全（PRD 8.1）
AI/Agent/Prediction/FreqAI 来源的 Signal `can_live_trade=false`（详情里明确标注 可回测✓ 可模拟✓ 可实盘✗）；只有人工确认过的 technical 类可标 可实盘⚠需确认。

## 文案register
中枢是操作台，动词要准：「发布到策略」「加入 dry-run 观察」「生成 StrategyDraft」「裁决冲突」「归档」。别用"赋能/无缝"这类 filler。
