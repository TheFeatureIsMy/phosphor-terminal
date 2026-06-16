# AlphaLoop

AI 驱动的加密货币量化交易工作台 — macOS 原生客户端 + Python/FastAPI 后端 + React 策略画布。

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
python3 -m pytest tests/ -q             # 跑测试 (CI 覆盖率门槛 30%)
```

### macOS App
```bash
cd macos-app
swift build && swift run                # 编译 + 运行
```

### 策略画布
```bash
cd canvas-web
npm install && npm run dev              # Vite dev server on :5173
```

### Docker 全栈
```bash
docker compose up                       # 起 backend (:8000) + Freqtrade (:8080)
```

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
