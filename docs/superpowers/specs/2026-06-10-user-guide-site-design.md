# AlphaLoop User Guide — Static HTML Site

**Date:** 2026-06-10
**Target:** `docs/user-guide/` (static site) + macOS app integration points
**Status:** Approved — ready for implementation

---

## Problem

AlphaLoop now has 25 pages across 8 sidebar groups (`AppRoute` enum). Each page mixes SMC/ICT trading vocabulary (Order Block, FVG, BOS, CHoCH, Shadow Window, HTF), AI quant concepts (research agents, signal fusion, FinBERT sentiment), and operational machinery (Freqtrade dry-run, circuit breakers, reconciliation bus). A first-time user — even a competent trader — has no map. The existing `docs/` tree serves architects, not users.

We need a beginner-friendly **user guide** that:

1. Explains the underlying trading and AI concepts from zero, with authoritative external citations.
2. Documents every one of the 25 pages: what it solves, what's on it, how to read each number, what to click.
3. Stitches pages into real end-to-end workflows so users learn the *flow*, not just isolated screens.
4. Looks like it belongs to AlphaLoop — same dark cyberpunk + Liquid Glass treatment.
5. Is reachable from inside the app with one click.

## Design Direction

A single static HTML site at `docs/user-guide/index.html`, double-clickable, zero build step, zero external dependencies. Visual style is a 1:1 port of AlphaLoop's design tokens into CSS variables so the guide feels native when launched from the sidebar.

The content is split into **three sections**, each with a distinct purpose:

- **Concepts** — pure conceptual primer ("what is an Order Block, and why does it matter?"). 10 chapters. Heavy on SVG diagrams and pull-quote citations.
- **Pages** — one chapter per page in the app (25 total), grouped by the 8 sidebar sections. Strictly structured so users know where to look.
- **Walkthroughs** — 5 end-to-end scenarios ("from zero to first strategy live," "a daily trading loop," "how to use the HTF Tribunal to decide an entry"). These weave pages together.

Integration into the app is two-pronged:

- A persistent **sidebar entry** ("用户指南 / User Guide") at the bottom of `AppShellView`'s sidebar, above settings.
- A dismissible **Dashboard top card** (`LearnAlphaLoopCard`) with three deep-link chips for first-run discovery.

Both open `docs/user-guide/index.html` via `NSWorkspace.shared.open(_:)`.

## Layout

```
┌────────────────────────────────────────────────────────────────────────────┐
│  [α  AlphaLoop Guide]                              [zh ◍ en]    ⌘K search  │
├──────────────┬─────────────────────────────────────────────────────────────┤
│  CONCEPTS    │  ╔════════════════════════════════════════════════════════╗ │
│   What is …  │  ║  Order Blocks                              03 / 10     ║ │
│   SMC/ICT    │  ║  ─────────────────────────────────────────────────────  ║ │
│ ▸ Order …    │  ║                                                         ║ │
│   FVG        │  ║   "An Order Block is a significant price area where     ║ │
│   Liquidity  │  ║    institutional traders have placed orders."           ║ │
│   MTF        │  ║                                       — TradeThePool    ║ │
│   Risk       │  ║                                                         ║ │
│   Dryrun     │  ║   [ SVG diagram — bearish OB on a candle chart ]        ║ │
│   AI Roles   │  ║                                                         ║ │
│              │  ║   Why it matters …                                      ║ │
│  PAGES       │  ║   How to spot one …                                     ║ │
│   OVERVIEW   │  ║   How it shows up in AlphaLoop …                        ║ │
│   STRATEGY   │  ║     → Market Structure page                             ║ │
│   STRUCTURE  │  ║     → Structure Matrix · HTF Tribunal                   ║ │
│   …          │  ║                                                         ║ │
│              │  ║   Sources                                               ║ │
│  WALKTHRU    │  ║     1. TradeThePool — SMC Terminology                   ║ │
│   First Strat│  ║     2. DailyPriceAction — SMC Definitive Guide          ║ │
│   Daily Loop │  ╚════════════════════════════════════════════════════════╝ │
│   HTF Tribl  │                                                              │
│   Risk Inc.  │  ◀  prev: SMC/ICT Overview        next: Fair Value Gap  ▶   │
│   Improve    │                                                              │
└──────────────┴─────────────────────────────────────────────────────────────┘
```

## Site Structure

```
docs/user-guide/
├── index.html                  # shell: header, sidebar, <main>, footer
├── assets/
│   ├── styles.css              # CSS variables port of PulseColors/Fonts/Spacing
│   ├── app.js                  # hash router, fetch + inject, search, lang toggle
│   ├── search-index.json       # title + keyword index (~150 entries)
│   └── fonts/
│       ├── Fraunces-Variable.woff2
│       ├── JetBrainsMono-Variable.woff2
│       └── Inter-Variable.woff2
└── content/
    ├── welcome.html
    ├── concepts/
    │   ├── 01-what-is-quant.html
    │   ├── 02-smc-ict.html
    │   ├── 03-market-structure.html
    │   ├── 04-order-block.html
    │   ├── 05-fair-value-gap.html
    │   ├── 06-liquidity.html
    │   ├── 07-multi-timeframe.html
    │   ├── 08-risk-basics.html
    │   ├── 09-dryrun-vs-live.html
    │   └── 10-ai-roles.html
    ├── pages/
    │   ├── overview/
    │   │   ├── dashboard.html
    │   │   └── live-readiness.html
    │   ├── strategy/
    │   │   ├── strategy-workspace.html
    │   │   ├── strategy-canvas.html
    │   │   └── backtest-simulation.html
    │   ├── structure/
    │   │   ├── market-structure.html
    │   │   ├── structure-matrix.html
    │   │   └── manipulation-radar.html
    │   ├── execution/
    │   │   ├── execution-center.html
    │   │   ├── orders-positions.html
    │   │   └── reconciliation-bus.html
    │   ├── risk/
    │   │   ├── risk-center.html
    │   │   ├── stop-protection.html
    │   │   └── circuit-breakers.html
    │   ├── ai-research/
    │   │   ├── ai-research-room.html
    │   │   ├── agent-platform.html
    │   │   ├── signal-center.html
    │   │   └── market-sentiment.html
    │   ├── growth/
    │   │   ├── growth-review.html
    │   │   ├── failure-clustering.html
    │   │   └── strategy-optimization.html
    │   └── system/
    │       ├── service-management.html
    │       ├── data-source-management.html
    │       └── settings.html
    └── walkthroughs/
        ├── first-strategy.html
        ├── daily-trading-loop.html
        ├── htf-tribunal-flow.html
        ├── risk-incident.html
        └── improve-strategy.html
```

Bilingual: every content file has a `_zh.html` and `_en.html` sibling (or front-of-file `data-lang` blocks — see Implementation Notes). MVP ships **both languages** per user requirement. Language toggle is a header button, persisted in `localStorage`.

## Content Specification

### Part I · Concepts (10 chapters)

Each chapter is one HTML partial, 400–800 zh-chars, opens with:

1. **One-line definition** in a `<blockquote class="lede">`
2. **Cited pull quote** from external authority
3. **SVG diagram** (inline `<svg>`, no external images) illustrating the concept on a stylized candle chart
4. **Body** — why it matters, how to spot it, common gotchas
5. **"In AlphaLoop"** — deep links to the page chapters where this concept surfaces
6. **Sources** — numbered list of external citations

| # | Chapter | Key citations |
|---|---|---|
| 01 | What Is Quant Trading | (internal — no external cite required) |
| 02 | SMC / ICT in 5 Minutes | [TradeThePool — SMC Terminology](https://tradethepool.com/technical-skill/smart-money-concepts-terminology), [DailyPriceAction — SMC Definitive Guide](https://dailypriceaction.com/blog/smart-money-concepts) |
| 03 | Market Structure: Trend, BOS, CHoCH | [FluxCharts — BOS Explained](https://www.fluxcharts.com/articles/break-of-structure-bos-explained), [LuxAlgo — MSS in ICT](https://www.luxalgo.com/blog/market-structure-shifts-mss-in-ict-trading) |
| 04 | Order Blocks | TradeThePool, DailyPriceAction |
| 05 | Fair Value Gaps (FVG) | DailyPriceAction |
| 06 | Liquidity Pools, Sweeps, Buy/Sell-Side | DailyPriceAction |
| 07 | Multi-Timeframe Analysis & the Shadow Window | [TradingStrategyGuides — MTF Top-Down](https://tradingstrategyguides.com/day-10-multi-timeframe-analysis-ict-smc-the-top-down-approach-explained) |
| 08 | Risk Basics: Position Size, Stop Loss, Drawdown, Circuit Breakers | (internal) |
| 09 | Backtest vs Dry-Run vs Live | [Freqtrade Backtesting docs](https://www.freqtrade.io/en/2023.8/backtesting) |
| 10 | AI Roles in AlphaLoop: Research, Generation, Fusion, Sentiment | (internal) |

### Part II · Pages (25 chapters)

Every page chapter follows the **same 7-section template** so users know exactly where to look:

1. **TL;DR** — one sentence: what problem this page solves
2. **Who uses it & when** — the user scenario
3. **Page anatomy** — annotated SVG mockup of the page with numbered callouts (1️⃣ 2️⃣ 3️⃣ …)
4. **Read the key metrics** — paragraph per metric: what it means, what's good/bad, what to do
5. **Common actions, step by step** — numbered procedures with mini-SVG of each click
6. **Behind the scenes** — plain-language data flow (e.g., "every 5s the app calls `/api/structure/matrix`, which checks Redis cache, then falls back to recomputing from candles")
7. **See also** — links to related Concepts chapters and Walkthroughs

Page chapters are grouped under the 8 sidebar groups, matching `AppRoute`:

- **OVERVIEW** (2) Dashboard · Live Readiness
- **STRATEGY** (3) Strategy Workspace · Strategy Canvas · Backtest & Simulation
- **STRUCTURE** (3) Market Structure · Structure Matrix (HTF Tribunal) · Manipulation Radar
- **EXECUTION** (3) Execution Center · Orders & Positions · Reconciliation Bus
- **RISK** (3) Risk Center · Stop Protection · Circuit Breakers
- **AI RESEARCH** (4) AI Research Room · Agent Platform · Signal Center · Market Sentiment
- **GROWTH** (3) Growth Review · Failure Clustering · Strategy Optimization
- **SYSTEM** (3) Service Management · Data Source Management · Settings

### Part III · Walkthroughs (5 scenarios)

End-to-end scenarios that thread multiple pages together. Each walkthrough has a **start checklist** and **end checklist** so users can self-verify completion. Each step links back to the relevant page chapter.

1. **first-strategy.html** — From zero to a live strategy: AI Research generates → Canvas adjusts → Backtest validates → Dry-run runs a week → Live small.
2. **daily-trading-loop.html** — A trader's morning routine: Dashboard → Market Structure → Structure Matrix MTF check → Signal Center → Execution if warranted.
3. **htf-tribunal-flow.html** — The Structure Matrix deep dive: LTF break → enters Shadow Window → HTF candle closes → verdict → Apply to Order Form.
4. **risk-incident.html** — When a circuit breaker trips: alert source → Risk Center → pause strategy → post-mortem.
5. **improve-strategy.html** — One week later, what to tune: Growth Review → Failure Clustering → param tweaks → re-backtest.

## Visual Style

Direct port of AlphaLoop's design tokens (`macos-app/AlphaLoop/DesignSystem/DesignTokens.swift`) to CSS variables in `styles.css`:

```css
:root {
  --bg:            #0a0c10;
  --bg-elevated:   #11141a;
  --card:          rgba(20, 24, 32, 0.6);
  --border:        rgba(255, 255, 255, 0.08);
  --border-strong: rgba(255, 255, 255, 0.14);
  --text-primary:  #e8eaee;
  --text-2nd:      #9ca0a8;
  --text-muted:    #5e636d;
  --accent:        #00ff9d;
  --state-yellow:  #f5c542;
  --state-orange:  #ff9b3d;
  --state-red:     #ff5470;

  --space-xxs:  4px;  --space-xs:  8px;  --space-sm: 12px;
  --space-md:  16px;  --space-lg: 24px;  --space-xl: 32px;
  --radius-sm:  6px;  --radius-md: 10px; --radius-card: 16px;

  --font-display: "Fraunces", Georgia, serif;
  --font-body:    "Inter", -apple-system, sans-serif;
  --font-mono:    "JetBrains Mono", "SF Mono", monospace;
}
```

- **Background layers**: solid `#0a0c10` + faint repeating dot grid (CSS gradient) + subtle 1% noise (data-URI SVG) — mirrors `BackgroundView`'s 4-layer stack.
- **Cards**: `background: var(--card); backdrop-filter: blur(20px); border: 1px solid var(--border); border-radius: var(--radius-card)`. Liquid glass without WebKit hacks.
- **Typography ramp**: `h1` 32px Fraunces 500 / `h2` 22px Fraunces 500 / `h3` 16px Inter 600 / body 15px Inter / mono 13px JetBrains for code & numerals.
- **Accent**: `var(--accent)` only on links, status dots, the "current" sidebar indicator, and the language toggle's active state. No green-on-green walls.
- **Citations**: rendered as small superscript chips `[¹]` that scroll-link to a Sources block at the bottom of each chapter — same convention as the IA spec.
- **Micro-motion**: page-load fade-up 60ms stagger; sidebar item hover border lifts; chapter switch crossfade 120ms. No scroll-triggered animations.

## Site Mechanics

- **Routing**: hash router (`#/concepts/order-block`). `app.js` listens for `hashchange`, parses path → fetches `content/<lang>/<path>.html` → injects into `<main>` → updates sidebar active class → smooth-scrolls to top.
- **Search**: `⌘K` opens a centered modal. Input filters `search-index.json` (title + keyword tokens) in real time. Index is hand-authored, one entry per chapter + key concept aliases (e.g., "公允价值缺口" → `concepts/fair-value-gap`).
- **Language toggle**: header button `[zh ◍ en]`. Click flips a `data-lang` attribute on `<html>`; router refetches the current chapter from the matching language folder. Persisted in `localStorage["alphaloop.guide.lang"]`. Default = `zh`.
- **Search-engine-free**: no analytics, no telemetry, no external requests beyond what the user explicitly clicks.
- **Offline-first**: all fonts vendored locally under `assets/fonts/`. No CDN. Site works opened directly from `file://`.

## macOS App Integration

Two entry points. Both call `NSWorkspace.shared.open(_:)` on the bundled or repo-relative `docs/user-guide/index.html`.

### 1. Sidebar entry (`Views/AppShell/SidebarView.swift`)

Add a `SidebarUserGuideLink` row at the bottom of the sidebar, **above** the settings row but **below** the last navigation section. Mini book icon (SF Symbol `book.closed`). Label uses `L10n.Guide.title` (新增 key). Tapping calls `openUserGuide()` helper that resolves the HTML path and opens it externally.

```swift
// new file: Views/AppShell/SidebarUserGuideLink.swift
struct SidebarUserGuideLink: View { ... }

// helper, lives in Services/UserGuide.swift
enum UserGuide {
    static func open(anchor: String? = nil) {
        let url = resolveLocalGuideURL(anchor: anchor)
        NSWorkspace.shared.open(url)
    }
}
```

Path resolution priority:
1. Bundled inside the app under `Resources/user-guide/` (release builds — Xcode copies the folder).
2. Repo-relative `../../docs/user-guide/index.html` from `Bundle.main.bundleURL` (dev builds).
3. Falls back to GitHub raw URL if neither exists.

### 2. Dashboard top card (`Views/Dashboard/DashboardView.swift`)

A new `LearnAlphaLoopCard` slotted at the very top of the Dashboard scroll content. Dismissible (writes `UserDefaults["hideLearnAlphaLoopCard"] = true`). Layout:

```
┌────────────────────────────────────────────────────────────────────┐
│  ✶  Learn AlphaLoop                                              ✕ │
│     5 分钟读完每个页面 · understand every page in 5 minutes         │
│                                                                    │
│     [ Welcome ]  [ Core Concepts ]  [ First Strategy → ]           │
└────────────────────────────────────────────────────────────────────┘
```

- Fraunces serif title, Inter subtitle (bilingual via `L10nText`)
- Three chips are buttons; each calls `UserGuide.open(anchor: "...")` with anchors `/`, `/concepts/`, `/walkthroughs/first-strategy`
- Close (`xmark.circle.fill`) sets the UserDefaults flag and animates the card out
- A "restore" affordance lives in Settings → Display ("Show Dashboard learn card")

### L10n keys (new `Localization/L10n+Guide.swift`)

```swift
extension L10n {
    enum Guide {
        static var title: String          { zh("用户指南", en: "User Guide") }
        static var sidebarLabel: String   { zh("用户指南", en: "Guide") }
        static var dashboardTitle: String { zh("学习 AlphaLoop", en: "Learn AlphaLoop") }
        static var dashboardSubtitle: String { zh("5 分钟读完每个页面", en: "Understand every page in 5 minutes") }
        static var chipWelcome: String    { zh("欢迎", en: "Welcome") }
        static var chipConcepts: String   { zh("核心概念", en: "Core Concepts") }
        static var chipFirstStrategy: String { zh("第一个策略", en: "First Strategy") }
        static var openFailed: String     { zh("无法打开用户指南", en: "Couldn't open the user guide") }
        static var restoreCard: String    { zh("显示 Dashboard 学习卡", en: "Show Dashboard learn card") }
    }
}
```

## Implementation Notes

- **Bilingual file layout**: chose folder-per-language (`content/zh/...`, `content/en/...`) over inline `data-lang` blocks. Router prepends `lang` to fetch path. Easier to author, easier for translators to diff, allows partial language coverage with graceful fallback to zh.
- **SVG diagrams**: hand-authored, no chart library. Each diagram lives inside the chapter HTML directly so the partial is self-contained. A `<style>` block scoped via SVG `class="diagram"` selectors keeps the look consistent (same `--accent`, `--state-*` vars).
- **Bundling vs repo-relative**: for dev builds we just read from the repo; release builds need the folder copied into the .app bundle. Add a Copy Files build phase later (out of scope for v1 — Settings will show "documentation served from repo").
- **Bundle size budget**: <2 MB total (fonts ~600 KB, content ~800 KB, code <50 KB).
- **Accessibility**: respect `prefers-reduced-motion` (kill fade-ups); semantic landmarks (`<nav>`, `<main>`, `<article>`); keyboard focus rings preserved.

## Out of Scope

- PDF export
- Search-engine SEO (site is local-only)
- Embedded video tutorials
- User progress tracking / bookmarks / comments
- Live API connection (guide stays static)
- Copy-button on code blocks (none of the chapters contain executable code)
- A dedicated build pipeline — content is hand-written HTML, no Markdown → HTML step
- Xcode "Copy Files" build phase for app-bundle inclusion (deferred; v1 reads from repo path)
