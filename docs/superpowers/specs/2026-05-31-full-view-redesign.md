# Full View Redesign — All Pages Audit & Optimization

**Date**: 2026-05-31
**Status**: Approved
**Scope**: 60+ SwiftUI views across 10+ modules in PulseDesk macOS app

## Design Decisions (User-Selected)

| Decision | Choice |
|----------|--------|
| Card system | Adaptive Hybrid — `.subtle` default, upgrades to glow on hover |
| Press feedback | Combined — scale(0.98) + brightness for cards, brightness-only for rows |
| Loading states | Hybrid — skeleton on first load, pulse dot on polling refresh |
| Empty states | Illustrative style (keep current), elevate quality: 120pt min height, entrance animation, secondary action support |
| Batch order | A (Design System) → B (Shell) → C (Data Pages) → D (AI Studio + Canvas) |

---

## Batch A: Design System Fixes (~8 files)

Foundation changes that cascade to ALL views.

### A1. Unified Card Component (`ProofAlphaCard`)

Merge `DepthCard` + `GlassCard` + `SpotlightCard` in `ProofAlphaComponents.swift` into a single component with `emphasis` parameter:

```swift
ProofAlphaCard(emphasis: .subtle)   // low transparency, no glow, no tilt
ProofAlphaCard(emphasis: .balanced) // medium transparency, hover glow, no tilt
ProofAlphaCard(emphasis: .bold)     // high transparency, accent border, 3D tilt + spotlight
```

**Fixes:**
- 3D tilt: replace `NSApp.windows.first!.frame.size` with `GeometryReader` local coordinates — each card tilts independently
- Spotlight: center tracks cursor position dynamically (fixes static `(0.5, 0.5)`)
- Remove ~80% code duplication between DepthCard/GlassCard
- `ProofAlphaButton` add disabled state visual (reduced opacity, no press/hover effects)

**Usage by module:**
- Dashboard, Trades, Backtest → `.subtle`
- Strategies, Settings, Risk → `.balanced`
- Landing, AI Studio → `.bold`

### A2. Unified Loading Component (`LoadingView`)

Replace ad-hoc `ProgressView("加载中...")` with typed skeleton system in `LoadingView.swift`:

```swift
LoadingView(type: .dashboard) // KPI row + chart + two-column
LoadingView(type: .listRow)   // Row-level skeleton
LoadingView(type: .detail)    // Detail page skeleton
LoadingView(type: .grid)      // Grid skeleton
LoadingView(type: .inline)    // Thin progress bar for polling refresh
```

**Rules:**
- First load → skeleton with staggered shimmer (phase offset = index * 0.15s)
- Background polling → green pulse dot near section title (no skeleton flash)
- Form submission → `ProgressView()` inside button + disabled state

### A3. EmptyStateView Refinements

- Minimum height: 80pt → 120pt
- Float animation: `easeInOut` → `.spring(response: 2.0, dampingFraction: 0.3)`
- Icon weight: `.light` → `.regular`, opacity: `0.5` → `0.6`
- Entrance: `.transition(.scale.combined(with: .opacity))`
- Add `secondaryAction: (label: String, action: () -> Void)?` parameter

### A4. Micro-Interaction Infrastructure

- `PressEffectModifier`: replace `DragGesture(minimumDistance: 0)` with `TapGesture` + `simultaneousGesture` — fixes ScrollView conflict
- `HoverEffectModifier`: default scale 1.01 → 1.03
- Add `staggeredAppearance` to ALL lists and grids currently missing it

### A5. Theme Bug Fixes

- Add `var loss: Color` instance property to `PulseColors` (responds to theme toggle)
- Replace all `PulseColors.loss` static references with `colors.loss`
- Replace hardcoded `spacing: 8` with `PulseSpacing.xs` in DashboardView KPI row
- Replace hardcoded `.font(.system(size: 48, ...))` in LandingView with `PulseFonts` token

### A6. Code Cleanup

- Delete `ToolbarView.swift` (duplicate of AppShell's `ConsoleToolbar`)
- Replace inline `PulseRing` code in `LandingView` with shared `PulseRing()` component
- Extract shared `NavRowView` from `SidebarButtonView` + `SettingsNavRowView` duplication

---

## Batch B: Shell + Navigation (~12 views)

### B1. AppShellView
- Replace `ProgressView("加载中...")` → `LoadingView(type: .detail)`
- Toolbar icon buttons: add `.help()` + hover opacity/scale transition
- Notification badge offset: replace hardcoded `(5, -5)` with proportional value

### B2. SidebarView
- Merge accent indicator bar (3px, 16pt) into glass selection background as single gradient highlight
- Footer status text: wire to `SystemStatus` ViewModel instead of hardcoded strings
- Collapsed mode: emit single `Divider()` after section loop, not per-section
- Replace `Spacer().frame(height: 30)` with `.padding(.top, 30)` on logo header

### B3. ToolbarView → DELETE
- All logic already in AppShell's `ConsoleToolbar`

### B4. CommandPaletteView
- Empty results: add "No results found" state
- Routes section: add "页面" header matching Strategies "策略" pattern
- Keyboard nav: `ScrollViewReader` + `scrollTo(selectedIndex)`
- Entrance: `.transition(.scale(scale: 0.95).combined(with: .opacity))`
- Loading indicator during 300ms debounce
- Extract shared `CommandPaletteRow` from duplicate `resultRow`/`strategyRow`

### B5. SettingsView
- Extract shared `NavRowView` from `SidebarButtonView`
- Add `hasUnsavedChanges` indicator (accent dot)
- `Command+[1-6]` keyboard shortcuts for section nav

### B6. Settings Sub-pages
- **APISettingsView**: rows → tappable cards with chevron; add edit sheet per provider; use `TerminalLabel` for heading
- **RiskSettingsView**: add validation (out-of-range → accent border + warning text); group params with dividers; range fields → `Slider` + label; "恢复默认" button
- **ProfileSettingsView**: make fields editable; add avatar picker; add timezone/2FA fields
- **NotificationSettingsView / ExchangeSettingsView / DangerZoneView**: replace hardcoded fonts with `PulseFonts` tokens

---

## Batch C: Core Data Pages (~20 views)

### C1. DashboardView
- Add error state when `kpis == nil && !isLoading`
- DataSourceBadge: wrap in own HStack row (no floating Spacer)
- KPI skeleton: phase offset = `index * 0.3` for wave effect
- Polling indicator: green `PulsingDot` near title

### C2. KPICardView
- `PulseColors.loss` → `colors.loss` (theme-responsive)
- Trend label: delayed staggered entrance after main value
- Value text: subtle glow shadow on hover (0.1s fade)

### C3. EquityCurveChart
- Hover tooltip: floating label showing formatted date + value
- Point lookup: index-based `firstIndex(where:)` instead of string match
- Range buttons: apply `pressEffect`
- Use `SpotlightCard` (no 3D tilt but with spotlight) instead of `GlassCard(enable3D: false)`

### C4. CorrelationHeatmapView
- Wrap in `GlassCard` for visual consistency
- Fixed cell width (`minWidth: 44`)
- Color legend gradient bar (-1.0 red → 0 neutral → 1.0 green)
- Self-correlation diagonal: distinct style (white text, no fill)
- Symbol prefix: 4 → 6 characters, or smart truncation

### C5. PositionsListView
- Row spacing: 1pt → 3pt, or 1px divider at 0.06 opacity
- Amount formatting: `.stripTrailingZeros` (not `%.4f`)
- Add PnL percentage next to absolute PnL
- Empty state height: 80pt → 120pt

### C6. RecentTradesListView
- Add `staggeredAppearance(index:)` matching positions
- Direction badges: use same style as PositionsListView
- Row hover: subtle `surfaceHover` background change
- Add order type icon (market/limit) next to direction badge

### C7. ActivityFeedView
- Severity bar: height-fill entrance animation
- Row hover: `borderHover` overlay
- Add severity labels (警告/严重/信息) or legend

### C8. BacktestView
- State transitions: `.transition(.opacity.combined(with: .move(edge: .bottom)))`
- Remove fixed 300pt height → `minHeight`
- History rows: add `staggeredAppearance`

### C9. BacktestConfigView
- Symbol buttons: add `pressEffect(scale: 0.92)`
- Strategy selector: add compact summary label of current selection

### C10. BacktestResultsView
- Metric grid: add `staggeredAppearance` with staggered delay
- Trade list: add dividers between rows + column headers matching OrdersTableView
- Add hover effect to metric cards

### C11. RiskView
- Icons: replace hardcoded `.font(.system(size: 20))` → `PulseFonts`
- Event rows: add hover + `staggeredAppearance`
- Divider between stats section and events section

### C12. SentimentView + FearGreedGauge
- Sentiment bars: `GeometryReader` relative width instead of fixed `CGFloat(value) * 100`
- Analysis button: show `ProgressView` during loading
- Scale labels: `frame(width: 140)` matching gauge width
- Center value color: animate with gauge color change

### C13. TradesView
- Tab underline: add 4pt spacing above (currently flush with text)
- Filter bar: move OUT of `if isLoading` guard (show filtering context during load)
- Count badges: `.transition(.opacity)` animation
- Filter text field: replace `.roundedBorder` with dark theme style

### C14. OrdersTableView / PositionsTableView
- Alternating row backgrounds: `index % 2 == 0 ? colors.surface.opacity(0.5) : .clear`
- Fix `layoutPriority` anti-pattern: use raw column weight values, not fractions
- Wrap in horizontal scroll at narrow widths
- Format PnL with proper decimal places

---

## Batch D: AI Studio + Canvas (~18 views)

### D1. AIStudioView
- Tab buttons: add `pressEffect(scale: 0.95)`
- Tab transition: `.move(edge: .trailing).combined(with: .opacity)` instead of `.opacity` only

### D2. Six AI Section Panels
- **All**: unify search/text field border styles (currently inconsistent across sections)
- **ResearchSectionView**: remove fixed sheet size → `.presentationSizing(.fitted)`, remove nested `.cardStyle()` inside scroll
- **SignalsSectionView**: search field add bottom border overlay; KPI row → adaptive grid; expandable truncated signal text
- **FactorResearchSectionView**: add loading state during `isRunning`; results grid → vertical `LazyVGrid`; error banner animate entrance
- **FreqAISectionView**: un-crowd config bar with `Divider` grouping; training history alternating row backgrounds; submit button `ProgressView`
- **ForecastSectionView**: chart add minimal axis labels; replace hardcoded model info with API data; chart area fade-in animation
- **RAGLabSectionView**: align structure to match other sections (remove standalone TerminalLabel header); add `maxHeight` on TextEditor; code blocks `.monospaced()` font

### D3. Canvas Node System
- **NodeView**: port circles 10pt → 12pt (+ invisible 6pt hit area); slider add current value label; disabled nodes add desaturation; title drag add `minimumDistance`
- **NodePalette**: add search clear button; hide empty categories when searching; port count badge contrast fix
- **NodeConfigPanel**: fix `.onChange(of: node.id)` to refresh nameText/notesText; delete add `.confirmationDialog`; merge gray levels (2 tiers max instead of 3)
- **GroupBoxView**: replace hardcoded 10/30/50 offsets with `PulseSpacing` constants; animate bounds changes; hide when empty
- **MiniMapView / CanvasBackground / CanvasEdges**: wrap in `staggeredAppearance`, consistent token usage

---

## Cross-Cutting Rules (Apply to ALL Views)

1. **Every interactive row** gets hover effect + press feedback
2. **Every list/grid** gets `staggeredAppearance` (stagger delay: `PulseAnimation.staggerDelay`)
3. **Every state transition** (loading→data, empty→data, error→data) gets `.transition(.opacity)` or equivalent
4. **No hardcoded** spacing, font sizes, or colors — always use `PulseSpacing`, `PulseFonts`, `PulseColors`
5. **No nested `cardStyle()`** inside `cardStyle()` — one level of card background per hierarchy level
6. **Every delete/destructive action** gets `.confirmationDialog`

---

## Implementation Order

```
Batch A (Design System) → Batch B (Shell) → Batch C (Data Pages) → Batch D (AI Studio + Canvas)
```

Batch A is the critical path — all other batches depend on the unified card, loading, and micro-interaction primitives.
