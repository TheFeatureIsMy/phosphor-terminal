# Canvas Production Redesign — Design Spec

**Date:** 2026-05-31
**Status:** Approved
**Scope:** StrategyCanvasTab + all canvas subcomponents (macOS SwiftUI app)

## Problem Statement

The current strategy canvas implementation is a functional prototype but not production-ready. Key gaps:

1. **Performance** — No viewport culling. All nodes rendered via `ForEach` regardless of visibility. 80+ nodes causes frame drops.
2. **Edge precision** — Edges connect to node centers, not specific port positions.
3. **Undo/redo** — Every drag `onChanged` event creates a separate undo entry. No coalescing.
4. **Error handling** — Auto-save fails silently. No user feedback for save/load errors.
5. **Interaction** — No copy/paste, no snap-to-grid, no multi-node drag, no in-canvas search.
6. **Palette UX** — 76 node types in raw DisclosureGroups. No favorites, recents, or drag-to-add.
7. **Config panel** — `filePicker` is a stub. No input validation. No real-time preview.
8. **Code generation** — Only 15 indicator types supported. Rest emit `# TODO` comments.
9. **Validation** — Cycle/orphan detection only at code-gen time, not at connection time.

## Target State

Production-ready visual strategy editor for 80–200+ node workflows. ComfyUI-style node cards + Node-RED interaction efficiency, wrapped in the existing ProofAlpha dark cyberpunk design system.

## Architecture

### Four-Layer Canvas Z-Stack

```
z=4  Overlay Layer    — SelectionRect, DragPreview, SnapGuides, ValidationIndicators, SearchHighlight
z=3  Node Layer        — ViewportCulled NodeDragWrapper (SwiftUI Views, only visible nodes rendered)
z=2  Edge Layer        — CanvasEdges (Canvas 2D): Bezier curves + data-flow particles
z=1  Background Layer  — CanvasBackground (Canvas 2D): dot-grid + scanlines
```

### File Changes

| File | Action | Description |
|------|--------|-------------|
| `Views/Canvas/CanvasBackground.swift` | Keep | No changes needed |
| `Views/Canvas/CanvasEdges.swift` | **Rewrite** | Precise port routing + particle animation |
| `Views/Canvas/CanvasDragPreview.swift` | Keep | No changes needed |
| `Views/Canvas/CanvasSelectionRect.swift` | Keep | No changes needed |
| `Views/Canvas/MiniMapView.swift` | **Enhance** | Resize handle, smooth scroll, selection highlight |
| `Views/Canvas/NodeView.swift` | **Enhance** | Status badges, collapse summary, port highlight on hover |
| `Views/Canvas/NodePalette.swift` | **Rewrite** | Tab bar + favorites + recents + drag-to-add |
| `Views/Canvas/NodeConfigPanel.swift` | **Rewrite** | Validation, preview, filePicker, undo coalescing |
| `Views/Canvas/CodePreviewSheet.swift` | Keep | No changes needed |
| `Views/Canvas/GroupBoxView.swift` | Keep | Wire to multi-select |
| `Views/Canvas/VariableSelector.swift` | Keep | No changes needed |
| `Views/Canvas/ViewportCuller.swift` | **New** | Visible-node filter with buffer padding |
| `Views/Canvas/SnapGuidesView.swift` | **New** | Alignment guide lines overlay |
| `Views/Canvas/NodeBadges.swift` | **New** | Error/warning/connected status badges |
| `Views/Canvas/CanvasSearchOverlay.swift` | **New** | ⌘F search overlay |
| `Views/Canvas/ConnectionPreview.swift` | **New** | Port snap preview during wire drag |
| `ViewModels/CanvasViewModel.swift` | **Rewrite** | Coalesced undo, clipboard, multi-drag, loading state, error state |
| `Models/CanvasModels.swift` | **Enhance** | Add `CachedPortPosition`, `SnapCandidate` types |
| `Services/NodeRegistry.swift` | Keep | No changes needed |
| `Services/GraphSerializer.swift` | Keep | No changes needed |
| `Services/CodeGenerator.swift` | **Enhance** | 20→55 node types, template registry pattern |
| `Services/EdgeValidator.swift` | **New** | Type compatibility matrix, cycle detection |
| `Services/EdgeRouter.swift` | **New** | Port-to-screen-coordinate calculator |
| `Services/ClipboardManager.swift` | **New** | NSPasteboard copy/paste with UUID rekeying |
| `Services/SnapEngine.swift` | **New** | 8px threshold edge/center alignment |
| `Services/CanvasErrorNotifier.swift` | **New** | Toast notifications for save/load errors |

### Data Flow

```
User Gesture → StrategyCanvasTab (gesture routing)
  → CanvasViewModel (state mutation + undo record + scheduleSave)
    → graph.nodes/edges (@Observable → SwiftUI auto-refresh)
      → ViewportCuller (filter visible nodes)
      → EdgeRouter (compute screen paths for visible edges)
        → CanvasEdges / NodeView (render)
```

**Auto-save:** 3s debounce via `CanvasViewModel.scheduleSave()` → `GraphSerializer.serialize()` → `APICanvas.save()`. On failure → `CanvasErrorNotifier` shows toast with retry count.

## Module Designs

### 1. ViewportCuller (New)

```
ViewportCuller {
    padding: 200px  // off-screen buffer to prevent pop-in

    func visibleNodes(nodes, viewport, canvasSize) -> [CanvasNode] {
        visibleRect = worldVisibleRect(viewport, canvasSize).insetBy(-padding)
        return nodes.filter { visibleRect.intersects($0.frame) }
                 + selectedNodes  // always render selected nodes
    }
}
```

Usage in StrategyCanvasTab: wrap in GeometryReader to get actual canvas size, pass to culler, `ForEach(visible)` instead of `ForEach(all)`.

### 2. EdgeRouter (New) — Precise Port Positioning

Computes world-coordinate position for each port circle:

- **Input port Y:** `node.y + titleBarHeight(30) + portIndex * portSpacing(18) + halfPortSize(6)`
- **Output port Y:** `node.y + titleBarHeight + (inputCount * 18) + gap(12) + portIndex * 18 + 6`
- **Input X:** `node.x` (left edge)
- **Output X:** `node.x + node.width` (right edge)

### 3. EdgeValidator (New) — Real-time Connection Validation

**Check at wire-drag time:**
- Port type compatibility (downward-compatible chain: `kline → indicator → signal → boolean → output`)
- Generic types (`text/number/array/object`) pass through freely
- `llmOutput → text`, `sentiment → signal`, `riskMetric → number`

**Check at connection completion:**
- Cycle detection (topological sort check)
- Single-connection enforcement when `allowsMultiple == false`
- Required input port satisfaction → warning badge on node

Feedback: compatible target ports glow green during drag; incompatible ports gray out.

### 4. CanvasEdges Rewrite

- Precise start/end at port coordinates (via EdgeRouter)
- Default 2px stroke, selected edge 3px + glow shadow
- Data-flow particles every 80px along path, animated via TimelineView
- Particles hidden when `scale < 0.3` (zoom-out optimization)
- Only edges with at least one endpoint in viewport are drawn
- Disabled edges: dashed + gray

### 5. NodePalette Rewrite

Replace `DisclosureGroup` tree with:
- Horizontal scrollable category tab bar (全部/数据/信号/决策/AI/输出)
- Favorites section (persisted to UserDefaults, max 20)
- Recently used section (in-memory, max 10, MRU order)
- Search bar with ⌘K shortcut, fuzzy match on name/type/category
- Drag-to-add: each item has DragGesture; drop on canvas calculates world-coordinate position
- Click-to-add retained as fallback

### 6. NodeConfigPanel Rewrite

- **Validation:** number fields check min/max inline (red border on violation). Required fields marked with red asterisk.
- **Real-time preview:** slider/number changes immediately visible on node body via `@Observable` propagation.
- **filePicker:** `NSOpenPanel` integration for `.py`, `.csv`, `.json` files.
- **Undo coalescing:** 500ms debounce per key — consecutive changes to same field coalesced into single undo entry.
- **Reset button:** per-field reset to `ConfigField.defaultValue`.
- **Layout:** name field → notes field → dynamic config schema → advanced options (collapsible) → actions (delete/reset).

### 7. Interaction System

**ClipboardManager (New):**
- ⌘C serialize selected nodes + their edges to NSPasteboard as JSON
- ⌘V deserialize, assign new UUIDs, offset position by (50, 50)
- ⌘D = copy + paste in one step
- Edge references rekeyed to new node UUIDs

**SnapEngine (New):**
- 8px snap threshold
- Snap to: left/right/top/bottom edges, horizontal/vertical centers
- Visual feedback via SnapGuidesView (dashed lines)
- Grid snap (20px) toggleable with Shift key
- Evaluated on drag end, not during drag

**Multi-select:**
- SelectionRect wired to multi-node select
- Multi-node drag maintains relative positions
- Shift-click appends to selection
- ⌘A selects all nodes + edges
- GroupBox integration: selecting a group selects all member nodes

**CanvasSearchOverlay (New):**
- ⌘F opens floating search bar (centered top)
- Type to filter → matching nodes highlight, viewport animates to first match
- ⌘G / ⇧⌘G jump to next/previous match
- No-match: search bar briefly turns red + shakes

**Keyboard Shortcuts (complete map):**
| Key | Action |
|-----|--------|
| ⌘C / ⌘V / ⌘D | Copy / Paste / Duplicate |
| ⌘A | Select all |
| ⌘F / ⌘G / ⇧⌘G | Search / Next match / Prev match |
| ⌘Z / ⇧⌘Z | Undo / Redo |
| Delete | Delete selected |
| 0 | Fit to content |
| ⌘K | Focus palette search |
| Space+drag | Pan canvas (temporary) |
| Shift | Toggle grid snap |
| ⌘Arrow | Nudge selection 1px |
| ⇧⌘Arrow | Nudge selection 10px |

### 8. NodeView Enhancements

- **Status badges:** warning badge (⚠) on nodes with unsatisfied required inputs; error badge (✕) on nodes with invalid config
- **Collapse summary:** when collapsed, show first output variable name + value preview (e.g., "RSI: 62.5")
- **Port hover:** port circles scale up on hover (1.2x) and glow with data type color

### 9. Engineering Quality

**Undo/Redo Coalescing:**
- Drag: record `startDrag` position, commit single `.moveNode` on `endDrag` if position changed
- Config: 500ms debounce per key — consecutive same-key changes merged (oldest `old` + newest `new`)
- Undo stack cap: 100 entries (FIFO eviction)

**Error Handling:**
- `CanvasErrorNotifier` service: emits toast messages for save/load failures
- `CanvasViewModel.isLoading: Bool` — drives skeleton screen
- `CanvasViewModel.saveStatus: SaveStatus` enum (saved/saving/error/dirty)
- Bottom status bar: "已保存" / "保存中..." / "保存失败" / "● 未保存"
- Auto-save retry: 3 consecutive failures → persistent warning icon

**Loading State:**
- On canvas load: skeleton screen with 4–6 node-shaped shimmer placeholders
- On data arrival: skeleton fades out, nodes fade in with staggered animation

**Animations:**
- Node add: scale 0.8→1.0 + opacity 0→1 (spring)
- Node delete: scale 1.0→0.8 + opacity 1→0 (easeOut 150ms)
- New edge: brief opacity pulse (0→1→0.7→1 over 500ms)
- Search jump: viewport smooth animation to target
- Config panel / palette: existing slide transitions retained

### 10. CodeGenerator Enhancement

**Coverage:** 20 node types → 55 node types

| Category | Before | After |
|----------|--------|-------|
| Data/Indicator | 15 | 25 |
| Signal Processing | 5 | 15 |
| Decision | 0 | 10 |
| AI | 0 | 5 |
| Output | 5 | 5 |

**Architecture change:** Replace `switch/case` with dictionary-driven template registry: `[nodeType: CodeTemplate]`. Adding a new node type requires only a new template entry, not generator logic changes. Unknown node types still emit `# warning: unhandled` annotations in generated code rather than silent `# TODO`.

### 11. Testing Strategy

**Swift side (new `CanvasViewModelTests`):**
- `ViewportCullerTests`: 100 random-positioned nodes, verify visible set subset property, verify selected nodes always included
- `SnapEngineTests`: verify snap threshold (8px), edge/center alignment math
- `EdgeValidatorTests`: type compatibility matrix completeness, cycle detection correctness
- `CanvasViewModelTests`: undo/redo push/pop, copy/paste UUID rekeying, drag coalescing
- `GraphSerializerTests`: round-trip with 200 nodes

**Backend (new `test_canvas.py`):**
- `CanvasWorkflow` CRUD endpoint tests
- Large graph JSON (200+ nodes) storage/retrieval

### 12. MiniMap Enhancements

- Draggable resize handle (bottom-right corner)
- Viewport rectangle drag with smooth animation
- Selected nodes highlighted in minimap
- Edge lines shown as thin strokes (sampled)
- Opacity: 0.9 on hover, 0.4 when idle (auto-fade after 3s)

## Implementation Phases

### Phase 1 — Core Performance + Edge Fixes (3–4 days)
ViewportCuller, EdgeRouter (precise ports), EdgeValidator (type checking), CanvasEdges rewrite (particles)

### Phase 2 — Interaction Efficiency (2–3 days)
ClipboardManager, SnapEngine, multi-select drag, CanvasSearchOverlay, keyboard shortcut system

### Phase 3 — Panel Reworks (2–3 days)
NodePalette rewrite, NodeConfigPanel rewrite, filePicker, config validation, undo coalescing

### Phase 4 — Polish + Code Gen (2–3 days)
CanvasErrorNotifier, loading skeleton, MiniMap enhancement, CodeGenerator 20→55 types, tests

**Total: ~9–13 days**

## Design Principles

- **YAGNI:** No speculative features. GroupBox exists but is unused — wire it up rather than replacing it.
- **ProofAlpha consistency:** All new views use existing design tokens (`PulseColors`, `PulseFonts`, `PulseSpacing`, `PulseRadii`). Use `CardModifier`, `GlassModifier`, `GlowBorder` from existing DesignSystem.
- **SwiftUI native:** Prefer standard SwiftUI controls over custom Canvas drawing for interactive elements. Canvas 2D only for non-interactive batch rendering (background, edges).
- **@Observable propagation:** All state changes flow through `CanvasViewModel.graph` which is `@Observable`. Views react automatically. No manual refresh triggers.
- **Backend unchanged:** The `CanvasWorkflow` blob-storage model is adequate for the visual editor use case. No backend schema changes needed.
