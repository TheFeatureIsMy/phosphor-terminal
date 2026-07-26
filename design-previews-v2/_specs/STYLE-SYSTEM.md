# AlphaLoop / PulseDesk · 六套 Web3 风格系统（v2 冻结版）

> 这是六套风格的**唯一真相**。任何页面的任何一套都必须严格照此落地：hex 不许改、字体不许换、signature 必须体现、禁止项一条不许犯。
> 六套已在 Dashboard 上验证过，现在要把**同一套风格语言**铺到其它页面，务必与既有 Dashboard 版视觉完全一致。

## 通用规则（六套都遵守）
- 单文件、自包含、可双击打开。Google Fonts 用 `<link>` 引入。
- 数字入场用 CountUp（纯 JS + requestAnimationFrame + easeOutCubic）。
- 必须 `@media (prefers-reduced-motion:reduce)` 全量降级（关动画/marquee/流动/呼吸）。
- 响应式 <768px 合理塌成单列。
- 键盘可聚焦控件必须有可见 focus 描边。
- 图标：不用彩色 emoji。用等宽/几何字符或规整 stroke SVG（各套注明）。
- 顶部放一个返回矩阵的链接：`<a href="index.html">← 返回矩阵</a>`（小字，符合各套风格）。
- 顶部放一个页面内的风格切换提示不需要——每格是独立文件。

---

## ① LEDGER · 链上账本（对标 Etherscan / 区块浏览器）
- **母题**：整页是一条竖向链上账本流，无卡片。左侧 ~90px 固定 gutter 显示区块高度(#4821 递减)+时间戳(等宽小字右对齐，竖直 hairline 分隔)。右侧逐行条目，行间 1px hairline 分隔。
- **配色（深色矿物墨）**：bg `#0D0F0E`；行底 `#111413`；hairline `#1E2422`；主文字 `#C8D0CC`；次要 `#6B7671`；等宽数字 `#E8EEEB`；**唯一强调=祖母绿 `#2FBF71`**（✓确认/盈利/hash链接/激活）；亏损 `#D9544D`(克制)；警示 amber `#C9A227`。**零渐变**。
- **字体**：全站 `'IBM Plex Mono',ui-monospace,monospace`（引入 400/500/600）。标题用 500/600 拉大字号。绝不用 Inter/衬线。
- **signature**：条目渲染成"已签名区块"——截断哈希 `0x8f..2a` + 验证勾 ✓ + 细「确认进度」条(██████░░░)。
- **禁止**：卡片/glass、backdrop-filter、mesh/极光、渐变文字、圆角>4px、紫蓝配色、emoji。
- **图标**：等宽/几何符号 ✓ ▸ ⬢ ░ █ ── │。

## ② DEPTH · 深度驾驶舱（对标 Bloomberg / dYdX）
- **母题**：高信息密度多窗格 cockpit。顶部 24px 高 tape 走马灯(横向无限滚动报价，hover暂停)。下方紧密 CSS Grid 多窗格，窗格间 1px 硬分隔或极小 gap(4-6px)。极小 label、紧行高。
- **配色（CRT 磷光琥珀 on 近黑）**：bg `#080807`；窗格底 `#0E0D0B`；分隔 `#211F1A`；主文字 `#D6CBB0`(暖灰)；次要 `#7A7159`；**主强调=钠光琥珀 `#F5A623`**(现役数据/标题/买盘/激活)；涨/买=磷光绿 `#3FB950`；跌/卖=`#E5484D`。暖调 CRT，禁霓虹青、禁蓝紫。
- **字体**：全等宽 `'JetBrains Mono',ui-monospace,monospace`（400/500/700）。字号 10-12px 紧行高。label uppercase+letter-spacing。
- **signature**：若页面有行情/深度场景就放订单簿深度阶梯；否则用「密集数据窗格 + tape 走马灯 + 琥珀高亮现役行」体现终端密度。
- **禁止**：圆角>2px、glass、mesh、渐变文字、紫蓝、emoji、大留白。要"密"。
- **图标**：▲▼ ● ░ █ │ ═。

## ③ PROTOCOL · 机构 DeFi（对标 Uniswap / Base / Phantom）— 唯一浅色
- **母题**：浅色大留白、大圆角(16-20px统一)、有节奏 bento(非三等分)。极轻边框+柔和 tint 阴影(阴影染品牌色，非纯黑)。
- **配色（浅色钴蓝双色）**：bg `#F6F7FB`(冷白)；卡底 `#FFFFFF`；边框 `#E6E9F2`；主文字 `#0F1524`；次要 `#5A6480`；**主品牌=钴蓝 `#3D5AFE`**(唯一主色)；辅助=暖珊瑚 `#FF7A59`(极少量强调)；涨 `#12B76A` 跌 `#F04438`；warning `#F59E0B`。柔和专业非饱和。次要文字对比达 WCAG AA。
- **字体**：display `'Space Grotesk'`(600/700)；body `'Inter'`(此档 Inter 可用)；数字 tabular。
- **signature**：干净可信的主卡（大 tabular 数字 + 内嵌平滑品牌色面积曲线 + pill 状态），像 Uniswap 资产卡。
- **禁止**：暗黑bg、霓虹、扫描线、mesh滥用、渐变文字标题、紫蓝AI配色、等宽当正文、密集cockpit、emoji、三等分玻璃卡。
- **图标**：规整 1.5 stroke 几何 SVG（Phosphor/Tabler 风格）。

## ④ SPATIAL · 策略星图（对标节点图谱 / DAG）
- **母题**：空间画布拓扑图。深色 bg 带极淡点阵坐标。实体(策略/信号/Agent/风控)是节点，节点间 SVG path 连线，**连线上有沿路径流动的脉冲光点**(SMIL animateMotion 或 CSS offset-path)。关键指标做半透明悬浮 HUD 叠在画布上。侧边可滚动悬浮 log 面板，底部悬浮 dock。
- **配色（星图冷光，非蓝紫）**：bg `#070B0C`(近黑冷绿)；网格点 `rgba(120,180,170,0.06)`；节点底 `#0F1614`；节点边 `#22403A`；主文字 `#CFE0DA`；次要 `#6C8079`；**主强调=青柠信号 `#5CE6A8`**(活跃节点/资金流脉冲/高亮)；次强调=冷蓝 `#3FA9E0`(信号类连线，与青柠区分数据流类型)；涨 `#5CE6A8` 跌 `#F0645B`；warning `#E8B84B`。
- **字体**：节点标题/display `'Space Grotesk'` 600；数据/坐标/标注 `'IBM Plex Mono'` 400/500。标注小而精确，像工程示意图。
- **signature**：资金/信号脉冲沿连线流动 + 活跃节点呼吸光晕 + 半透明悬浮 HUD。这是灵魂。
- **HUD 允许 backdrop-filter**（这是该套 signature 的一部分，合理）。
- **禁止**：传统卡片网格、mesh、玻璃滥用(仅HUD可)、渐变文字、紫蓝AI配色、emoji。
- **图标**：几何节点符号(圆/六边形/菱形) SVG。

## ⑤ BRUTALIST · 生猛 Degen（对标 Blur / Blast / pump.fun）
- **母题**：新粗野主义。粗边框(2-3px solid)硬块布局，可故意错位不对齐。offset 硬阴影 `box-shadow:6px 6px 0 #000`(实心不模糊)。全站 `border-radius:0`。横向大字 marquee(hover暂停)。字号对比极端(巨大 vs 极小)。
- **配色（黑+电光黄）**：bg `#0A0A0A`(或局部纯`#000`)；块底 `#141414`；**主强调=电光黄 `#E5FF00`**(大面积用于大数字/marquee/主按钮底)；文字白 `#FFFFFF`/黑 `#000`(黄底用黑字)；涨 `#00E676`(生猛绿) 跌 `#FF3B3B`(生猛红)；边框用 `#FFF`/`#E5FF00`/`#000`；极少量品红 `#FF2E9A` 点缀。高对比不柔和。正文可读性保证(禁黄底黄字)。
- **字体**：display 超粗压缩黑体 `'Anton'` 或 `'Archivo'`(800/900)，可 uppercase/skew/italic；body/数据 `'Space Mono'`(等宽)。
- **signature**：超大压缩黑体数字 + marquee 大字条 + offset 硬阴影块。hover：块体 translate(3px,3px) 让硬阴影"贴合"。
- **禁止**：柔和阴影、glass、圆角、mesh、渐变文字、紫蓝AI配色、精致微交互、温柔对称居中。
- **图标**：粗几何符号 ▲▼ ■ ► ✕ 或粗 stroke SVG。

## ⑥ RWA · 机构级衬线（对标 Ondo / Ethena / Superstate）
- **母题**：庄重报告式网格。克制 header(衬线品牌名+细分隔)。大号衬线数字配精确小标签(像财报封面/factsheet：label上、大数字下、单位小字)。金融表格(细 hairline、右对齐数字、充足留白)。像印刷精美的机构月报搬上屏。
- **配色（深墨绿+米金）**：bg `#0B1310`(深墨绿近黑)；面板 `#101B16`；hairline `#22322B`；主文字 `#E8E4D6`(暖米白)；次要 `#8A9188`；**主强调=米金 `#C9A86A`**(关键数字/品牌/强调线)；深绿点缀 `#2E7D5B`；涨 `#3E9B6E`(沉稳绿) 跌 `#B54A45`(沉稳砖红)；warning `#C9922A`。低饱和有厚度。对比达 WCAG AA。
- **字体**：衬线 display `'Cormorant Garamond'`(600，heritage 感，禁 Fraunces/Instrument Serif)，只用于标题/大数字；body `'Inter'`(400/500 清晰)；数据 tabular 或 `'IBM Plex Mono'` 精密对齐。
- **signature**：大号衬线数字配精确时间戳小字("截至 2026-07-14") + factsheet 式精密数据网格。气质=可打印给机构 LP 的月报。
- **入场**：hairline draw-in(scaleX 0→1)+内容淡入，克制优雅非弹跳。
- **禁止**：霓虹、扫描线、glass、mesh、渐变文字、紫蓝AI配色、emoji、赛博感、花哨动效。
- **图标**：极少用；若用简单细 stroke 几何 SVG。
