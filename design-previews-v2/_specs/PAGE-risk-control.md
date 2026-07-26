# 页面数据规格 · 风控中心（PRD 7.9 + v2.2§5 双层风控）

> 目标：所有 TradeIntent 的**强制门禁**。PRD 非目标里反复强调：AI/Agent 不得绕过 RiskEngine 下单，禁止关闭风控。
> 这是"警示状态型"页面——状态机、拦截事件、紧急停止。

## 页面单一职责
一眼看清：当前整体风险水位、各风险维度是否触警、Freqtrade 连接与降级状态、最近拦截了什么、以及紧急停止入口。

## 布局骨架（各风格用自己母题演绎；这页强调"状态/门禁/警示")
1. **顶栏**：页面名「风控中心 / Risk Control」+ 全局风险水位徽标(当前 **CAUTION 警戒** · 水位 62%) + 紧急停止入口(常驻)
2. **全局风险水位 hero**：大号水位指标(风险敞口 62% / 回撤 -4.82% / 保证金率 18.4%)，配一个水位可视化(仪表/进度/阶梯，各风格自选)
3. **Freqtrade 连接状态机**（signature 数据 · PRD v2.2§5）：展示 6 态状态机，当前处于某一态，高亮：
   `healthy → connection_lost → pulse_degraded → freqtrade_native_guard_only → reconciliating → failed`
   当前态 = **pulse_degraded**（PulseDesk 降级，Freqtrade 原生守卫仍在）。说明该态限制：禁止策略升级、禁止提高仓位、禁止启动新 live_small。
4. **风险维度网格**（PRD 7.9 九个维度）：全局风险✓、组合风险✓、相关性风险⚠、AI/Agent 风险✓、Signal 冲突⚠(3组)、操控风险⚠(PEPE extreme)、Freqtrade/API 风险⚠(降级)、模拟盘异常✓、每个维度一个状态格(正常/警戒/触发 三态视觉)
5. **风控拦截事件流**（signature · 数据密集）：≥6 条被拦截的 TradeIntent，每条展示 risk_codes + reasoning(PRD 中期指标要求)。
6. **门禁规则**：几条生效中的强制规则(单笔最大仓位/最大回撤熔断/相关性上限/操控评分阈值)，含开关视觉态(只读展示)
7. **紧急停止总控**（底部常驻）：一键撤单·平仓·冻结新开仓，需二次确认视觉(各风格自选确认样式)

## 真实数据 · 风控拦截事件（6 条，务必全用）
| 时间 | 被拦交易意图 | 来源 | risk_codes | reasoning |
|---|---|---|---|---|
| 2m | SOL/USDT 加空 180→260 | sol_short(#3) | POSITION_LIMIT, CORRELATION_HIGH | 单标的敞口超限 + 与 ETH 空头相关性 0.82 |
| 8m | PEPE/USDT 开多 | 某 Agent | MANIPULATION_EXTREME | 操控雷达 M3 拉盘出货预警，评分 0.88，禁止入场 |
| 14m | BTC/USDT 升级 live_small | breakout_v3 | FREQTRADE_DEGRADED | 连接降级态禁止升级 live_small |
| 22m | ARB/USDT 开多 | 因子研究(#10) | SIGNAL_REJECTED | 来源 Signal 已被人工驳回 |
| 35m | ETH/USDT 提高仓位 12→20 | grid_eth | DRAWDOWN_GUARD | 组合回撤 -4.82% 接近 -5% 熔断线 |
| 51m | DOGE/USDT 无止损开多 | range_bottom(#7) | MISSING_STOPLOSS | 强制止损缺失，拒绝执行 |

## 风险维度状态（9 维）
- 全局风险：正常(62% 水位，警戒但未触发)
- 组合风险：正常
- 相关性风险：⚠警戒(ETH/SOL 空头相关性 0.82)
- AI/Agent 风险：正常(权限门禁生效)
- Signal 冲突：⚠警戒(3 组待裁决)
- 操控风险：⚠触发(PEPE extreme)
- Freqtrade/API 风险：⚠警戒(pulse_degraded)
- 模拟盘异常：正常
- 紧急停止：就绪(未触发)

## 门禁规则（生效中，只读展示）
- 单笔最大仓位 ≤ 10% 总权益 · 生效
- 最大回撤熔断线 -5% · 生效(当前 -4.82% 接近)
- 单标的相关性上限 0.85 · 生效
- 操控评分阈值 ≥0.8 自动 block · 生效
- 缺失止损拒绝执行 · 生效

## Freqtrade 状态机文案（PRD v2.2§5 精确）
healthy / connection_lost / pulse_degraded / freqtrade_native_guard_only / reconciliating / failed
当前：**pulse_degraded** — "PulseDesk 已降级，Freqtrade 原生止损与仓位限制仍在生效。禁止策略升级、提高仓位、启动新 live_small。请人工检查连接。"

## 文案 register（错误/警示态是重点）
风控文案要直接说明"拦了什么、为什么、怎么办"，不道歉、不含糊。例：「已拒绝：单标的敞口超限。当前 SOL 敞口已达上限，解除请先减仓或调整门禁规则。」紧急停止按钮文案清晰："紧急停止全部"→确认→"已停止"。
