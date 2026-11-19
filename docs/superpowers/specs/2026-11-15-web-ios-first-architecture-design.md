# Web + iOS 优先架构设计

> 状态：Proposed · 日期：2026-11-15
> Supersedes：`2026-11-15-multi-client-saas-architecture-design.md` 的**客户端技术路线与阶段顺序**（Flutter 四端 → Web + iOS 先行）
> 保留：多租户、远程服务端、执行隔离、画布 WebView 的结论
> 关联：[组件化与结构分析](../architecture/18_componentization_web_ios_server.md)

## 0. 决策变化

用户优先级调整为：**网站（`web/`）与 iOS App 先行**；Android/Windows 后置；服务端必须可部署、能力正常、全链路可验证。

因此：

| 项 | 旧方案 | 新方案 |
|---|---|---|
| Web | 与 Flutter 并列，优先级低 | **第一优先级**，浏览器 + 后续 Tauri 壳 |
| iOS | Flutter | **SwiftUI，复用 `macos-app/` 的模型/服务/ViewModel/设计系统** |
| Android/Windows | Flutter 四端 | 后置，技术选型待定（Compose / Flutter / Tauri） |
| 画布 | Flutter WebView | **Web 端就地保留；iOS 用 WKWebView 加载同一份构建产物** |
| 服务端 | SaaS 多租户 | 不变；但先保证部署与全链路，再做租户化 |

选择 SwiftUI 而非 Flutter 的理由：仓库已有 45k 行 Swift（Models/Services/ViewModels/DesignSystem/L10n），iOS 可复用其中大部分；Flutter 会把这两套现成客户端都作废。代价是 iOS 需要把 macOS 的单一 executable target 拆成共享 Core + 平台壳。

## 1. 目标形态

```text
浏览器 (web/) ─┐
iOS (SwiftUI) ─┼── HTTPS/WSS ──> API Server (FastAPI)
Windows (后续) ─┤                     │
macOS (冻结)  ─┘                     ├─ PostgreSQL (later RLS)
                                     ├─ Redis
                                     └─ Freqtrade (later per-tenant)
```

- 服务端是唯一真相源；客户端不直连数据库/Freqtrade；
- 先单租户可用，再迁移多租户（`tenant_id` + RLS）；
- 多租户执行隔离完成前，非平台 owner 只允许 paper/dry-run。

## 2. Web（第一优先级）

### 2.1 目标

- 浏览器可直接访问，`API_BASE` 运行时可配（同源 / 预发 / 生产）；
- 登录、租户切换（后续）、总览、策略、回测、执行、风控、设置；
- 画布编辑器保留在 Web，作为策略编辑主入口。

### 2.2 结构

按 [组件化文档 §2.2](../architecture/18_componentization_web_ios_server.md) 迁移到 `features/`；先迁 auth / dashboard / backtest 三条链路，页面行为保持不变。

### 2.3 远程服务端适配

- `VITE_API_BASE` 与运行时 `window.__ALPHALOOP_CONFIG__` 二级覆盖；
- 生产同源部署（Caddy 反代 `/api`、`/auth`、`/ws`），避免 CORS 与混合内容；
- token 存 `localStorage`（Web）／Keychain（iOS），401 自动刷新；
- WebSocket 用短时 ticket，不把 access token 放 query。

### 2.4 验收

- 生产构建（`npm run build`）通过；
- 登录 → 总览 → 策略 → 回测 → 结果 → 风控，全链路在浏览器完成；
- 刷新页面保持会话；token 过期回登录；
- 无 `localhost` 硬编码（除开发默认）。

## 3. iOS（第二优先级）

### 3.1 复用策略

从 `macos-app/AlphaLoop/` 抽出 SwiftPM library：

```text
AlphaLoopCore  (Models / Services / ViewModels / DesignSystem / L10n / Realtime)
AlphaLoopiOS   (App / Views / Resources)
AlphaLoopMac   (冻结壳，后续可删)
```

- Core 禁止 `import AppKit`，平台差异用 `#if os(...)`；
- iOS 首版复用 Dashboard / Strategy / Backtest / Risk 的 ViewModel 与 API；
- 导航改为 Tab + NavigationStack；表格改 List；
- 画布用 `WKWebView` 加载 Web 构建的同一份 bundle，只读。

### 3.2 验收

- Core 在 iOS 模拟器编译通过（CI `xcodebuild -destination 'generic/platform=iOS'`）；
- 登录 → 总览 → 策略列表 → 回测提交 → 结果，全链路可用；
- token 存 Keychain，401 自动 refresh；
- 推送点击可深链到对应 run/alert（首版可延后）。

## 4. 服务端（并行最高优先级）

### 4.1 部署

- `SERVER_HOST/SERVER_PORT` 可配置；Docker 置 `0.0.0.0`；
- `TrustedHostMiddleware` + `ALLOWED_HOSTS`；
- 反向代理 Caddy/Nginx + TLS；
- `scripts/gen-secrets.sh` 生成 `SECRET_KEY` / `PULSEDESK_ENCRYPTION_KEY`，部署脚本自动调用；
- `/readiness` 检查 DB/Redis，报告 Freqtrade；作为容器/LB 探针。

### 4.2 全链路

- HTTP 级 E2E：注册/登录 → 鉴权 → 策略 → 版本 → 回测命令 → worker → ledger → 结果 → 风控封锁；
- Freqtrade 在测试中 mock 在 runner 边界，其余全部真实；
- CI 跑全量 pytest（覆盖率 ≥65%）；
- 真实环境 smoke：`/health`、`/readiness`、登录、总览。

### 4.3 多租户（P1，服务端）

- `tenants` / `memberships` / `device_sessions`；
- `tenant_id` + Postgres RLS + JWT `tid/role`；
- Provider 凭据按租户派生密钥；
- Command Bus 租户隔离；
- 隔离测试：A 租户无法读写 B 的任何数据。

### 4.4 执行隔离（P2）

- 每租户独立 Freqtrade runtime / 容器；
- 配额、日志、健康检查；
- 完成前只允许 paper。

## 5. 阶段

### P0（当前）

- [x] 服务端 host/TrustedHost/密钥生成/部署脚本
- [x] `/readiness` 深度探针
- [x] HTTP 全链路 E2E
- [ ] Caddy/Nginx TLS 样例
- [x] Web 生产构建验证：Node 20.19 下 `npm run build` 成功（2.85s），`vite preview` 可加载 1.27MB JS

### P1（Web 生产化）

- [x] 运行时 API base（`window.__ALPHALOOP_CONFIG__` → `VITE_API_BASE` → 同源）
- [x] `features/auth` 目录起步
- [x] OpenAPI 导出脚本 `scripts/export-openapi.sh`（输出 gitignored）
- [x] features 全部产品页迁移完成（auth/dashboard/backtest/execution/risk/strategy-workspace/structure/manipulation/growth/ai-studio/agent-platform/sentiment/system/settings/live-readiness/signal-center），`tsc -b` 通过
- [x] OpenAPI → TS：`npx openapi-typescript@6 ../docs/api/openapi.json -o src/shared/api/schema.d.ts` 可生成
- [ ] 用生成类型替换手写 `lib/types.ts`
- [ ] OpenAPI 生成 TS client，删手写类型
- [x] 路由级 code splitting：主包 1.27MB → 831KB，各 feature 独立 chunk
- [ ] 响应式布局（移动浏览器可读）

### P2（iOS MVP）

- [x] `project.yml` + XcodeGen 生成 iOS 工程（`.xcodeproj` 不入库）
- [x] 共享 Models/Services/ViewModels/DesignSystem/Localization/State 直接编入 iOS target
- [x] iOS 登录（`/auth/login`）+ 总览（权益/运行/风控/持仓）+ 下拉刷新 + 登出
- [x] `xcodebuild` iOS Simulator 构建通过（BUILD SUCCEEDED）；macOS `swift build` 通过（8.73s）
- [x] CI 增加 XcodeGen + iOS simulator 构建步骤
- [ ] 抽 `AlphaLoopCore` SwiftPM target（当前先共享源码，避免一次性改访问级别）
- [x] iOS Keychain 持久化 token + 启动 `getMe` 恢复会话（macOS 仍内存存储）
- [x] 策略列表 → 版本 → 90 天回测 → 轮询状态 → 指标展示
- [x] 风控页：overview/rules + 禁止新开仓（持久化）/解除，二次确认
- [x] 策略版本只读画布（WKWebView + 同一份 canvas-web bundle + DSL 注入）
- [x] 设置页：服务端地址、语言、登出
- [x] 订单/持仓执行页（单笔撤单 / 市价平仓 + 批量撤单/平仓，均二次确认）
- [x] iOS/Web 设置页展示当前租户（名称/标识/角色）
- [x] Web 设置页配置租户执行运行时（URL/凭据/上限/健康检查）
- [ ] 推送、离线缓存

本地验证命令见 [`macos-app/IOS.md`](../../macos-app/IOS.md)。

### P3（多租户 + 执行隔离）

- [x] `tenants` / `memberships` 表 + Alembic 迁移
- [x] 注册自动创建租户（owner）+ JWT `tid/role`；`/auth/tenant` 可查询
- [x] AuthMiddleware 把 `tid` 写入 request state；`get_current_tenant_id` 可注入
- [x] `strategies_v2` / `strategy_versions` 加 `tenant_id`；创建继承、列表/详情/版本端点按 token tenant 过滤
- [x] 迁移 `0469f666f59f`：加列 + 索引 + FK + 回填默认租户
- [x] `backtest_runs.tenant_id`；启动回测写入、列表/详情/状态按 tenant 过滤
- [x] `strategy_runs` 通过 `strategy_versions.tenant_id` 间接隔离（列表/详情/订单/账本/pause/resume/stop）
- [x] 全局 Freqtrade 执行路由（`/api/orders`、`/api/execution/*`）暂只允许平台 admin，避免租户越权看全局仓位
- [x] `/api/v2/ledger/events` 按 run → version tenant 过滤
- [x] `provider_configs.tenant_id` + 按租户 HKDF 派生 Fernet 密钥（旧全局行仍用主密钥）
- [x] Provider 管理接口（列表/详情/更新/删除/测试/启停/审计/health-summary）按租户过滤
- [x] LLMService 按租户选择 Provider，并用行 tenant 密钥解密（研究/草稿链路）
- [x] RAG / AI Risk Cache 按租户选择 LLM
- [x] AI 缓存 key 按租户命名空间（`pd:runtime:tenant:{id}:{symbol}:ai_risk_cache`）
- [x] `capital_pools` / `risk_policies` tenant 字段；lookup 接口与 live-small 审批按租户校验
- [ ] positions/orders 执行数据直接 tenant 字段（依赖 per-tenant 运行时）
- [x] 全部 Alembic 迁移已在临时 PostgreSQL 17 集群实跑通过（`scripts/verify-migrations-postgres.sh`）
- [x] 应用层 PostgreSQL smoke：注册 → 登录 → `/auth/tenant` → 创建/列出策略 → 回测列表
- [ ] Postgres RLS 与跨表隔离测试
- [x] Provider 凭据按租户派生密钥（`provider_configs.tenant_id` + HKDF）
- [x] 旧主密钥/明文凭据的兼容解密与启动时重加密（`reencrypt_legacy_provider_credentials`）
- [ ] per-tenant runtime、配额、Android/Windows 选型

## 6. 风险

| 风险 | 缓解 |
|---|---|
| Swift Core 抽取破坏 macOS 编译 | 先只移动文件不改逻辑；CI 双平台编译 |
| Web 迁移影响现有页面 | 一页一页迁，行为不变 + 截图对比 |
| 多租户改动大 | 先单租户上线，RLS 分阶段 |
| 沙箱无法跑 Swift/vite | 依赖 CI；本地验证清单写清 |
| 远程部署密钥/域名配置错 | `gen-secrets.sh` + 启动 fail-fast + `/readiness` |

## 7. 待确认

1. iOS 最低版本（建议 iOS 18，若用 Liquid Glass 则 26）。
2. Web 是否要 PWA（可安装、离线只读）？
3. 多租户是否在 Web/iOS 首版就上线，还是先单租户内测？
4. Android/Windows 的启动时间点与技术选型。
