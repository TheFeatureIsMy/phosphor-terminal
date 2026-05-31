# Canvas UX Redesign

**Date:** 2026-05-31
**Status:** Approved
**Context:** 用户反馈画布功能太难用 — 连线反直觉、端口难找、空状态无引导、76种节点无分类引导

## 1. Problem Summary

通过对全部 16 个 canvas 文件和 5 类市场主流系统的调研分析，当前实现的核心问题：

1. **连线交互反直觉** — 两次点击模式（点端口A→点端口B），零视觉反馈。无橡皮筋线，无拖拽连线。ViewModel 有 wireDragSource 但 UI 层未接入
2. **端口不可见** — 10px 圆点，颜色与边框相同。4个无名端口（上下左右）无语义、无标签、无数据类型标识
3. **新用户无从下手** — 76 种节点平铺展示，空画布仅一行灰色提示文字，无模板、无引导
4. **配置面板扁平** — 所有参数同等级别，无主次、无端口连线状态显示
5. **状态反馈缺失** — 连线选中态、端口 hover 态、保存错误提示均不充分

## 2. Market Research

研究了三套标杆系统：

| 系统 | 端口模型 | 连线模型 | 值得借鉴 |
|------|---------|---------|---------|
| **Unreal Engine Blueprint** | Pin: name + direction(input/output) + type + LinkedTo[] | Schema 验证 ArePinsCompatible() | Pin 方向用语义而非几何, Schema 为连接规则的唯一权威 |
| **ComfyUI** | 输入参数名 → 值(值或[srcNodeId, outputIndex]) | 连接嵌入 node.inputs | DAG 执行, class_type 模式, object_info 注册表 |
| **React Flow** | sourceHandle/targetHandle (string) | 独立 Edge: {source, target, sourceHandle, targetHandle} | Handle 模式, bezier/step/straight 多线型 |

共同结论：**端口方向是 Input/Output（语义），不是上下左右（几何）**。端口应有 key（程序标识）+ name（显示标签）+ dataType（类型着色+兼容验证）。

## 3. Data Model

### 3.1 Port System

`PortSide` enum 删除，替换为 `PortDirection`：

```swift
enum PortDirection: String, Codable {
    case input   // 渲染在节点左侧
    case output  // 渲染在节点右侧
}
```

`PortDefinition` 增加字段：

```swift
struct PortDefinition: Identifiable {
    let key: String               // 稳定标识符, e.g. "kline", "rsiValue"
    let name: String              // 显示标签, e.g. "K线数据", "RSI值"
    let direction: PortDirection  // .input | .output
    let dataType: PortDataType
    let isRequired: Bool
    let allowsMultiple: Bool
    let tooltip: String           // 悬停提示（新增）
}
```

### 3.2 Edge

`sourcePort`/`targetPort` 的 raw string 改为 `sourcePortKey`/`targetPortKey`，匹配 PortDefinition.key：

```swift
struct CanvasEdge: Identifiable, Codable {
    let id: UUID
    let sourceNodeId: UUID
    let sourcePortKey: String     // matches PortDefinition.key
    let targetNodeId: UUID
    let targetPortKey: String
    // dataType 从 PortDefinition 派生, 不需要冗余存储
}
```

### 3.3 Schema Validator (NEW)

借鉴 UE Blueprint 的 EdGraphSchema:

```swift
struct ConnectionSchema {
    func canConnect(from: PortDefinition, to: PortDefinition) -> ConnectionResult
    func compatiblePorts(for output: PortDefinition, in nodes: [CanvasNode]) -> [PortMatch]
}

enum ConnectionResult {
    case allowed
    case incompatibleType(PortDataType, PortDataType)
    case wrongDirection
    case alreadyFullyConnected
    case selfConnection
}
```

## 4. Interaction Design

### 4.1 Connection: Click-to-Connect → Drag-to-Wire

| 操作 | 行为 |
|------|------|
| 从输出端口拖拽 | 拉出橡皮筋虚线，松手到输入端口完成连接 |
| 点击输出→点击输入 | 保留作为备选（触控板精细操作） |
| 拖拽中经过兼容端口 | 目标端口绿色发光，虚线变实线预览 |
| 拖拽中经过不兼容端口 | 目标端口红色 X 标记 |
| Esc | 取消当前拖拽/连接操作 |
| Shift+拖拽端口 | 创建正交线(step) |
| 点击连线 + Delete | 删除连线 |

### 4.2 Port Visual States

| 状态 | 端口样式 |
|------|---------|
| 空闲未连接 | 8px 圆点, colors.border, 40% 透明度 |
| 悬停 | 放大到 14px, PulseColors.accent, 发光 shadow |
| 连线拖拽中(源) | 脉冲动画 + accent glow |
| 经过兼容目标 | 14px 绿色脉冲, 虚线变实线预览 |
| 经过不兼容目标 | 红色 X 图标 |
| 已连接 | 10px accent 实心圆, 不透明 |
| 已连接且选中 | 同上 + 外圈光环 |

### 4.3 Node Visual Layout

```
     ┌──────────────────────┐
     │  📊 RSI 指标    [▾]  │  ← 标题栏（类别底色）
●  K线数据                  │  ← 输入端口在左侧
     │                      │
     │   周期: [14] ───●    │  ← 内嵌 widget
     │                      │  RSI值 ●→  ← 输出端口在右侧
     │                      │
     └──────────────────────┘
```

- 端口点击区域 24×24px (当前 10px → 提升 5.7x 面积)
- 端口标签在端口外侧, 12px 字体
- 必填端口用 `*` 前缀标记
- 节点最小宽度 180px, 标题栏高度 32px

### 4.4 Canvas Operations

| 操作 | 触发 |
|------|------|
| 平移画布 | 拖拽空白区 / 滚轮上下 / Space+拖拽 |
| 缩放画布 | 触控板捏合 / Cmd+滚轮 |
| 适应画布 | Cmd+0 / 底部按钮 |
| Tab 命令面板 | Tab — 搜索+添加节点（VS Code Command Palette 风格） |
| 框选 | 拖拽空白区拉出选区矩形 |
| Option+拖拽节点 | 复制节点并拖出副本 |
| 右键菜单 | 删除 / 复制 / 复制+粘贴 / 对齐(左/右/顶/均匀分布) / 折叠/展开 |
| Shift+方向键 | 微移 10px |

### 4.5 Edge Rendering

| 线型 | 触发 | 描述 |
|------|------|------|
| bezier (默认) | 直接拖拽 | 三次贝塞尔曲线 |
| step (正交) | 拖拽时按 Shift | L 形正交线 |
| straight | 后续支持 | 简洁直连 |

新增：
- **数据流向动画** — 线路上 pulse-dash 沿数据方向流动，2s 周期
- **连线悬停** — 鼠标靠近时 1.5px→3px，显示删除按钮
- **数据类型颜色** — 根据 PortDataType 着色（沿用现有色彩体系）
- **interactionWidth** — 不可见热区 20px，方便点击细线

## 5. Empty State & Templates

### 5.1 Empty State

空画布展示三种开始方式：
1. **模板卡片**（5个预设模板，主推）
2. **AI 自然语言描述**（输入中文描述自动生成节点图）
3. **空白画布**（从零开始）

```
      🧬 开始构建你的量化策略

  ┌──────────┐  ┌──────────┐  ┌──────────┐
  │ 📈 均线交叉│  │ 🤖 AI信号 │  │ ✨ 空画布  │
  │ 4 节点    │  │ 6 节点    │  │ 从零开始  │
  └──────────┘  └──────────┘  └──────────┘

  ── 或者 ──
  💬 [用自然语言描述你的策略...]  AI 生成 →
```

### 5.2 Built-in Templates

| 模板 | 节点数 | 节点列表 |
|------|--------|---------|
| 均线交叉 | 4 | K线数据 → MA(快) + MA(慢) → 交叉判断 → 入场 |
| AI 信号策略 | 6 | K线数据 → RSI + MACD + LLM推理 → 评分 → 入场 |
| 网格交易 | 5 | K线数据 → 布林带 → 网格计算 → 下单 × N |
| 多因子决策 | 8 | K线+情绪+宏观 → 多条件分支 → 凯利仓位 → 入场 |
| 空模板 | 0 | 从零开始 |

模板加载后自动 `fitToContent()`。

## 6. Config Panel

### 6.1 Layout

三层信息架构：

```
┌──────────────────────┐
│ 📊 RSI 指标       🗑  │  ← 节点头部 + 删除
│ 信号处理             │
│──────────────────────│
│ ═ 核心参数 ═         │  ← 第1层：必填参数, slider/input
│ 周期    [14] ──●     │
│ 超买    [70] ──●     │
│ ═ 端口连线 ═         │  ← 第2层：连接状态
│ ● K线数据 ✅ 已连接   │    点击可跳转对端节点
│ RSI值 ●→ → 条件判断  │
│ ──────────────────   │
│ ▶ 高级选项           │  ← 第3层：折叠, 名称/备注/条件
└──────────────────────┘
```

### 6.2 Behavior

- 默认隐藏，选中节点时从右侧滑入（250ms spring）
- 切换节点时内容交叉淡入淡出
- 参数变更即时反映到节点，3s 防抖保存
- 面板外点击/`Esc` 隐藏面板

## 7. Fullscreen Mode

| 操作 | 触发 |
|------|------|
| 进入 | Cmd+Shift+F / 工具栏按钮 / 双击画布空白区(可配) |
| 退出 | Cmd+Shift+F / Esc |

全屏态所有面板变为悬浮模式：
- 节点面板 — 贴左边缘悬浮, 半透明底, 点击外部关闭
- 配置面板 — 选中节点时出现, 失焦关闭
- 工具栏 — 顶部浮动, 3s 不操作后半透明
- 小地图 — 缩小到 120×90

## 8. Keyboard Shortcuts

```
Tab                    命令面板（搜索+添加节点）
Space+拖拽              临时切换到平移模式
Cmd+0                  适应画布
Cmd+F                  搜索节点
Cmd+Z / Cmd+Shift+Z    撤销/重做
Cmd+C / Cmd+V          复制/粘贴
Cmd+D                  快速复制（原位复制+偏移）
Delete                 删除选中
Option+拖拽节点         复制拖出副本
Cmd+A                  全选
Cmd+B                  切换节点面板
Cmd+Shift+F            全屏
Esc                    取消选择 / 取消连线 / 退出全屏
↑↓←→                 微移 1px (Shift = 10px)
```

## 9. Files to Modify

| 文件 | 改动类型 | 说明 |
|------|---------|------|
| `Models/CanvasModels.swift` | 重写 | PortSide→PortDirection, PortDefinition 增加字段, CanvasEdge 改为 sourcePortKey/targetPortKey, 新增 ConnectionSchema |
| `ViewModels/CanvasViewModel.swift` | 重写 | 新增拖拽连线状态机, rubberBand 线, 端口兼容检查, 模板加载 |
| `Views/Strategies/StrategyCanvasTab.swift` | 重写 | 全屏支持, Tab 命令面板, 新布局, 空状态模板选择器 |
| `Views/Canvas/NodeView.swift` | 重写 | 命名端口, 左右布局, 拖拽连线, 端口状态动画 |
| `Views/Canvas/NodePalette.swift` | 重写 | 搜索优先, 模板区, 简化分类展示 |
| `Views/Canvas/CanvasEdges.swift` | 重写 | bezier/step/straight 三线型, 流动动画, suspension 热区 |
| `Views/Canvas/NodeConfigPanel.swift` | 重写 | 三层架构, 端口连线状态, slider 即时反馈 |
| `Views/Canvas/MiniMapView.swift` | 修改 | 连线预览, 拖拽定位 |
| `Services/NodeRegistry.swift` | 修改 | PortDefinition 适配新字段(tooltip, direction) |
| `Views/Canvas/CanvasDragPreview.swift` | 删除 | 替换为 rubberBand 线 |

## 10. Spec Self-Review

- **Placeholders:** 无
- **Internal consistency:** 数据模型、交互行为、视觉布局三者一致 — PortDirection 驱动布局方向, PortDefinition.key 作为 Edge 引用锚点
- **Scope:** 10 个文件的改动（3 重写 + 5 重写 + 1 修改 + 1 删除），一次性完成
- **Ambiguity:** 无 — 所有交互状态（端口8种视觉状态、连线3种状态、面板2种状态）均有明确定义
