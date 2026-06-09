# Structure Matrix · Column-First Redesign

**Date**: 2026-06-10
**Author**: design pair
**Status**: approved, ready for implementation
**Replaces**: `macos-app/AlphaLoop/Views/Structure/StructureMatrixView.swift` (current grid layout)

---

## 1. Why this page exists

The "Structure Matrix" page is **not** an SMC/ICT research panel — that role belongs to the adjacent `MarketStructureView`. The matrix page is the trader's **pre-entry MTF consistency referee**:

> Before I press "open order" / "scale in" — is every relevant structural zone (OB / FVG / Liquidity Pool) **healthy on every timeframe I care about** (5m → 15m → 1h → 4h)?
> If not, **which zone on which timeframe is broken**, and what's the recommended action (allow / reduce_size / block_entry / observe)?

It must be **scannable in under one second** — the trader will tab to it, glance, and tab back to the order ticket. Density matters more than beauty; clarity of the cross-timeframe story matters most of all.

Data contract is fixed by the existing BFF (`/api/structure/matrix?symbol=…`): 4 timeframes × 3 zone types = up to 12 `MatrixCell`s, each carrying `status`, `current_strength`, `filled_ratio`, `temporary_violation`, `action`, and `reason_codes`. The page also receives an overall `state` (healthy / warning / violated) and aggregated `reason_codes`.

## 2. What's wrong with the current implementation

1. **Information hierarchy is inverted.** The overall `state` — the single most important output — is reduced to a small banner; the refresh button occupies the prime top-right slot.
2. **The matrix is a dumb grid.** Each cell shows one number and a color block. Cross-timeframe alignment (the trader's actual mental model) gets the same visual weight as cross-zone correlation.
3. **`filled_ratio` is nearly invisible.** It's the canonical "this FVG is about to invalidate" signal but lives only in the popover.
4. **Shadow Window panel duplicates matrix data** with no visual link, forcing the reader's eye to ping-pong between two regions.
5. **Generic look.** The current grid could belong to any analytics dashboard. Nothing about it says "trading terminal / risk console."

## 3. The new direction: Column-First

We replace the row-major grid with **three vertical zone towers**: Order Block / FVG / Liquidity Pool. Each tower contains four stacked `TowerSegment`s, top-down `4h → 1h → 15m → 5m`. A **TF gutter** on the left shows the timeframe labels with a vertical timeline thread running through them — visually anchoring all three towers to the same temporal axis.

This makes the page answer one question at a glance:

> "Are all four timeframes aligned for this zone type? If not, which segment is broken?"

A break in any tower segment shows as a colored interruption + pulse + alignment-bar dot, immediately legible without reading numbers.

### Layout (1440 px reference)

```
┌─────────────────────────────────────────────────────────────────┐
│ ▥  Structure Matrix · 结构矩阵                                  │
│    vertical zone-consistency towers                             │
│                                                                 │
│   ┌────────────────────────────────────────┐  [BTC|ETH] [↻]   │
│   │ ● WARNING · 1h OB temp_viol · 1h FVG…  │                   │
│   └────────────────────────────────────────┘                   │
├─────────────────────────────────────────────────────────────────┤
│ ◣ ZONE CONSISTENCY TOWERS                       3 zones × 4 tf │
├──────┬──────────────┬──────────────┬──────────────────────────┤
│      │ ◧ Order Block│ ▤ FVG        │ ≋ Liquidity Pool          │
│      │ OB / mitig.  │ FVG / imbal. │ LP / equal-highs & lows   │
│      │  3 / 4 ALIGN │  1h · 85% FIL│  3 / 4 ALIGN              │
│      ├──────────────┼──────────────┼───────────────────────────┤
│      │              │              │                           │
│  4h  │ ⊙ 88  strong │ ⊙ 12  filled │ ⊙ 85  buy · 2 touches    │
│  HTF │ ▰▰▰▰▰▰▰▰ allow│ ▰▰▰▰▰▰▰▰ allow│ ▰▰▰▰▰▰▰▰ allow         │
│  ┊   ├──────────────┼──────────────┼───────────────────────────┤
│  │   │              │              │                           │
│  1h  │ ⊙ 41 ▲TEMP   │ ⊙ 85  near   │ ⊙ 35  sell · 3 weak       │
│  ┊   │ ▰▰▰▱▱ reduce │ ▰▰▰▰▰ reduce │ ▰▰▱▱▱ observe             │
│      ├──────────────┼──────────────┼───────────────────────────┤
│ 15m  │ ⊙ 82  strong │ ⊙ 42  filled │ ⊙ 60  buy · 1 mid         │
│  ┊   │ ▰▰▰▰▰▰▰▰ allow│ ▰▰▰▰▰▰▰▰ allow│ ▰▰▰▰▰▰ allow             │
│      ├──────────────┼──────────────┼───────────────────────────┤
│  5m  │ ⊙ 78  strong │ ⊙ 35  filled │ ⊙ 70  buy · 0 strong      │
│  LTF │ ▰▰▰▰▰▰▰▰ allow│ ▰▰▰▰▰▰▰▰ allow│ ▰▰▰▰▰▰▰ allow            │
│      ├──────────────┼──────────────┼───────────────────────────┤
│      │ ▰ ▰ ▰ ▰      │ ▰ ▰ ▰ ▰      │ ▰ ▰ ▰ ▰                   │
│      │ (alignment)  │ (alignment)  │ (alignment)               │
├──────┴──────────────┴──────────────┴──────────────────────────┤
│ ◣ REASON CODES · AUDIT LOG                            live     │
│ ┌───────────────────────────────────────────────────────────┐ │
│ │ ● ● ●  structure_guard.audit       tail · 50 · auto-scroll│ │
│ ├───────────────────────────────────────────────────────────┤ │
│ │ ▸ 12:34:51  1h·OB    temp_viol  shadow_low_violated_…    │ │
│ │ ▸ 12:34:51  1h·FVG   near_fill  fvg_nearly_filled · …    │ │
│ │ ▸ 12:34:50  4h·*     intact     htf_alignment_confirmed   │ │
│ └───────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## 4. Component breakdown

All new components live in `macos-app/AlphaLoop/Views/Structure/` as `private struct`s inside `StructureMatrixView.swift` (or split into `StructureMatrixView+Components.swift` if the file grows past ~600 lines).

### 4.1 `StructureMatrixView` (root)

- `@Environment(\.networkClient)`, `@Environment(PulseColors.self)`, `@State var viewModel: StructureMatrixViewModel?`
- Same `.task` lifecycle as today
- Replaces the current `VStack` body with:
  1. `MatrixHeaderBar` (title + symbol picker + state strip)
  2. `ScrollView` containing:
     - `ZoneTowersGrid` (the three towers + TF gutter)
     - `ReasonCodesConsole`

### 4.2 `MatrixHeaderBar`

```swift
private struct MatrixHeaderBar: View {
    let viewModel: StructureMatrixViewModel
    let symbols: [String]
    // header layout: title block | state strip (middle) | controls (right)
}
```

- **Title block**: 36×36 glyph tile + "结构矩阵 / Structure Matrix" + subtitle "多周期一致性裁判 / multi-timeframe consistency referee"
- **State strip**: pulses when `state != "healthy"`. Color depends on state (warning=yellow, violated=red). Text summarizes the highest-severity reason code(s) in human form.
- **Controls**: symbol segmented picker + refresh icon button (no symbol picker grid; one row is enough).

### 4.3 `ZoneTowersGrid`

The structural heart of the page. Lays out:

- A **TF gutter** (fixed 64 pt wide) on the left
- Three **ZoneTower**s on the right (each flexible, equal width, 16 pt gap)

The 3 towers and the TF gutter share the same row-grid layout (header row 64 pt + 4 segment rows of equal height + alignment-bar row 36 pt). We achieve perfect row alignment with a single `Grid` (SwiftUI 5+) — 5 rows × 4 columns (gutter + 3 towers).

```swift
private struct ZoneTowersGrid: View {
    let data: StructureMatrixBFFResponse
    var body: some View {
        let zoneKeys = ["bullish_ob", "fvg", "liquidity_pool"]
        let orderedRows = orderedByTimeframe(data.rows)  // 4h, 1h, 15m, 5m
        Grid(horizontalSpacing: 16, verticalSpacing: 0) {
            // Row 0: gutter spacer + tower headers
            // Row 1..4: gutter TF cell + segment cells
            // Row 5: gutter spacer + alignment indicators
        }
    }
}
```

### 4.4 `TFGutter` rows

- Each row shows `4h / 1h / 15m / 5m`
- Big number in `PulseFonts.displayHeading` (rounded), small unit underneath in `PulseFonts.micro`
- The first and last get an `HTF` / `LTF` tag chip (accent for HTF, info for LTF)
- A vertical line runs through the column behind the labels — 1pt, `border` color, masked with a gradient at top and bottom to fade out. The labels sit on top of the line with a small `bg-0` background to interrupt it (suggests a timeline thread).

### 4.5 `ZoneTowerHeader`

Top cap of each tower (64 pt tall):

```
┌─────────────────────────────────┐
│ ◧  Order Block             3/4 │
│    OB / mitigation zone   align │
└─────────────────────────────────┘
```

- Glyph: monospace display glyph (◧ for OB, ▤ for FVG, ≋ for LP)
- Name in `PulseFonts.headline`
- Subtitle in `PulseFonts.monoLabel` (`text-2`)
- Right side: a summary readout. Default: `"<n>/<total> aligned"`. If the most concerning issue is a single segment, surface it (`"1h · 85% filled"`). One of three states:
  - **All healthy** → accent color, e.g. `"4 / 4 aligned"`
  - **Warning** → warn color, e.g. `"1h · 85% filled"`
  - **Violated** → danger color, e.g. `"1h · temp_viol"`
- Bottom border is 1 pt of `accent-dim` (or warn-dim / danger-dim based on tower state) — subtle but identifies the column at a glance.

### 4.6 `TowerSegmentCell`

The repeating unit (12 instances). Three-column inline layout: `StatRing (40 pt) | SegInfo (flex) | ActionChip (auto)`.

```
┌─────────────────────────────────────────┐
│ │ ⊙ 41  ┊ 1h  shadow_low_violated  [reduce] │  ← warn variant
│ ▲ TEMP                                       │
│ ▰▰▰▱▱                                        │
└─────────────────────────────────────────┘
```

- **Left border 2 pt** colored by status (`accent` healthy, `warn` warning, `danger` violated, `text-3` inactive). Adds a glow (`box-shadow`-equivalent via `.shadow(color: ..., radius: 4)`) on healthy/warn/danger.
- **StatRing**: 40 pt circular progress showing the **most contextually relevant single number** per zone type:
  - OB → `current_strength × 100`
  - FVG → `filled_ratio × 100` (note: filled is what kills FVGs, so this is the more dangerous metric to surface as primary)
  - LP → `current_strength × 100`
  - Ring color follows status; center text is the int value
- **SegInfo** (middle): two stacked lines
  - Row 1: TF label (big, 13 pt rounded semibold) + a short secondary fact (e.g. `strength · 88%`, `filled · 85% · nearly_filled`)
  - Row 2: a 4 pt strength bar (always `current_strength`, regardless of zone type, so the bar means the same thing in every cell)
- **ActionChip** (right): pill — `allow` (accent) / `reduce_size` → "reduce" (warn) / `block_entry` → "block" (danger) / `observe` (info) / blank for `""`
- **Violation overlay**: when `temporary_violation`, a 1 pt warn border pulses (1.4s ease in/out infinite) and a small `▲ TEMP` chip sits at top-right
- **Inactive variant**: 45% opacity, ring grey, action chip outline-only with text "—"
- **Tap**: opens a popover with full details (same content as today's popover — strength %, status, action, all reason codes as chips)

### 4.7 `AlignmentIndicator`

Bottom cap of each tower:

```
┌─────────────────────────────────────────┐
│ alignment       ▰  ▰  ▰  ▰              │
└─────────────────────────────────────────┘
```

- Four small bars (14×5 pt, 3 pt gap) one per timeframe, top-to-bottom matching the segments above
- Each colored: accent (healthy) / warn (warning) / danger (violated) / text-3 (inactive)
- Healthy bars get a subtle glow; warn bars pulse very gently (0.6s opacity 0.6→1.0)
- Acts as a tower "sparkline" — a quick visual summary of the column

### 4.8 `ReasonCodesConsole`

Replaces the current "Shadow Window panel" — same information, much better treatment.

```swift
private struct ReasonCodesConsole: View {
    let entries: [ConsoleEntry]   // derived from data.rows
}

private struct ConsoleEntry {
    let timestamp: Date    // synthesized "now" for current snapshot, real for streamed updates later
    let timeframe: String
    let zoneTag: String    // "OB", "FVG", "LP", "*"
    let severity: Severity // .tempViol, .nearFill, .intact, .recompute, .systemTick
    let codeText: AttributedString  // with highlighted keys
}
```

- **Console chrome**: dot triad (red/yellow/green like macOS window dots) + title `structure_guard.audit` + right-side meta `tail · 50 · auto-scroll on`
- **Body**: each row is a 5-column grid:
  - `▸` prompt (accent)
  - `HH:mm:ss` timestamp (`text-3`)
  - TF chip (`5m·OB` style)
  - Severity tag (uppercase, color-coded)
  - Code text with highlighted reason fragments in warn/accent
- Hover highlights the row (`surface-hi`)
- For the v1 we **derive** entries deterministically from `data.rows` + `data.reason_codes`. Tick/recompute lines are synthesized to give the feed life. When the backend later streams real audit events we replace the derivation with a subscription.

### 4.9 What we delete

- The current `MatrixCellView` (with its overlay popover) — replaced by `TowerSegmentCell`
- The standalone shadow window section (`shadowWindowPanel`) — its information moves into the towers (the violation pulse + reason chip) and the console (audit log row)
- The standalone state banner — folded into the `MatrixHeaderBar`'s state strip

## 5. Visual language

| Token | Value | Use |
|---|---|---|
| Title font | `PulseFonts.displayHeading` (existing, rounded semibold) | Tower & view titles |
| Big numbers | `PulseFonts.tabularLarge` (existing) | TF labels in gutter, ring values |
| Mono labels | `PulseFonts.monoLabel` (existing) | Subtitles, chips, console rows |
| Mono caption | `PulseFonts.micro` (existing) | Unit suffixes, console timestamps |
| Accent (healthy) | `PulseColors.StateColors.green` | Default zone state |
| Warning | `PulseColors.StateColors.amber` (#FFB800) | `temporary_violation`, weakening |
| Danger | `PulseColors.StateColors.red` | `violated` |
| Info | `PulseColors.cyan` | `observe` action, LTF tag |
| Tower bg | `colors.cardBackground` + the existing card modifier | All cards/towers |
| Border | `colors.border` default, `colors.borderHover` on hover | All cards |
| Cell radius | `PulseRadii.md` (10) | Segment cells |
| Tower radius | `PulseRadii.lg` (16) | Tower outer container |

We **do not** introduce new color tokens or new fonts — every state already has a color in `DesignTokens.swift`, and `PulseFonts.tabularLarge` already gives us a 22 pt monospaced digit font.

## 6. Animations

| Event | Animation |
|---|---|
| First load | Towers fade-in + 8 pt rise, staggered 60 ms each (use `staggeredAppearance(index:)`) |
| Segment violation | 1.4 s ease-in-out opacity pulse on border, infinite (`@State pulseOpacity`) |
| Refresh | Existing `PulseAnimation.easeOutMedium` cross-fade |
| Hover on segment | 100 ms ease-out: border `→ borderHover`, bg `→ surfaceHover`, slight 1 pt lift via `.offset(y: -1)` |
| Live state-strip dot | 1.5 s opacity 1.0 → 0.4 infinite |
| Alignment bar (warn) | 0.8 s opacity 0.55 → 1.0 infinite |

## 7. Data flow (unchanged)

```
StructureMatrixView (.task)
        ↓
StructureMatrixViewModel  (existing, unchanged)
        ↓ loadMatrix() / refresh()
APIStructureBFF.getMatrix(symbol:)  (existing, unchanged)
        ↓ /api/structure/matrix?symbol=
backend → StructureMatrixService → MatrixResult
```

**No changes to ViewModel, API service, schema, or backend.** Only the view layer.

## 8. Empty / loading / error states

- **Loading (no prior data)**: existing `LoadingView(type: .grid)` inside the towers area — keep the header visible so symbol/refresh still work
- **Loading (refresh)**: keep towers visible, dim them to 0.7 opacity, show a small spinning indicator in the header
- **Error**: existing `EmptyStateView` with retry button (same as today)
- **No rows** (rare): same empty state, message "暂无结构数据 / No structure data"
- **Inactive cell** (zone type missing for a row): inactive variant of `TowerSegmentCell` (45% opacity, neutral colors)

## 9. Accessibility & i18n

- All chinese strings come from `L10n.Structure.*` (existing keys). We need 5 new keys:
  - `L10n.Structure.consistencyTowers` — "区域一致性矩阵" / "Zone Consistency Towers"
  - `L10n.Structure.aligned` — "对齐" / "aligned"
  - `L10n.Structure.auditLog` — "审计日志" / "Audit Log"
  - `L10n.Structure.htf` — "HTF" (untranslated, technical term)
  - `L10n.Structure.ltf` — "LTF" (untranslated, technical term)
- VoiceOver: each tower has an accessibility label like `"订单块 — 4 周期中 3 个已对齐，1h 出现临时违规"`; each segment cell labels itself with `"<TF> <zone>, 强度 <n>%, 行动 <action>"`

## 10. File / code organization

- Replace `macos-app/AlphaLoop/Views/Structure/StructureMatrixView.swift` entirely (it's a single-file view today, ~470 lines).
- If the new file exceeds ~600 lines, split into:
  - `StructureMatrixView.swift` — root + header + container
  - `StructureMatrixView+Towers.swift` — `ZoneTowersGrid`, `TFGutter`, `ZoneTowerHeader`, `TowerSegmentCell`, `AlignmentIndicator`
  - `StructureMatrixView+Console.swift` — `ReasonCodesConsole`, `ConsoleEntry`, derivation helpers
- All new types are `private struct`s. No types leak out of these files.
- Add localization keys to `macos-app/AlphaLoop/Localization/L10n+Structure.swift`.

## 11. Risks and trade-offs

- **Density vs breathing room**: with 12 tower segments + alignment bars + console, the view height is ~720 pt minimum. Acceptable for the macOS app (window is typically taller). On narrow windows the towers stay readable down to ~280 pt each.
- **Three-column visual rhythm**: works well when all three zone types have data. If the backend ever ships fewer zone types we'd need fallback layout; for now the contract guarantees 3.
- **Animation cost**: violation pulse + alignment-bar gentle pulse + dot pulse. All CSS-equivalent SwiftUI animations using `.repeatForever(autoreverses: true)`. Negligible CPU; no Timeline-based work.
- **Reason-code derivation in console**: the v1 derives entries from the latest snapshot. This is acceptable because the existing page didn't show a real audit feed either; the upgrade is purely visual. The interface is structured so swapping to a real stream is local to the `ConsoleEntry` derivation function.

## 12. Out of scope

- Backend changes
- Wiring the "apply to order form" action (the verdict CTA from direction C is **not** in the B design)
- Real-time push of console events (we derive from snapshot for v1)
- Cross-symbol comparison (current page is single-symbol; future work)
