# Findings — PulseDesk

## 架构决策
- 前端先于后端开发, 全 mock 模式下独立可运行
- superpower 规划文档中的 Phase 1-4 已全部实现为一个批次提交
- Tauri v2 桌面壳仅基本集成, 未深度测试

## 风险项
- `splash-cursor.tsx` ESLint 全局忽略 — 含第三方代码
- `src-tauri/target/` 需在 `.gitignore` 中排除 (已配置)
- 后端测试覆盖率待确认
- AI Research / Agent Signal Hub 依赖 TradingAgents, LICENSE 状态不明

## 已知问题
- 部分新 UI 组件 (particles, splash-cursor) 在 SSR/测试环境可能有问题
- Tauri 桌面编译需 macOS 本地 Rust 工具链
