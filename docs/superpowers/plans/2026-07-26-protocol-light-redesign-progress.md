# Progress: macOS Protocol 浅色风格全站重构

> 日期: 2026-07-26 · 提交: `466c56c` · 状态: 全部完成,待用户目视验收
> 关联设计: `design-previews-v2/03-protocol.html` + `_specs/STYLE-SYSTEM.md` §③ PROTOCOL
> 前置计划: `2026-07-25-protocol-light-redesign.md`

## 本次会话完成的工作

### 1. 环境 / 基础设施(非视觉)
- **Docker 镜像源修复**: 失效的 daocloud/ustc/163 → `docker.1panel.live`(改 `~/.colima/default/colima.yaml`)。freqtrade 镜像成功拉取。
- **VPN 代理注入容器**: 新建 `docker-compose.override.yml`(已 gitignore),给 api + freqtrade 注入 `HTTP(S)_PROXY=http://host.docker.internal:7892`,NO_PROXY 排除容器间通信。需用户开全局 VPN(代理端口 7892)。
- **`ccxt_ticker_stream.py`**: ccxt 的 aiohttp 不读代理环境变量,加 `_proxy_from_env()` 显式传给 ccxt `httpsProxy`。此后端改动已随全提交入库。
- 全栈跑通: postgres + redis + api(:8000) + freqtrade(:8080, binance dry-run running),macos app live 模式。

### 2. 移除登录(Phase 0)
- `AlphaLoopApp.swift` ContentView 去掉 `isAuthenticated` 分支,后端就绪直接进 AppShellView。
- `AuthState` 默认 `isAuthenticated = true` + 注入 mockUser,保留 login/logout/register 方法防连锁编译错误。
- `KeychainService` 改进程内内存存储(NSLock 包裹),根除未签名 SPM 可执行文件每次 HTTP 请求读钥匙串都弹授权框的问题。

### 3. Protocol 浅色风格重构(Phase 1-4)
**Phase 1 地基** — 打包 Space Grotesk + Inter 字体(`Resources/Fonts/`,OFL,AppDelegate 运行时注册);`DesignTokens.swift` 全站换 protocol 精确 hex;ThemeManager 锁浅色(isDark 恒 false);清除全站 glassEffect/扫描线/mesh/材质叠层/暗色 hex。

**Phase 2 总览页** — `DashboardView` + 新建 `DashboardProtocolCards.swift`,按稿 1:1 bento(equity 大卡 CountUp / 权益曲线描线动画 / 三卡 / 持仓 / 双 feed),绑定 DashboardViewModel 真实数据,1240 居中。

**Phase 3 有稿三页** — 布局 1:1、数据求真(无数据块用空态,不造假):
- Signal 信号中枢(signal-03): hero 统计带 + 过滤 chips + 冲突裁决区(symbol 多空对立真实派生) + 信号表可展开行
- Risk 风控中心(risk-03): water 水位环卡 + 守卫网格(真实 guards) + 拦截事件流(activeLocks) + 门禁规则(只读);FSM 状态机后端无数据→省略
- Research 投研室(research-03): hero 深度控制 + 标的卡 + 多 Agent 观点网格(置信度标注"估算") + verdict 裁定卡;辩论时间线后端无数据→省略

**Phase 4 全站适配** — `KryptonCard` 去 3D/聚光灯改白卡(41 文件继承);`TerminalLabel`/`QuantPageHeader` 去暗色等宽终端风(58 处继承);暗色 mask/白字/玻璃/材质残留清零;Landing 落地页浅色重写;23 页分 5 组(A 核心/B 执行/C 结构/D AI成长/E 系统)逐组审查。

### 4. 紧急停止收敛
- 移除 6 页面顶部 EmergencyStopBar(执行×3 风控×3)+ Dashboard 底栏 EmergencyActionBar。
- **只保留全局顶栏(GlobalStatusBar)单入口**,每页可见。各页 ViewModel 的 emergencyStop 方法保留,由顶栏统一调用。

### 5. 动效 / 交互 / 无障碍(V1)
- `PulseAnimation` 新增 protocol 缓动: `protocolEase`(0.2,0.7,0.3,1)/`drawIn`/`hoverLift`;staggerDelay 0.035→0.05。
- 曲线描线 / 进度条 / 卡片 hover 时长统一到预设。
- `staggeredAppearance` + `shimmer` 骨架屏加 `accessibilityReduceMotion` 降级(reduced-motion 静止),此前全站完全缺失。
- 8 页容器宽度统一 `PulseSpacing.contentMaxWidth = 1240`。

## 关键设计决策
- **布局 1:1,数据求真**: 设计稿的虚构结构(辩论时间线/FSM 状态机/拦截流/裁决组)若后端无对应数据,用空态/真实近似映射,**绝不造假数据**(遵守 CLAUDE.md 禁生产路径假数据)。
- **杠杆优先**: 多数页面布局结构本就合理,通过共享组件(KryptonCard/QuantPageHeader/TerminalLabel/DesignTokens)一次性 protocol 化,而非逐页重写 28,000 行。
- **绿涨红跌保留、无紫色**(用户 memory 约束);紫色 token 已映射到钴蓝。

## 待办 / 后续
- [ ] 用户目视验收各页(尤其 Dashboard/Signal/Risk/Research 四个 1:1 页)
- [ ] 无稿 ~30 页目前只换肤未重排布局,如需按 protocol 重排需逐页确认
- [ ] 后端字体依赖 VPN 代理(7892),VPN 断开则 binance 行情/freqtrade 失联
- [ ] TradingDashboardView.swift 为未接线遗留页(仅 preview 引用),可考虑删除

## 验证
- `swift build` 0 error;app 稳定运行 live 模式;后端 /health ok;全站 glassEffect/材质/暗色 hex/白字残留 = 0
