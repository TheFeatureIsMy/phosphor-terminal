# Plan: 移除登录 + AlphaLoop 全站 Protocol 浅色风格 1:1 重构

日期:2026-07-25 · 目标:去掉登录页;把 macOS app(141 视图 / ~27,900 行)从暗色 OKX/赛博朋克风,按 `design-previews-v2/03-protocol.html` + `_specs/STYLE-SYSTEM.md` §③ PROTOCOL 严格重做为浅色机构 DeFi 风。用户已确认"一次做到底"。

## Protocol 风格锁定值(来自 STYLE-SYSTEM.md,hex 不可改)
- 色:bg `#F6F7FB` / 卡 `#FFFFFF` / 边框 `#E6E9F2` / 主文字 `#0F1524` / 次要 `#5A6480` / 主品牌钴蓝 `#3D5AFE` / 辅助珊瑚 `#FF7A59`(极少量) / 涨 `#12B76A` 跌 `#F04438` / warning `#F59E0B`
- accent-soft `#EAEEFF` / up-soft `#E6F7EF` / down-soft `#FDECEA` / warn-soft `#FEF4E2`
- 字体:display=Space Grotesk(600/700);body=Inter(400-700);数字 tabular
- 圆角:统一 16-20px(卡 18 / lg 20 / sm 12);阴影:染品牌色柔和 tint(非纯黑)`0 8px 24px rgba(61,90,254,.06)`,hover 上浮
- 禁止:暗黑 bg、霓虹、扫描线、mesh、渐变文字标题、紫蓝 AI 配色、等宽当正文、玻璃滥用、emoji、三等分玻璃卡
- 图标:1.5 stroke 几何 SVG(Phosphor/Tabler 风)→ SwiftUI 用 SF Symbols 细线变体近似

## Phase 0 — 移除登录
- `AlphaLoopApp.swift` `ContentView`:删掉 `authState.isAuthenticated` / `LoginPlaceholderView` 分支,后端就绪后直接 `AppShellView`
- `AuthState`:`init` 或启动时默认置 `isAuthenticated = true`、注入 `mockUser`,保留 `login/logout/register` 方法避免连锁编译错误
- 保留 `LoginPlaceholderView` 代码(不再路由),降低回退成本

## Phase 1 — 设计地基(全站换肤杠杆)
1. 打包字体:Space Grotesk(600/700)+ Inter(400/500/600/700)OFL ttf → `Resources/Fonts/`;`Package.swift` 加 `.copy("Resources/Fonts")`;启动注册(CTFontManagerRegisterFontsForURL 或 Bundle 注册)
2. 重写 `DesignTokens.swift`:PulseColors 全部换成 protocol 浅色 hex(上方锁定值);PulseFonts 换 Space Grotesk/Inter;PulseRadii 卡=18/lg=20/sm=12;PulseShadow 改品牌色 tint 柔和阴影
3. `ThemeManager`:锁定浅色,移除/短路 dark 分支;`AlphaLoopApp` `preferredColorScheme(.light)`
4. 核心组件:`ViewModifiers.swift` / `CardModifier` / `DepthCard` / `SpotlightCard` / `KryptonButton` / `KryptonCard` / `AtmosphericBackgroundModifier` 从玻璃拟态改为白卡 + 柔和阴影 + hover translateY(-3px);去掉 mesh/scanline/noise 四层背景,换成 `#F6F7FB` 纯冷白底

## Phase 2 — 总览页 1:1(对照 03-protocol.html)
重建 `DashboardView` 及子组件:顶部 nav(brand mark + 链接 + API 状态点 + 连接账户按钮)→ hero(eyebrow + 大标题 + action row 启动/回测/同步/紧急停止)→ bento row1(equity 大卡:徽章 + 46px tabular 总权益 + PnL pill + 4 子指标 | 权益曲线卡:tabs + SVG 渐变面积曲线 + CountUp)→ row2(运行时/实盘就绪度进度条/全局风险 三卡)→ 持仓表(彩色币种图标 + LONG/SHORT pill + 浮盈)+ 净敞口卡 → 双 feed(AI 决策流 / 风险告警)→ sticky 底部紧急停止 bar。复刻 CountUp、曲线描线动画、reveal 交错入场。

## Phase 3 — 有稿页面 1:1
按 `research-03-protocol.html` / `risk-03-protocol.html` / `signal-03-protocol.html` 重建:AI 研究页、风控中心、信号中心。

## Phase 4 — 其余无稿页面(~30 页)按 protocol 语言适配
靠 Phase 1 token 自动继承浅色基底,逐页把布局改成 protocol 语言(bento 非等分 / 白卡 / Space Grotesk 标题 / tabular 数字 / 柔和阴影 / pill 状态)。覆盖:策略工作台、回测实验室、执行中心、结构矩阵、操纵雷达、成长、系统、设置、通知、Agent 平台等。分批推进。

## 验证
- 每 Phase 后 `cd macos-app && swift build` 必须通过
- 全程保持后端 live(Docker 栈 + VPN 代理已就绪)
- L10n:所有新文案走 `L10n.<Domain>`,不硬编码
- 绿涨红跌语义保留;无紫色(符合用户 memory 约束)

## 风险
- 字体注册在 SPM executable 里需验证(可能需 Info.plist ATSApplicationFontsPath 或运行时注册)
- 141 视图中部分直接硬编码了暗色 hex / `.glassEffect()`,需全局 grep 清理
- 工作量极大,Phase 4 会跨多轮;token 层做对后大部分页面能自动浅色化,再逐页精修
