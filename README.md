# AlphaLoop

AI 驱动的加密货币量化交易工作台 — 多端 App（iOS / Android / Windows / macOS）+ 远程多租户服务端。

> **方向调整（2026-11-15）**：目标改为四端 App + 独立服务器 + 多租户 SaaS；macOS 原生客户端（`macos-app/`）暂停开发。
> 当前仓库仍保留旧的 macOS 单机结构，迁移设计见
> [`multi-client-saas-architecture-design.md`](docs/superpowers/specs/2026-11-15-multi-client-saas-architecture-design.md)。
> 下文"三个代码库"的描述是历史现状，不是目标架构。

界面默认中文（zh-CN），暗黑赛博朋克 + Liquid Glass 设计语言。

## 三个相互独立的代码库

| 路径 | 技术栈 | 职责 |
|---|---|---|
| `backend/` | Python 3.11 · FastAPI · SQLAlchemy · Pydantic v2 | API、策略评估、风控、AI 研究编排、Freqtrade 适配 |
| `macos-app/` | Swift 6.2 · SwiftUI · macOS 26+ | 原生客户端，target = `AlphaLoop` |
| `canvas-web/` | React 19 · Vite · @xyflow/react | 策略图形化编辑器（嵌入 macOS WebView） |

三方之间不共享代码,只通过 HTTP API 通信。

Provider integrations go through a unified Provider Adapter framework
(`backend/app/services/providers/`). Configuration is stored in the
`provider_configs` table; the admin API is at `/api/admin/providers/*`.
See `docs/integrations/api-audit.md` for per-provider integration
details and `docs/settings/configuration-model.md` for the configuration
schema.

## 快速开始

### 后端
```bash
cd backend
python3 run.py                          # FastAPI on :8000
python3 -m pytest tests/ -q             # 跑测试 (CI 覆盖率门槛 65%，当前 74%)
```

首次启动需要创建第一个账号（之后注册默认关闭，由管理员创建）：

```bash
curl -X POST http://127.0.0.1:8000/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"username":"admin","email":"admin@local","password":"change-me-please"}'
```

除 `/health`、`/docs`、`/auth/*` 外，所有 API 都需要 `Authorization: Bearer <token>`。
桌面端与 Web 端登录后会自动携带；远程部署请在 `.env` 设置随机 `SECRET_KEY` 与
`PULSEDESK_ENCRYPTION_KEY`（`APP_ENV=production` 时缺失会拒绝启动）。

### macOS App
```bash
cd macos-app
swift build && swift run                # 编译 + 运行
```

### Web / 策略画布

Web 端需要 Node.js 20.19+（Vite 7）；本机 Node 16 无法构建，CI 使用 Node 22。

```bash
cd web
npm ci && npm run build
```

API 地址优先级：`window.__ALPHALOOP_CONFIG__.apiBase` → `VITE_API_BASE` → 同源。
生产推荐同源反代（`/api`、`/auth`、`/ws`），不要硬编码 localhost。

策略画布：

```bash
cd canvas-web
npm install && npm run dev              # Vite dev server on :5173
```

### 后端一键部署

本机和远程用同一个入口。有 Docker 时两边都走 `docker-compose.yml`（Postgres、Redis、API、Freqtrade 模拟盘）。没有 Docker 的本机用 Homebrew 的 Postgres、Redis 和 TA-Lib，再起 API 与 Freqtrade 模拟盘。

```bash
scripts/deploy.sh local                  # 本机
scripts/deploy.sh remote user@host       # 服务器，目录默认 /opt/phosphor-terminal
scripts/deploy.sh status
scripts/deploy.sh down
```

Docker 部署会以 `APP_ENV=production` 启动，必须先在项目根目录 `.env`（或 shell 环境）提供：

```bash
SECRET_KEY=$(python3 -c "import secrets;print(secrets.token_urlsafe(48))")
PULSEDESK_ENCRYPTION_KEY=$(python3 -c "from cryptography.fernet import Fernet;print(Fernet.generate_key().decode())")
```

Docker 可用时，跑一次完整栈 smoke（构建 → readiness → 注册/登录 → dashboard）：

```bash
scripts/compose-smoke.sh
```

SaaS 就绪评估（2026-11-18）见 [`docs/planning/2026-11-18-saas-readiness-report.md`](docs/planning/2026-11-18-saas-readiness-report.md)。

多租户完成度与剩余风险见 [`docs/planning/2026-11-17-multi-tenant-completion-matrix.md`](docs/planning/2026-11-17-multi-tenant-completion-matrix.md)。
升级步骤见 [`docs/operations/multi-tenant-upgrade.md`](docs/operations/multi-tenant-upgrade.md)。

审计当前数据库的租户列/RLS 覆盖：

```bash
DATABASE_URL=... python scripts/audit-tenant-schema.py
```

部署前检查（密钥、数据库、租户角色、RLS、迁移 head）：

```bash
APP_ENV=production scripts/preflight.sh
```

验证租户隔离（临时 PostgreSQL + 迁移 + app/worker 角色 + 双租户 API/RLS）：

```bash
scripts/verify-tenant-isolation.sh
```

验证全部 Alembic 迁移（会起一个临时本地 PostgreSQL，结束后清理）：

```bash
scripts/verify-migrations-postgres.sh
```

缺失时容器会拒绝启动，而不是带着默认密钥运行。

币安官方 Agent 接入不把 API Key 放在本机。Grok 侧已登记 `binance-mcp-server`，地址是 `https://agent.binance.com/mcp/agentic`，`oauth_client_id` 为 `grok`。行情可以先读。查余额和下单要在浏览器里完成 Binance 授权，并给 Agentic 子账户转入资金。Freqtrade 这条模拟盘如果改成交易所实盘，才另外需要 API Key 和 Secret。

## 文档入口

完整文档清单见 [`docs/README.md`](docs/README.md)。常用入口：

- **产品愿景与 IA**: [`docs/product/ia_backend_redesign.md`](docs/product/ia_backend_redesign.md)
- **架构总览 (v2.5)**: [`docs/architecture/00_master_architecture_decision_v2_5.md`](docs/architecture/00_master_architecture_decision_v2_5.md)
- **开发计划**: [`docs/planning/development_plan_v2_5.md`](docs/planning/development_plan_v2_5.md)
- **页面设计稿**: [`docs/superpowers/specs/`](docs/superpowers/specs/)
- **Claude Code 协作约定**: [`CLAUDE.md`](CLAUDE.md)

## 仓库布局

```
phosphor-terminal/
├── backend/              FastAPI 后端
├── macos-app/            SwiftUI 原生应用 (AlphaLoop)
├── canvas-web/           React 策略画布
├── docs/                 全部产品 / 架构 / 设计文档
│   ├── product/          顶层产品 PRD
│   ├── architecture/     v2.5 架构决策与阶段方案
│   ├── planning/         开发计划
│   ├── superpowers/      页面级设计稿 (specs)
│   ├── ui-references/    截图与 HTML 原型
│   └── archive/          历史重构报告
├── docker-compose.yml
└── CLAUDE.md             Claude Code 工作规约
```

## 许可

私有项目。
