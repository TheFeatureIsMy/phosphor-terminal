# AlphaLoop 多端 + 远程多租户架构设计

> 状态：Superseded（客户端路线与阶段由 `2026-11-15-web-ios-first-architecture-design.md` 取代；多租户/执行隔离结论保留）
> 日期：2026-11-15
> 取代：`docs/architecture/02_technical_architecture.md` §4（客户端）与 §5（本机部署）中"macOS 单机"的前提
> 关联：[P0 修复计划](../planning/2026-11-15-p0-remediation-plan.md) · [差距分析](../planning/2026-11-15-skills-and-industry-gap-analysis.md)

## 0. 背景与结论

产品方向已明确为：

- **四个客户端**：iOS、Android、Windows、macOS；
- **服务端独立部署在服务器**，不再随客户端跑在本机；
- **多租户 SaaS**：每个用户/团队的数据互相隔离；
- macOS 原生客户端（`macos-app/`）**暂停开发**，不再是主线。

仓库现状与目标存在结构性错位：

| 现状 | 目标 |
|---|---|
| README / AGENTS / 架构 02 都写 "macOS 原生 + localhost" | 四端 App + 远程 HTTPS |
| `web/` 是 Tauri 2 壳，但 `tauri.conf.json` 仍是 macOS `targets: "app"` | Windows / macOS 桌面 + 移动端 |
| 后端单租户、全局表、单 Freqtrade 容器 | 多租户隔离、按租户执行 |
| 认证是 2026-11-15 才补的全局 Bearer | 多租户 JWT、设备会话、WS 鉴权 |
| 画布两份（`canvas-web` / `web/src/canvas`） | 一份 React 画布，被四端 WebView 复用 |

**未找到旧的多端设计文档**：已检索工作区、`docs/` 全部 md/html、git 全历史（含删除文件与 pickaxe），只有 macOS 单机方案与早期 backend 设计。本文件即为重新设计。

## 1. 关键技术决策（提议）

| # | 决策 | 理由 | 备选 |
|---|---|---|---|
| D1 | **Flutter 一套代码覆盖 iOS/Android/Windows/macOS** | 四端单一代码库、接近原生的性能与手感、图表/手势成熟；团队不需要维护 4 套 UI | 完全原生（SwiftUI + Compose + WinUI）效果最佳但成本 3–4 倍；React Native 桌面端弱 |
| D2 | **画布仍用 React，Flutter 通过 WebView 嵌入** | DAG 编辑器是重交互 Web 组件，重写成本极高；现有 `web/src/canvas` 可复用 | Flutter 重写画布（不建议） |
| D3 | **后端保留 FastAPI，新增租户层 + Postgres RLS** | 现有 45k 行后端与 1483 个测试可复用；RLS 是 SaaS 隔离的底线 | 每租户独立库（运维成本高） |
| D4 | **执行层隔离：每租户独立 Freqtrade 运行时** | 单容器共用会让 A 租户的策略影响 B 租户；实盘必须隔离 | 共享进程 + 逻辑隔离（不可接受） |
| D5 | **契约优先：OpenAPI 生成 Dart / TS 客户端** | 四端 + 画布，手写类型必漂移 | 手写（现状，已出现漂移） |
| D6 | **先只对平台 owner 开放实盘；普通租户先 paper/dry-run** | 多租户下代客实盘涉及合规与资金安全 | 全量开放（不建议） |

> 如果"效果最佳"必须理解为 100% 平台原生，则改为：SwiftUI（iOS + macOS）+ Jetpack Compose（Android）+ WinUI 3（Windows）。这是 3 套代码、3 条发布链，工期约 Flutter 方案的 3 倍。默认按 Flutter 推进。

## 2. 目标架构

```text
iOS (Flutter) ─┐
Android (Flutter) ─┤
Windows (Flutter) ─┼── HTTPS/WSS ──> Reverse Proxy (Caddy/Nginx, TLS)
macOS (Flutter) ─┘                         │
                                           ▼
                                   FastAPI (multi-tenant)
                                   ├─ Auth / Tenant context
                                   ├─ BFF / REST / WS
                                   ├─ Command Bus (tenant-scoped)
                                   ├─ Provider adapters (per-tenant creds)
                                   ├─ Market data (shared)
                                   └─ Execution orchestrator
                                           │
                     ┌─────────────────────┼─────────────────────┐
                     ▼                     ▼                     ▼
              PostgreSQL (RLS)        Redis (namespaced)     Object storage
                     │
                     ▼
         Freqtrade runtime per tenant (container / job)
```

客户端不直接访问数据库、Redis、Freqtrade；所有动作经服务端。画布是 Flutter 内嵌的 React 静态包，通过 JS bridge 与服务端/Flutter 通信。

## 3. 客户端设计（Flutter）

### 3.1 技术栈

- Flutter 3.x / Dart 3，`go_router` 导航，`riverpod` 状态管理；
- `dio` + OpenAPI 生成的 Dart client；
- `flutter_secure_storage`（Keychain / Keystore）存 refresh token；
- `webview_flutter` 嵌画布；
- `fl_chart` + 自绘 K 线（或 `candlesticks`），桌面端键盘快捷键；
- 推送：FCM（Android/Windows? 不支持）/ APNs（iOS）；桌面端用 WebSocket + 本地通知；
- 生物识别解锁（`local_auth`）。

### 3.2 页面与信息架构

移动端不是桌面端缩小版：

| 端 | 导航 | 首屏 | 差异 |
|---|---|---|---|
| iOS/Android | 底部 Tab（总览 / 策略 / 执行 / 风控 / 我的） | 账户权益 + 今日 PnL + 风险状态 | 单手操作、推送、离线只读 |
| Windows/macOS | 侧边栏 + 多窗口/分栏 | 多面板工作台 | 键盘快捷键、密集表格、画布编辑 |

策略编辑（DAG）只在桌面端与平板横屏开放；手机端只读 + 参数微调。

### 3.3 客户端与服务端的契约

- 所有请求带 `Authorization: Bearer`，token 内含 `sub`、`tid`（租户）、`role`；
- base URL 运行时可配（开发/预发/生产），不硬编码 localhost；
- 401 → refresh rotation；refresh 失效 → 清会话回登录；
- WebSocket 用**短时 ticket**（`POST /auth/ws-ticket`）握手，不把长期 token 放 query；
- 离线：缓存最近一次总览/持仓快照，标注 `as_of`，禁止离线下单。

### 3.4 画布

- 抽出 `canvas/` 独立 React 包，构建为单文件静态资源；
- Flutter 通过 `webview_flutter` 加载本地 asset；
- JS bridge：`getDsl()` / `setDsl()` / `validate()` / `saveDraft()`；
- 画布不发网络请求，鉴权与保存由 Flutter 侧完成；
- `canvas-web/` 归档（macOS 冻结后不再维护），`web/src/canvas` 迁入新包。

## 4. 服务端多租户设计

### 4.1 租户模型

```text
tenants(id, name, slug, plan, status, created_at)
users(id, email, password_hash, is_active, created_at)          # 全局唯一邮箱
memberships(user_id, tenant_id, role, created_at)               # owner/admin/trader/viewer
device_sessions(id, user_id, tenant_id, refresh_hash, device, expires_at, revoked_at)
```

- JWT：`sub`（user）、`tid`（当前租户）、`role`、`jti`；
- 一个用户可属于多个租户，登录后选择/切换；
- 平台管理员（`is_platform_admin`）可跨租户运维，但所有操作写审计。

### 4.2 数据隔离

- 所有租户数据表加 `tenant_id UUID NOT NULL`，外键指向 `tenants`；
- Postgres **RLS**：`USING (tenant_id = current_setting('app.tenant_id')::uuid)`；
- 每次请求在事务开始执行 `SET LOCAL app.tenant_id = ...`；
- 平台管理员走单独数据库角色 `app_platform_admin`（BYPASSRLS）；
- SQLite 测试库不支持 RLS，测试用显式 `tenant_id` 过滤 + 隔离测试兜底。

需要加 `tenant_id` 的核心表（首批）：

`strategies_v2`、`strategy_versions`、`strategy_runs`、`freqtrade_runs`、
`execution_orders`、`execution_trades`、`execution_positions`、`execution_ledger_events`、
`command_bus_commands`、`provider_configs`、`capital_pools`、`risk_policies`、
`strategy_risk_policy_bindings`、`notifications`、`research_reports`、`growth_reports`。

共享表（不加 tenant）：`market_data`、`symbols`、`provider_catalog`、`system_settings` 的平台级项。

### 4.3 认证与授权

- 密码登录 + refresh rotation；设备会话可撤销；
- 角色：`owner`（管理租户/凭据/实盘开关）、`trader`（策略/回测/执行）、`viewer`（只读）；
- 实盘开关：`tenant.live_enabled` 默认 false，需 owner + 二次确认 + （建议）TOTP；
- 管理接口 `/api/admin/*` 仅平台管理员；
- WS 握手用一次性 ticket；所有订阅按 tenant 过滤。

### 4.4 Provider 凭据

- 每租户独立 `provider_configs` 行；
- 加密密钥按租户派生：`Fernet(HKDF(master_key, tenant_id))`，主密钥只存环境变量/KMS；
- 解密失败、密钥版本不符 → fail closed，不静默回退明文；
- 凭据字段永不返回客户端（只返回 `configured: true` + 掩码）。

### 4.5 Command Bus 与配额

- `command_bus_commands.tenant_id`；worker 按租户公平调度；
- 每租户并发上限（如 2 个回测、1 个执行命令）；
- 队列统计按租户隔离（现有 `/api/system/command-queue` 升级为租户视图 + 平台视图）；
- 长任务（回测/训练）进独立执行池，不阻塞交易命令。

### 4.6 执行隔离（最难，必须单独阶段）

现状：单 Freqtrade 容器 + 单 SQLite 路径 + 本机文件系统，无法多租户。

目标：

- 每个租户一个 runtime 目录 `/data/tenants/{tenant_id}/`；
- 每次 live_small/实盘运行为独立容器（或 K8s Job），独立 API 端口、独立 SQLite、独立 rules 文件；
- 容器网络策略：只能访问交易所 + 内部 API；不挂宿主目录；
- 编排服务负责创建/销毁/健康检查/日志回收；
- 资源配额（CPU/内存/最大 open trades）；
- 租户间行情数据共享，交易数据不共享。

在隔离完成前：**非 owner 租户只允许 paper/dry-run，禁止 live_small/live_full**。

## 5. 数据迁移策略

1. 新建 `tenants` / `memberships` / `device_sessions`；
2. 创建默认租户 `default`，把现有 `users` 全部挂到该租户（owner）；
3. 所有租户表加 nullable `tenant_id` → 回填默认租户 → 设 NOT NULL；
4. 唯一约束改为租户内唯一（如 provider identity、策略名）；
5. 启用 RLS；
6. 双写/灰度期：旧接口默认使用 token 的 `tid`，缺省回退默认租户（仅迁移期）；
7. 迁移完成后移除回退。

每一步都要有 alembic 迁移 + 回滚方案 + 数据校验脚本。

## 6. API 与契约

- 保持现有 `/api/*`、`/api/v2/*` 路径，租户从 token 解析，不放在 URL；
- 新增 `/api/auth/*`（登录/刷新/设备/切换租户）、`/api/tenant/*`（成员/配额/凭据状态）；
- 导出 `openapi.json`，CI 生成 Dart client 与 TS client；客户端禁止手写响应类型；
- 错误统一：`{detail, reason_codes[]}`；分页统一游标；
- 版本策略：破坏性变更进 `/api/v3`，旧版保留一个发布周期。

## 7. 部署与运维

- 反向代理：Caddy/Nginx 自动 TLS，HTTP/2 + WebSocket；
- 容器：`api`、`worker`、`postgres`、`redis`、`execution-orchestrator`；
- Postgres：每日备份 + PITR；Redis 仅缓存/队列，不作为真相源；
- 观测：请求日志、租户维度指标、Command 队列、Freqtrade 心跳、告警；
- 秘钥：KMS/环境变量注入，禁止进镜像；
- 区域与合规：至少明确数据存放区域；实盘涉及地区法规需单独评估。

## 8. CI / 发布

| 目标 | Runner | 产物 |
|---|---|---|
| iOS | macOS | `.ipa`（TestFlight） |
| Android | ubuntu | `.aab`（Play） |
| Windows | windows | `.msix` / NSIS |
| macOS | macOS | `.dmg`（签名 + 公证，恢复开发后） |
| backend | ubuntu | 镜像 + 测试 + 覆盖率 ≥65% |

Flutter 四端在 CI 矩阵构建；画布静态包在构建前生成并注入 Flutter assets。

## 9. 阶段计划

### P0 — 远程服务端可用（1–2 周）

- [x] 后端 `SERVER_HOST` / `SERVER_PORT` 可配置，默认仍回环；Docker 置 `0.0.0.0`
- [x] `TrustedHostMiddleware` + `ALLOWED_HOSTS`（默认 localhost，远程填域名）— 已完成并通过测试
- [ ] 反向代理 + TLS（Caddy/Nginx 样例）
- [ ] 客户端 base URL 配置化（先 Flutter 壳 + 登录）
- [ ] WS ticket 鉴权
- [ ] OpenAPI 导出 + Dart client 雏形
- [x] README/AGENTS 改为多端方向，macOS 标注冻结

验收：公网 HTTPS 下，Flutter 登录 → 总览 → 登出闭环；匿名/过期 token 全部 401。

### P1 — 租户地基（3–5 周）

- tenants/memberships/sessions 表 + JWT `tid/role`；
- `tenant_id` 迁移 + RLS + 隔离测试；
- Provider 凭据按租户派生密钥；
- Command Bus 租户字段 + 队列隔离；
- 现有接口按 token 租户过滤。

验收：两个租户的 A 用户无法读写 B 的任何策略/运行/订单/凭据（自动化测试）。

### P2 — Flutter 核心客户端（4–6 周）

- 登录/切换租户、总览、策略列表/详情、回测、执行、风控、设置；
- iOS/Android 自适应 + Windows/macOS 桌面布局；
- 实时推送、离线快照；
- 画布 WebView 只读版。

验收：四端可完成"登录 → 看总览 → 选策略 → 跑回测 → 看结果"。

### P3 — 画布编辑 + 实盘隔离（4–6 周）

- 画布编辑/校验/发布；
- 每租户执行运行时、容器编排、配额；
- owner 实盘开关 + TOTP + 审计。

验收：A 租户的 live 运行不影响 B；非 owner 无法开启实盘。

### P4 — 发布与运营

- 四端商店/签名/公证、崩溃上报、版本强制升级；
- 计费/配额（若商业化）、数据导出/删除（合规）。

## 10. 风险

| 风险 | 影响 | 缓解 |
|---|---|---|
| 多租户执行隔离复杂 | 阻塞 SaaS 实盘 | 先 paper-only，隔离完成再开实盘 |
| Flutter 画布体验弱 | 策略编辑体验下降 | 画布保留 WebView，只重写外壳 |
| 现有后端单租户假设深 | 迁移面大 | RLS + 分阶段表迁移，不一次改完 |
| Freqtrade 多实例资源开销 | 成本高 | 按租户 plan 限制并发运行数 |
| 移动端实时图表性能 | 卡顿 | 降采样 + 服务端聚合 |
| 合规/地区限制 | 无法上线 | 先 paper-only，实盘按地区灰度 |

## 11. 待确认

1. Flutter 方案是否确认？若坚持 100% 原生，需要按 3 套代码重估工期。
2. 租户是"一人一租户"还是"团队/组织"？是否允许一个用户属于多个租户？
3. 首期是否只做 iOS + Android + Windows，macOS 延后？
4. 实盘是否只对平台 owner 开放，普通租户长期 paper-only？
5. 是否需要计费/套餐/配额，还是内部单租户多设备优先？
