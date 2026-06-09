# Structure Matrix — HTF Tribunal Redesign

**Date:** 2026-06-10
**Page:** `StructureMatrixView.swift` (multi-timeframe defense page, independent of the 9-step workflow)
**Status:** Approved — ready for implementation
**Supersedes:** `2026-06-10-structure-matrix-column-first-design.md`

---

## Problem

The current `StructureMatrixView` (Column-First implementation) renders a 3-column zone-type tower (Order Block / FVG / Liquidity Pool) cross-cut by a timeframe gutter (5m/15m/1h/4h) and a bottom reason-codes console. It covers basic matrix display + status banner + shadow-window side panel, but is missing roughly half of the features specified in `docs/product/ia_backend_redesign.md` §6.2:

- **No Shadow Window state visualization** (the central concept: countdown to next HTF candle close)
- **No 8-state machine display** (the real `MTFGuardState` has 8 values, not the 5 the previous spec assumed)
- **No Fast Track Health mini bar** — without this, the user cannot tell whether verdicts are trustworthy
- **No Action Recommendation surface** — the verdict (ALLOW / OBSERVE / REQUIRE_CONFIRM / BLOCK_ENTRY / REDUCE_SIZE / IGNORE) is not exposed
- **No StructureDetailDrawer** — clicking a cell does nothing actionable
- **No Hearings timeline** — past MTF guard events are not surfaced

The deeper problem is that the page does not answer the question SMC/ICT traders actually bring to it: *"This break — does it count yet? How long until I know?"* That question is governed by the HTF candle close timer and the Shadow Window state — neither of which is the protagonist in the current design.

## Design Direction

**HTF Tribunal.** Reframe the page as a courtroom where multi-timeframe structural events are tried. Each LTF break is provisional until the HTF candle closes — that interim is the "shadow window," and the page makes the countdown to the verdict the protagonist.

**Aesthetic:** Court Procedural / Editorial. Fraunces serif for chamber titles, JetBrains Mono for prices/countdowns, Inter for body. Dark ground (`#0a0c10`) with paper-grain overlay. Verdict-driven color system: ALLOW=green / WATCH=yellow / REDUCE=orange / BLOCK=red.

**Reading order top-to-bottom:**

1. **Fast Track Health Mini Bar** — latency / data age / Redis status. Tag reads "verdict trustworthy" when green, "verdict suspect" when degraded.
2. **Masthead** — "The Structure Tribunal · chamber of multi-timeframe defense" + date stamp.
3. **Controls** — symbol picker with ⌘K hotkey, TF segmented (5m/15m/1h/4h), refresh.
4. **Tribunal Centerpiece** (3-column):
   - **Left:** 8-state machine vertical rail. Current state pulses; past states are green; future states are dim.
   - **Center:** giant 240px SVG countdown ring — "1h candle closes in 42:11," reads at a glance.
   - **Right:** VERDICT panel — large verdict word (e.g. REDUCE), one-line italic reason, and "Apply to Order Form" CTA.
5. **Evidence Matrix** — 4 TF × 3 zone-type cells. Strength heatmap + filled ratio per cell. Cells in shadow get a diagonal-stripe overlay + "IN SHADOW" badge.
6. **Shadow Windows Panel** — 2-column cards, fast→slow TF pairing, 12-segment candle progress bar, FAST / VIOL / RECLAIM / FILL counts.
7. **Charges & Reasons** — numerals + TF + plain-language narrative + machine `reason_code` chip.
8. **Hearings & Past Rulings** — vertical timeline of past `mtf-guard-events`.
9. **Detail Drawer** — slides in from right when a cell is clicked.
10. **Symbol Picker Sheet** — ⌘K modal with Recent / All Symbols sections.

## Layout

```
┌─────────────────────────────────────────────────────────────────────┐
│ ●  latency 45ms · data 1.2s old · redis ok          [verdict trustworthy] │
├─────────────────────────────────────────────────────────────────────┤
│ THE STRUCTURE TRIBUNAL              2026·06·10                       │
│ chamber of multi-timeframe defense                                   │
├─────────────────────────────────────────────────────────────────────┤
│ [BTC/USDT ⌘K]    [5m|15m|1h|4h]                              ⟳     │
├─────────────────────────────────────────────────────────────────────┤
│ ┌────────────┐  ┌──────────────────┐  ┌──────────────────────────┐ │
│ │ INACTIVE   │  │                  │  │  VERDICT                 │ │
│ │ WATCHING   │  │   ╭──────╮       │  │  REDUCE                  │ │
│ │ PENDING    │  │  │ 42:11 │       │  │  size to 50%             │ │
│ │ ▶ VIOL ◀  │  │  │  1h   │       │  │  "italic reason line"    │ │
│ │ RECLAIM   │  │   ╰──────╯       │  │  [Apply to Order Form]   │ │
│ │ CONFIRMED  │  │ 1h candle closes │  │                          │ │
│ │ INVALID    │  │   in 42:11       │  │                          │ │
│ │ EXPIRED    │  │                  │  │                          │ │
│ └────────────┘  └──────────────────┘  └──────────────────────────┘ │
├─────────────────────────────────────────────────────────────────────┤
│ EVIDENCE MATRIX                                                      │
│         OrderBlock          FVG            LiquidityPool             │
│  4h   ▓▓▓▓▓░░░ 64%      ▓▓░░░░░░ 18%    ▓▓▓░░░░░ 31%               │
│  1h  [▓░░░░░░░ IN SHADOW]▓▓▓▓░░░░ 50%   ▓▓▓▓▓▓░░ 71%               │
│ 15m   ▓▓░░░░░░ 22%      ▓▓▓▓░░░░ 48%    ▓▓▓░░░░░ 38%               │
│  5m   ▓░░░░░░░  9%      ▓▓░░░░░░ 25%    ▓▓░░░░░░ 21%               │
├─────────────────────────────────────────────────────────────────────┤
│ SHADOW WINDOWS                                                       │
│ ┌─ 15m → 1h ──────────────┐  ┌─ 5m → 15m ──────────────────────┐   │
│ │ OB · short · in shadow  │  │ FVG · long · reclaim_pending    │   │
│ │ FAST 8 · VIOL 2 · RECLAIM 0 · FILL 0.34   │ FAST 11 · ...    │   │
│ │ ▓▓▓▓▓▓▓▓░░░░ candles    │  │ ▓▓▓▓▓▓▓▓▓▓▓░ candles            │   │
│ └─────────────────────────┘  └────────────────────────────────┘    │
├─────────────────────────────────────────────────────────────────────┤
│ CHARGES & REASONS                                                    │
│  i. 1h  "price slipped below 1h Order Block bottom by 0.4%"          │
│         [reason_code: TEMPORARY_VIOLATION]                           │
│  ii. 5m "left an FVG unfilled in the impulse"                        │
│         [reason_code: FVG_UNFILLED]                                  │
├─────────────────────────────────────────────────────────────────────┤
│ HEARINGS & PAST RULINGS                                              │
│  09:42  CHoCH confirmed on 1h     → ALLOW                            │
│  08:15  Sweep on 4h               → OBSERVE                          │
│  07:30  Premium zone tagged       → REQUIRE_CONFIRM                  │
└─────────────────────────────────────────────────────────────────────┘
```

## Components (Swift)

All components live in `Views/Structure/StructureMatrixView.swift`. No new files unless a component grows past ~80 lines — in which case it gets its own file under `Views/Structure/`.

| Component | Responsibility |
|---|---|
| `FastTrackHealthMiniBar` | Top status bar: latency / data age / Redis state + verdict-trustworthy tag |
| `TribunalMasthead` | Editorial header: serif title + date stamp |
| `TribunalControls` | Symbol button (⌘K), TF segmented control, refresh |
| `SymbolPickerSheet` | Modal with search, Recent (UserDefaults), All Symbols |
| `TribunalCenterpiece` | 3-col layout: state rail + countdown ring + verdict panel |
| `StateMachineRail` | Vertical list of 8 `MTFGuardState` values; current pulses, past=green, future=dim |
| `HTFCountdownRing` | 240px SVG-equivalent (Canvas/Path) ring with mm:ss text and TF tag |
| `VerdictPanel` | Verdict word, italic reason line, "Apply to Order Form" button |
| `EvidenceMatrix` | 4 TF × 3 zone-type grid of `EvidenceCell`s |
| `EvidenceCell` | Strength heatmap bar + filled ratio %; in-shadow cells get diagonal-stripe overlay + badge |
| `ShadowWindowsPanel` | 2-col grid of `ShadowWindowCard`s |
| `ShadowWindowCard` | TF pairing header, zone meta, FAST/VIOL/RECLAIM/FILL counts, 12-segment candle progress |
| `ChargesPanel` | Numbered list of reason rows with TF + narrative + reason_code chip |
| `HearingsTimeline` | Vertical timeline of past mtf-guard events |
| `StructureDetailDrawer` | Right-slide drawer showing full cell detail on tap |

## Data Contract

The redesign needs more data than the current `/api/structure/matrix` endpoint provides. The view contract is extended (additive only — matrix endpoint stays unchanged):

**Existing (unchanged):**
- `GET /api/structure/matrix?symbol=` → `StructureMatrixBFFResponse` (4 TF × 3 zone-type cells with strength / filled_ratio / temporary_violation / action / reason_codes)

**New endpoints to wire up:**
- `GET /api/structure/shadow-windows?symbol=` → `[ShadowWindowSnapshot]`
- `GET /api/structure/mtf-guard/{strategy_id}/{symbol}` → current `MTFGuardState` + verdict + countdown_seconds_to_htf_close
- `GET /api/structure/mtf-guard-events/{strategy_id}` → `[MTFGuardEvent]` (history for Hearings timeline)
- `GET /api/system/fast-track-health` → `{ latency_ms, data_age_seconds, redis_ok }` (or reuse existing health endpoint)

All four endpoints already exist on the backend per `backend/app/routers/structure_bff.py`. The Swift work is purely adding the corresponding `APIStructureBFF` methods + mock data.

## ViewModel

`StructureMatrixViewModel` is extended to fetch all four endpoints in parallel inside `loadMatrix()`:

```swift
@Observable @MainActor
final class StructureMatrixViewModel {
    var matrixData: StructureMatrixBFFResponse?
    var shadowWindows: [ShadowWindowSnapshot] = []
    var mtfGuard: MTFGuardSnapshot?
    var guardEvents: [MTFGuardEvent] = []
    var fastTrackHealth: FastTrackHealth?
    var selectedSymbol = "BTC/USDT"
    var selectedTimeframe: String = "1h"
    var isLoading = false
    var error: String?

    func loadAll() async {
        async let m = api.getMatrix(symbol: selectedSymbol)
        async let s = api.getShadowWindows(symbol: selectedSymbol)
        async let g = api.getMTFGuard(strategyId: "default", symbol: selectedSymbol)
        async let e = api.getMTFGuardEvents(strategyId: "default")
        async let h = api.getFastTrackHealth()
        // assign + handle errors
    }
}
```

A countdown `Timer` ticks once per second while the view is visible to drive `HTFCountdownRing` without re-fetching.

## Symbol Picker

Same UX as the MarketStructureView picker:
- Button shows current symbol + `⌘K` kbd hint
- Activation: click or ⌘K
- Search field + Recent (last 3, `UserDefaults`) + All Symbols
- Source: hardcoded `["BTC/USDT", "ETH/USDT", "SOL/USDT", "AVAX/USDT", "LINK/USDT", "ARB/USDT"]` for now; replace with `/api/symbols` in a follow-up

## Design Tokens

Reuse only — no new tokens.

- Backgrounds, cards, borders: `PulseColors.background*`, `PulseColors.cardBackground`, `PulseColors.border`, `PulseGlass`
- Verdict colors: green=`PulseColors.accent`, yellow=`PulseColors.StateColors.yellow`, orange=`PulseColors.StateColors.orange`, red=`PulseColors.StateColors.red`
- Shadow overlay: low-opacity red diagonal stripes
- Type ramp: `PulseFonts.displayHeading` (masthead), `PulseFonts.headline` (chapter titles), `PulseFonts.tabularLarge` (countdown, verdict word, prices), `PulseFonts.monoLabel` (reason codes), `PulseFonts.caption` (subtitles), `PulseFonts.body.italic()` (narrative lines)
- Spacing: `PulseSpacing.xl` between sections, `PulseSpacing.lg` inside sections, `PulseSpacing.md` between rows
- Radii: `PulseRadii.card` for section wrappers, `PulseRadii.md` for inner cards

## Animations

- Page entrance: stagger fade-up on sections (50ms step, 250ms duration each)
- Countdown ring: smooth angular drain, no jitter
- Current state pulse: 1.5s opacity oscillation
- Evidence cell hover: subtle border lift
- Drawer: spring slide-in from right

## Out of Scope

- Backend `/api/symbols` endpoint
- The "Apply to Order Form" button only emits a notification — order form wiring lives elsewhere
- Real-time WebSocket updates (still 5s polling driven by VM)
- Multi-symbol cross-comparison
