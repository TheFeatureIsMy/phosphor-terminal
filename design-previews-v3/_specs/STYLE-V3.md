# AlphaLoop · V3 设计系统规格（三方案冻结版）

> 目标：全面重新设计 AlphaLoop 的 UI/UX——布局、动效、转场、字体，不是换色。
> 产品定位（PRD 最终结论）：**AI 结构化自动交易运行控制台**。不是 AI 功能集合，不是行情软件。
> 三条新设计语言与 v2 六套（ledger/depth/protocol/spatial/brutalist/rwa）**不重复**，各自有独立母题与动效语法。
> 每套已验证 4 种核心页型：总览（监控态）/ 实盘准入（门禁态）/ 风控中心（警示态）/ 策略工作台（密集工作态）。
> 共享同一套真实数据（见各页）；zh-CN 优先；单文件自包含可双击打开。

## 通用规则（三套都遵守）
- 数字入场 CountUp（requestAnimationFrame + easeOutCubic）。
- `@media (prefers-reduced-motion: reduce)` 全量降级。
- 键盘可聚焦控件有可见 focus 描边。
- 不用彩色 emoji；图标用几何 stroke SVG 或字符符号。
- 每页顶部小字返回链接 `<a href="index.html">← 返回矩阵</a>`。
- 响应式 <900px 合理塌缩。

---

## A · SENTINEL 哨兵 — 任务指挥台（深色，状态机优先）

**母题**：整页是一张「作战指挥台」。状态机/门禁是主角，不是数据卡片。
- **布局**：左 72px 固定图标 rail（每图标下嵌 3px 状态 LED 点）+ 顶 36px 状态 ribbon（系统/风控/FastTrack/Freqtrade/Redis/交易所 一排 LED 芯片）+ 内容 12 列 grid。模块方角 2px、1px hairline 边框，无阴影、无玻璃。
- **配色（石墨 + 信号青）**：bg `#0B0E13`；模块底 `#10141B`；hairline `#1C222B`；主文字 `#E6EAF2`；次要 `#8B94A7`；**唯一主强调=信号青 `#2DD4BF`**（健康/就绪/现役）；警示 `#F0B35E`；危险 `#F45D5D`；涨 `#34D399` 跌 `#F45D5D`。零渐变、零模糊。
- **字体**：UI `'Inter Tight'`（500/600/700，紧字距）；数据/读数/标签 `'JetBrains Mono'`（数字主字体）。标签 mono uppercase + letter-spacing .12em。
- **动效语法**：①模块错峰入场（translateY 6px + fade，60ms 阶梯）；②LED 状态点 2.4s 呼吸脉冲；③门禁链节点逐级点亮（每个 220ms，连线 draw-in）；④读数 CountUp；⑤页面切换 = 模块层整屏 fade+6px 上移，200ms。hover 仅 hairline 提亮，不上浮。
- **signature**：**门禁链 GateChain**——LIVE_SMALL_READY 渲染为 5 级闸门链路（节点+连线逐级点亮）；状态一律用 LED 圆点+mono 大写词。

## B · MERIDIAN 经线 — 精密仪器台（浅色，度量优先）

**母题**：把交易数据当「度量」呈现——刻度、公差带、读数、标注。不是 bento，是仪器面板。
- **布局**：内容最大宽 1320；方角 3px；1px hairline 细线分隔；读数卡 = 顶部 mono 小标 + 大号 mono 数字 + 底部微型刻度尺（tick）；关键卡带「公差带」可视化（±阈值区间）。
- **配色（暖纸 + 墨钢 + 铜）**：bg `#F4F3EF`（暖纸）；卡底 `#FBFAF7`；hairline `#E3E0D8`；主文字 `#14161A`（近黑墨）；次要 `#6B6E78`；**主强调=钢青 `#2450A8`**（链接/激活/关键读数）；**铜 `#B4530F`** 极少量用于警示标记与刻度主标；涨 `#0E7A4D` 跌 `#C0392B`。无阴影（或极浅 1px 纸影）。
- **字体**：标题/大数字 `'Inter Tight'` 600 tight tracking（可叠 mono）；全部数据 `'IBM Plex Mono'`；标签 mono 小号 + letter-spacing .14em uppercase。
- **动效语法**：①刻度尺 draw-in（scaleX 0→1 自左）；②表针 sweep（旋转 0→目标，800ms cubic-bezier(.2,.7,.2,1)）；③读数 CountUp；④区块入场 = 顶部 hairline 先画线、内容再淡入（200ms 后接）；⑤页面切换 = 旧内容向左 12px 淡出、新内容自右淡入，克制无弹跳。
- **signature**：**公差带读数卡** + 弧线量表（gauge 带真实 tick 刻度，表针指当前值）。一切读数都带单位与阈值刻度。

## C · GLASS OPS 深玻 — 原生深度控制台（暗色，深度优先）

**母题**：macOS 26 Liquid Glass 的 Web 演绎。半透明玻璃模块悬浮在缓慢流动的「市场氛围层」之上；氛围色随系统状态变化。
- **布局**：内容悬浮于氛围层上；玻璃模块大圆角 20px、`backdrop-filter: blur(24px) saturate(1.6)`、1px 微光描边（内发光）；间距松。氛围层 = 3 个大半径 radial 光斑（青/靛/品红极淡），60s 超慢速漂移；风险状态切换时氛围色偏转（normal→青靛，warning→琥珀，risk→红）。
- **配色（近黑 + 流光青）**：bg `#06080D`；玻璃 `rgba(255,255,255,.055)`；描边 `rgba(255,255,255,.12)`；主文字 `#F2F5FA`；次要 `#9AA4B8`；**主强调=流光青 `#67E8F9`**；辅助=极淡紫 `#A5B4FC`；涨 `#34D399` 跌 `#FB7185`；警示 `#FBBF24`。
- **字体**：`'SF Pro Display'` 体系（system-ui 栈）+ 数据 `'SF Mono'/ui-monospace`。大数字用 700、负字距、极淡 text-shadow 发光。
- **动效语法**：①氛围层 60s 无限漂移（transform translate，无关键帧跳变）；②模块入场 cross-dissolve（opacity+blur(8px→0)）；③hover = 描边扫光（conic-gradient 边框高亮旋转 300ms）+ 内层提亮，无位移；④读数 CountUp + 发光渐入；⑤页面切换 = 帧不动、内容 cross-dissolve 互换（像原生 app）。
- **signature**：**氛围状态联动**——风险等级改变氛围层色相；数字极淡发光描边；玻璃 HUD 信息条。
