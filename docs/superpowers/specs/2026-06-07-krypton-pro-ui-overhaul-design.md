# Krypton Pro macOS UI 全面优化 — 设计规约

日期: 2026-06-07 | 状态: 待审批

## 目标

对 PulseDesk macOS SwiftUI 应用进行全面 UI 品质提升，覆盖设计系统清理、组件统一、排版规范化、动效打磨、加载/空/错误态一致性、glassEffect 审计。

## 设计约束

- 动效强度：**平衡** — 适度弹簧、交错入场、微交互，不炫技
- 排版：**严格 PulseFonts** — 禁止硬编码 .font(.system(...))。排除：Canvas/图表绘制内部、EquityCurveChart 等自定义 Shape 的标注字体
- 组件：统一迁移到 KryptonCard(emphasis:) — 移除 SpotlightCard/GlassCard/ProofAlphaCard
- glassEffect：审计修复所有误用 — 必须直接作用于内容，不在 .background 内
- 工作区切换：缩放深度过渡，类似 macOS Spaces

---

## Section 1: 设计系统层

### 1.1 清理废弃组件

移除以下组件及其 typealias：
- `ProofAlphaCard` → 全部替换为 `KryptonCard(emphasis:)`
- `SpotlightCard` → 替换为 `KryptonCard(emphasis: .balanced)`
- `GlassCard` → 替换为 `KryptonCard(emphasis: .bold)`
- `ProofAlphaButton` → 替换为 `KryptonButton`

### 1.2 PulseFonts 补全

新增变体：
- `displayLarge` — 32pt bold（页面主标题）
- `headline` — 15pt semibold（卡片标题）
- `label` — 12pt medium（表单标签）

### 1.3 动画预设扩展

新增：
- `workspaceTransition` — spring(0.25, damping 0.8)，工作区切换
- `cardEntry` — spring(0.4, damping 0.75)，卡片入场

### 1.4 glassEffect 规则

强制约束：`.glassEffect()` 只能直接作用于内容视图。禁止 `.background { glassEffect() }` 模式。

---

## Section 2: 组件层

### 2.1 KryptonCard 增强

新增变体参数：
- `isEmpty: Bool` — 虚线边框 + 居中 TerminalLabel
- `isLoading: Bool` — 内置 shimmer 骨架屏
- `errorMessage: String?` — 红色左边框 + 错误 + 重试
- `onRetry: (() -> Void)?` — 错误态重试回调

### 2.2 新统一组件

| 组件 | 用途 |
|------|------|
| `EmptyStateView` | 图标 + TerminalLabel + 可选按钮 |
| `LoadingCard` | shimmer 骨架卡片 |
| `ErrorCard` | 错误信息 + 重试按钮 |
| `SectionHeader` | `// SECTION` 标签 + 右侧操作 |

### 2.3 StatusDot 增强

- 新增 `.warning`（琥珀色）
- idle 脉冲周期降速 3x

---

## Section 3: 视图层

### 3.1 工作区切换

`AppShellView.workspaceContent`:
- ZStack + opacity → `.transition(.asymmetric(...))` + matchedGeometryEffect
- 缩放深度过渡：0.25s spring, damping 0.8

### 3.2 侧边栏

- WorkspaceIconButton: 统一 hoverGlassStyle
- 激活态: 液态玻璃高亮 + accent 发光
- ⌘K/设置按钮: hoverGlassStyle
- Logo: hover 时微脉冲光环

### 3.3 全局状态栏

- PulseFonts 统一
- StatusDot 统一状态指示
- DataFlowLine 用于数据流指示

### 3.4 Dashboard Bento Grid

- 8 张卡片 → KryptonCard
- staggeredAppearance 入场 (35ms/张)
- CountUp 数字弹簧动画
- TickerTapeView 边缘渐变遮罩

### 3.5 其余视图

- 列表: 统一 shimmer 加载态 + TerminalLabel 空态
- 表单: 统一 SectionHeader
- Sheet: 统一圆角 + 玻璃态背景

---

## Section 4: 交互打磨

### 4.1 悬停统一

| 元素类型 | 反馈 |
|---------|------|
| 卡片 | hoverGlassStyle + accent 边框 |
| 按钮 | pressEffect (0.97 scale + 微亮) |
| 行 | hover 背景色 + 左边框 accent |

### 4.2 Toast/通知

- Toast: StaggeredAppearance 入场
- 通知 Popover: 统一排版令牌

### 4.3 键盘导航

- CommandPalette: hover 高亮 + 上下键选择
- Escape 统一关闭 Sheet/Popover/Palette

### 4.4 性能

- 清理冗余 GeometryReader 嵌套
- Shimmer → TimelineView 驱动
- 大型列表确认已使用 LazyVStack（非 VStack+ForEach）

---

## Section 5: 实施阶段

| Phase | 内容 | 目录 |
|-------|------|------|
| P1 | 设计系统清理 + PulseFonts 补全 | DesignSystem/ |
| P2 | 组件升级 + 新组件 | Views/Shared/ |
| P3 | 工作区动画 + AppShell 打磨 | Views/AppShell/ |
| P4 | Dashboard 迁移 | Views/Dashboard/ |
| P5 | 其余视图逐批迁移 | Views/ 所有剩余 |
| P6 | glassEffect 全量审计修复 | 全局 |
| P7 | 交互动效 + 性能 + 验证 | 全局 |

---

## 成功标准

1. `PulseFonts` 之外无硬编码 `.font(.system(...))`
2. 无 `SpotlightCard`/`GlassCard`/`ProofAlphaCard` 引用
3. 所有 `.glassEffect()` 直接作用于内容（非 .background）
4. 所有列表/卡片加载态使用统一 shimmer
5. 所有空态使用 EmptyStateView + TerminalLabel
6. 工作区切换有缩放深度过渡动画
7. `swift build` 通过
8. 所有现有测试通过
