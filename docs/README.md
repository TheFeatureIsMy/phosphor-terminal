# Documentation Index

文档分为五大区域：**产品 → 架构 → 计划 → 设计稿 → 历史**。当前主线版本：v2.5。

> 📖 **面向最终用户**：完整的中英双语用户指南在 [`user-guide/`](user-guide/index.html)（10 概念章 + 25 页面章 + 5 走查）。直接在浏览器打开 `user-guide/index.html`，或在 macOS app 的侧边栏底部点 "用户指南"。

## 🎯 product/ — 产品 PRD

顶层产品定义,所有架构与设计的源头。

- [`ia_backend_redesign.md`](product/ia_backend_redesign.md) — **最终版** 产品信息架构 + 后端重设计（页面、API、状态机的权威来源）
- [`initial_tech_design.md`](product/initial_tech_design.md) — 项目最初的技术设计稿（历史参考）

## 🏛 architecture/ — v2.5 架构总览

按编号阅读：00 → 17 串成完整架构线。

| 编号 | 内容 |
|---|---|
| `00_master_architecture_decision_v2_5.md` | **主架构决策（v2.5）** — 必读 |
| `00_sources_and_evidence.md` | 决策依据与引用 |
| `01_prd_pulsedesk_v2.md` | v2 期 PRD |
| `02_technical_architecture.md` | 技术架构 |
| `03_app_ia_and_ui_layouts.md` | 应用信息架构与 UI 布局 |
| `04_data_models_api_db.md` | 数据模型 / API / DB schema |
| `05_security_risk_guardrails.md` | 安全与风控护栏 |
| `06_ai_development_prompts.md` | AI 开发提示词 |
| `07_engineering_optimizations_v2_2.md` | 工程优化（v2.2） |
| `08_cloud_hybrid_ai_routing_v2_3.md` | 混合云 AI 路由（v2.3） |
| `09_code_implementation_hardening_v2_3_2.md` | 实现加固（v2.3.2） |
| `10_database_erd_v2_4.md` / `10_database_erd_v2_5.md` | 数据库 ERD（v2.4 / v2.5） |
| `11_module_boundaries_v2_4.md` | 模块边界（v2.4） |
| `12_exchange_api_strategy_v2_4.md` | 交易所 API 策略（v2.4） |
| `13_strategyruledsl_semantics_v2_5.md` | 策略规则 DSL 语义 |
| `14_command_bus_worker_contract_v2_5.md` | Command Bus + Worker 合约 |
| `15_execution_ledger_contract_v2_5.md` | 执行账本合约 |
| `16_freqtrade_runtime_contract_v2_5.md` | Freqtrade 运行时合约 |
| `17_phase_plan_v2_5.md` | 阶段计划总览 |

子目录：

- [`phases/`](architecture/phases/) — Phase 01–07 详细阶段方案（信号中心 / Freqtrade 适配 / 策略画布 / AI 研究 / 操纵雷达 / 增长引擎 / 小仓位安全运营）
- [`changelog/`](architecture/changelog/) — v2.3 / v2.3.2 / v2.4 / v2.5 修订日志

## 📅 planning/ — 开发计划

- [`development_plan_v2_5.md`](planning/development_plan_v2_5.md) — 当前阶段任务、节奏、依赖

## ✨ superpowers/ — 页面级设计稿

每个文件是一次 brainstorming → spec → implementation 的产物。命名：`YYYY-MM-DD-<topic>-design.md`。

| 文件 | 主题 |
|---|---|
| `2026-06-07-krypton-pro-ui-overhaul-design.md` | 整站 UI 翻新（Krypton Pro） |
| `2026-06-10-market-structure-causal-storyboard-design.md` | 市场结构页 — Causal Storyboard |
| `2026-06-10-structure-matrix-column-first-design.md` | 结构矩阵页 — Column-First（已废弃） |
| `2026-06-10-structure-matrix-htf-tribunal-design.md` | 结构矩阵页 — **HTF Tribunal**（当前实施） |

新的页面 spec 应继续放在 [`superpowers/specs/`](superpowers/specs/)。如果旧 spec 被新的取代,在新 spec 的 frontmatter 加 `Supersedes:` 行而不是删除旧文件。

## 🖼 ui-references/ — 截图与原型

- [`mockups/`](ui-references/mockups/) — HTML 静态原型（`index.html`, `phase2-preview.html`）
- [`screenshots/`](ui-references/screenshots/) — 28 张微信收到的 UI 参考截图

## 🗄 archive/ — 历史

完成或废弃的工作快照,只保留不维护。

- [`archive/refactor/`](archive/refactor/) — 早期重构 sprint 的审计报告与交付总结

## 写新文档时

| 场景 | 放哪里 |
|---|---|
| 产品 PRD 改动 | `product/` |
| 新架构决策（v2.6+） | `architecture/` + 加 changelog |
| 新阶段计划 | `architecture/phases/` |
| 单页面设计 / 重设计 | `superpowers/specs/YYYY-MM-DD-<topic>-design.md` |
| UI 截图 / 原型 | `ui-references/` |
| 完结报告 / 弃用文档 | `archive/` |
