# Market Structure — Causal Storyboard Redesign

**Date:** 2026-06-10
**Page:** `MarketStructureView.swift` (SMC research panel, independent of the 9-step workflow)
**Status:** Approved — ready for implementation

---

## Problem

The current `MarketStructureView` displays the SMC analysis output as four parallel sections (summary metrics row → zones grid → liquidity pools strip → events timeline). Each section is technically correct but the page reads as a dashboard of disconnected facts. The viewer has to mentally re-assemble the causal chain that the backend engine (`backend/app/services/structure/engine.py`, the 9-step pipeline `regime → swing → liquidity pool → sweep → FVG → order block → BOS/CHoCH → lifecycle → entry score`) actually computes.

For an SMC/ICT trader the most valuable thing the engine produces is **the story of what just happened to price and what is therefore active now** — not the inventory of zones.

A first attempt (Price Ladder mockup) failed because it tried to put every artifact on a single vertical price axis; the result was visually overloaded.

## Design Direction

**Causal Storyboard.** The page is rewritten as a short narrative in four chapters, read top-to-bottom, each titled with a Roman numeral and an italic Instrument Serif "pose" line that names the question that chapter answers.

- **I. CONTEXT** — *"what kind of market are we in?"* — regime + structure score + premium/discount + active inventory count.
- **II. HOW WE GOT HERE** — *"recent structural events, oldest first"* — vertical thread connecting events (Sweep → BoS → FVG Fill) with causal arrows and one-line italic narrative under each.
- **III. WHAT'S ACTIVE NOW** — *"zones price has yet to fully react to · ranked by distance"* — 2-column zone cards sorted by absolute distance from current price, each card leads with a large distance-from-now headline.
- **IV. LIQUIDITY POOLS** — *"where stops cluster — magnets for price"* — compact one-row-per-pool list.

A reserved `future-slot` (dashed placeholder) sits between Chapter II and III for the eventual price sparkline overlay (deferred).

## Layout

```
┌────────────────────────────────────────────────────────────────┐
│ α  Market Structure   SMC RESEARCH    [BTC/USDT ⌘K] [5m|15m|1h|4h] ⟳ │
├────────────────────────────────────────────────────────────────┤
│ I. CONTEXT — what kind of market are we in?                    │
│    TRENDING     │  Score 76/100 ▓▓▓▓▓▓▓░░░  │  PREMIUM  │ 4z·3p │
│    "narrative line in italic explains the regime"              │
├────────────────────────────────────────────────────────────────┤
│ II. HOW WE GOT HERE — recent events, oldest first              │
│    ● Sweep 60200 ▲                                              │
│      "swept buy-side liquidity above prior swing"               │
│      ↓                                                          │
│    ● BoS 62100 ▲                                                │
│      "broke prior swing high — confirms bullish CHoCH"          │
│      ↓                                                          │
│    ● FVG Fill 61600                                             │
│      "filled imbalance left by the impulse leg"                 │
│                                                                 │
│    [ ─ ─ future: price sparkline ─ ─ ]                          │
├────────────────────────────────────────────────────────────────┤
│ III. WHAT'S ACTIVE NOW — ranked by distance                    │
│   ┌──────────────────────┐ ┌──────────────────────┐            │
│   │ −0.34% BELOW NOW     │ │ +0.81% ABOVE NOW     │            │
│   │ DEMAND · 1h          │ │ FVG · 15m            │            │
│   │ italic narrative     │ │ italic narrative     │            │
│   │ strength ▓▓▓▓░░ 67%  │ │ strength ▓▓▓░░░ 52%  │            │
│   │ mitigation ▓▓░░ 22%  │ │ mitigation ░░░░  8%  │            │
│   └──────────────────────┘ └──────────────────────┘            │
├────────────────────────────────────────────────────────────────┤
│ IV. LIQUIDITY POOLS — magnets for price                        │
│   ▲  62 800   "equal highs · buy-side"     ×3   ▓▓▓▓░ 71%     │
│   ▼  60 100   "equal lows · sell-side"     ×4   ▓▓▓░░ 58%     │
└────────────────────────────────────────────────────────────────┘
```

## Components (Swift)

All components live in `Views/Structure/MarketStructureView.swift`. No new files unless a component grows past ~80 lines.

| Component | Responsibility |
|---|---|
| `MarketStructureHeader` | α glyph, title, role tag, symbol button, TF picker, refresh |
| `SymbolPickerSheet` | Modal sheet with search field, Recent list, All Symbols list, ⌘K hotkey |
| `ContextChapter` | Chapter I — regime word + narrative + 3 meters |
| `RegimeMeter` | Vertical bar visualization of structure score (0–100) |
| `PremiumDiscountPill` | Colored pill for premium/discount/equilibrium |
| `EventThreadChapter` | Chapter II — vertical thread of `EventThreadRow`s with `↓` connector |
| `EventThreadRow` | Single event: dot + type + price + italic narrative line |
| `FutureSlotPlaceholder` | Dashed placeholder reserving space for future sparkline |
| `ActiveZonesChapter` | Chapter III — 2-col grid of `ZoneStoryCard` sorted by distance |
| `ZoneStoryCard` | Distance-from-now lede + type/TF subtitle + narrative + strength + mitigation |
| `LiquidityPoolsChapter` | Chapter IV — vertical list of `PoolStoryRow`s |
| `PoolStoryRow` | Direction icon + price + narrative + touch count + strength bar |

## Data Contract — Unchanged

This redesign is **view-only**. It MUST NOT change:

- `MarketStructureViewModel` (`ViewModels/MarketStructureViewModel.swift`)
- `APIMarketStructure` and its response types (`Services/APIMarketStructure.swift`)
- Backend `/api/structure/market-view` BFF endpoint

Sorting (zones by `|distance from current price|`, events by timestamp ascending) is done in the view layer using existing fields. Narrative strings are derived in the view from `reasonCodes` + `zoneType` + `direction` (a small `NarrativeBuilder` helper inside the view file).

## Symbol Picker

- Trigger: button in header showing current symbol + `⌘K` kbd hint
- Activation: click or `⌘K` keyboard shortcut
- Content: search field at top, "Recent" section (last 3 used, persisted in `UserDefaults`), "All Symbols" section
- Symbol source: existing hardcoded `["BTC/USDT", "ETH/USDT", "SOL/USDT", "AVAX/USDT", "LINK/USDT", "ARB/USDT"]` array in view file. A follow-up will replace this with a `/api/symbols` backend call — out of scope for this spec.
- Dismiss: ESC, click outside, or selection

## Design Tokens

Reuse only — no new tokens.

- Backgrounds, cards, borders: `PulseColors.background*`, `PulseGlass`
- State colors: `PulseColors.accent` (bullish demand zones), `PulseColors.StateColors.red` (bearish supply), `PulseColors.cyan` (FVG), `PulseColors.purple` (liquidity)
- Type ramp: `PulseFonts.displayHeading` (chapter numerals), `PulseFonts.headline` (chapter titles), `PulseFonts.tabularLarge` (distance lede, prices), `PulseFonts.caption` (subtitles), `PulseFonts.body.italic()` (narrative lines)
- Spacing: `PulseSpacing.xl` between chapters, `PulseSpacing.lg` inside chapters, `PulseSpacing.md` between rows
- Radii: `PulseRadii.card` for chapter wrappers, `PulseRadii.md` for cards inside

## Animations

- Page entrance: stagger fade-up on chapters (50ms step, 250ms duration each)
- Zone card hover: subtle border lift + shadow
- Refresh: rotate icon while loading
- No animation on sub-components — chapter-level stagger only

## Out of Scope

- Backend `/api/symbols` endpoint
- Price sparkline in the future-slot (placeholder reserved only)
- Multi-symbol comparison
- Persisting the popup state across app launches beyond Recent symbols
