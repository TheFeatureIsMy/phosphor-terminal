---
name: web3-aesthetic-systems
description: Six distinct, production-ready Web3 / crypto / fintech aesthetic systems for dashboards, trading terminals, data-dense product UI, and DeFi apps. Each is a complete design language (palette, type, layout DNA, signature, motion, icons) grounded in a real product lineage — not a color swap. Use when building or reskinning a crypto/fintech/data product and you want a strong, non-generic visual identity. Includes a theme-switching strategy and a web→SwiftUI cross-framework port map.
---

# Web3 Aesthetic Systems

> Six complete aesthetic systems for **crypto / fintech / data-dense product UI** (dashboards, trading terminals, DeFi apps, admin consoles). This is NOT a landing-page skill and NOT a "pick a hue" theme file. Each system is a full design language with its own layout DNA, type philosophy, motion, and signature element, grounded in a real product lineage so it never reads as generic AI output.
>
> Everything below is **framework-agnostic tokens + intent**. A web→SwiftUI port map is in §8 so the same system ships on the web and on Apple platforms.

---

## 0. HOW TO USE THIS SKILL

1. **Read the product's job first.** These systems are for data-dense product surfaces. If the brief is a marketing landing page or portfolio, this is the wrong skill.
2. **Pick a system by the product's temperament** (§1 selector), not by favorite color.
3. **Match layout family to page type** (§7). No single system is best for every page — a records page, a narrative page, and an alert page want different DNA.
4. **Copy the system's spec verbatim** (§2–§6): the hex values, the fonts, the signature, the forbidden list. Do not average two systems together unless doing an explicit theme architecture (§9).
5. **Honor the quality floor** (§10) on everything: responsive, reduced-motion, visible focus, WCAG AA.

**The core discipline: one system per surface.** The failure mode this skill exists to prevent is "same wireframe, six color swaps." Each system has a different *layout DNA* (a vertical ledger is not a bento is not a node graph). If you find yourself building the same DOM and only changing `--accent`, you are doing it wrong — either commit to one system's DNA, or use the theme architecture in §9 deliberately.

### Bundled resources
- **`tokens.json`** — machine-readable token sets for all six systems (exact hex, fonts, radius, density, forbidden lists, Google Fonts imports). Read this to get values programmatically instead of parsing the tables below.
- **`references/examples/`** — seven working, self-contained HTML reference implementations. **Open them in a browser (or read the source) before building — a rendered example teaches the system's layout DNA faster than the spec alone.**
  - `01-ledger.html` … `06-rwa.html` — one full dashboard per system, showing each system's signature, layout DNA, palette, and motion in a real (non-trivial) page.
  - `theme-switcher.html` — a live demonstration of §9: one shared page layout swapping five systems (LEDGER/DEPTH/PROTOCOL/RWA/BRUTALIST) via a token set. Use it to understand exactly which properties are token-switchable vs structural.

  These are **calibration references, not templates to copy verbatim** — they show what "right" looks like for each system. Match their quality bar; don't clone their exact content.

---

## 1. SYSTEM SELECTOR

| If the product should feel… | Use | Lineage |
|---|---|---|
| Like an on-chain record you can audit line by line | **① LEDGER** | Etherscan / block explorers |
| Like a professional's professional trading terminal | **② DEPTH** | Bloomberg Terminal / dYdX |
| Like a clean, trustworthy modern consumer product | **③ PROTOCOL** | Uniswap / Base / Phantom |
| Like a living system topology / signal network | **④ SPATIAL** | Node graphs / React Flow / DAG editors |
| Like it has an attitude and refuses to be polished | **⑤ BRUTALIST** | Blur / Blast / pump.fun |
| Like an institutional-grade asset report | **⑥ RWA** | Ondo / Ethena / Superstate |

**Density / brightness spectrum** (helps triangulate):
- Lightest surface: ③ PROTOCOL (the only light-mode system by default)
- Densest: ② DEPTH → ① LEDGER
- Most spatial / least tabular: ④ SPATIAL
- Loudest: ⑤ BRUTALIST
- Most reserved / heritage: ⑥ RWA

---

## 2. ① LEDGER — On-chain Ledger

**Lineage:** Etherscan, block explorers. **Temperament:** forensic, immutable, everything is a signed record.

### Layout DNA
The whole page is **one vertical ledger stream — no cards.** A fixed left gutter (~90px) shows a monotonic index (block height `#4821` counting down) + timestamps (`06:22`), right-aligned mono, separated from the body by a vertical hairline. The right column is line-by-line entries, 1px hairline between rows. Each entry reads like a signed block.

### Palette (dark, mineral ink)
```
--bg:        #0D0F0E   /* page */
--row:       #111413   /* entry row base */
--row-alt:   #141917
--hairline:  #1E2422
--text:      #C8D0CC   /* primary */
--text-dim:  #6B7671   /* secondary */
--text-mute: #4A5551
--num:       #E8EEEB   /* mono numerals */
--accent:    #2FBF71   /* THE only accent — emerald: ✓ confirm / profit / hash link / active */
--down:      #D9544D   /* loss, used sparingly */
--warn:      #C9A227   /* amber caution */
```
**Zero gradients.** The restraint is the point.

### Type
Mono everywhere: **IBM Plex Mono** (400/500/600). Titles = 500/600 at larger size. Never Inter, never serif.

### Signature
Entries render as **"signed blocks"**: a truncated hash (`0x8f..2a`) + a verification check `✓` + a thin "confirmation progress" bar (`██████░░░` or a hairline fill showing settled depth). This is what the page is remembered by.

### Motion
New rows fade-in and push down (stagger on load or IntersectionObserver). Nothing loops. Nothing floats.

### Icons
Mono / geometric glyphs only: `✓ ▸ ⬢ ░ █ ── │`. No emoji, no drawn SVG icons.

### Forbidden
Cards, glass/backdrop-filter, mesh/aurora, gradient text, radius > 4px, purple/blue-violet, emoji.

---

## 3. ② DEPTH — Depth Cockpit

**Lineage:** Bloomberg Terminal, dYdX, market-maker terminals. **Temperament:** maximum information density, for someone who stares at it all day.

### Layout DNA
**High-density multi-pane cockpit.** A 24px horizontal ticker tape marquee runs across the top (`BTC 64,180▲ ETH 3,342▲ …`, pauses on hover). Below: a tight CSS Grid of panes with 1px hard dividers or 4–6px gaps. Tiny labels, tight line-height. If the product has an order-book / depth surface, the **hero is a live order-book depth ladder**.

### Palette (CRT phosphor amber on near-black)
```
--bg:        #080807
--pane:      #0E0D0B
--pane-2:    #131109
--divider:   #211F1A
--text:      #D6CBB0   /* warm gray */
--text-dim:  #7A7159
--text-mute: #565043
--accent:    #F5A623   /* sodium amber: live data / titles / bids / active */
--up:        #3FB950   /* phosphor green — up/buy */
--down:      #E5484D   /* down/sell */
```
Warm CRT tone. **No neon cyan, no blue-violet.**

### Type
All mono: **JetBrains Mono** (400/500/700). Sizes 10–12px with tight line-height for terminal density. Labels uppercase + letter-spacing.

### Signature
The **order-book depth ladder**: each price level is a row whose background is a cumulative-volume bar extending right-to-left (bids green, asks red), with the current mark price highlighted in amber and a mid-price spread indicator. If no order-book data exists, express density via "packed data panes + ticker tape + amber-highlighted live row."

### Motion
Ticker tape infinite horizontal scroll (pauses on hover). Optional subtle depth-bar "flicker." All off under reduced-motion.

### Icons
`▲▼ ● ░ █ │ ═`. No emoji.

### Forbidden
Radius > 2px, glass, mesh, gradient text, purple/blue, emoji, generous whitespace. This system must feel *dense*.

---

## 4. ③ PROTOCOL — Institutional DeFi (light)

**Lineage:** Uniswap, Base, Phantom. **Temperament:** clean, trustworthy, modern consumer product. **The only light-mode system.**

### Layout DNA
Light, generous whitespace, **large radius (16–20px, consistent)**, rhythmic bento (NOT three equal cards). Very light borders + soft *tinted* shadow (shadow carries the brand hue, never pure black). No heavy glassmorphism.

### Palette (light, cobalt two-color)
```
--bg:        #F6F7FB   /* cool white */
--card:      #FFFFFF
--border:    #E6E9F2
--text:      #0F1524   /* primary */
--text-dim:  #5A6480   /* secondary — must pass WCAG AA */
--text-mute: #8A93A8
--accent:    #3D5AFE   /* cobalt — the one brand color */
--accent-2:  #FF7A59   /* warm coral — tiny accents only (CTA hover / today's PnL) */
--up:        #12B76A
--down:      #F04438
--warn:      #F59E0B
--shadow:    0 12px 34px rgba(61,90,254,0.10)
```
Soft, professional, non-saturated. Secondary text must clear WCAG AA.

### Type
Display **Space Grotesk** (600/700); body **Inter** (acceptable here — this is the clean-modern-product register); numerals tabular.

### Signature
A clean, trustworthy **primary asset card**: large tabular number + an embedded smooth brand-color area curve (restrained cobalt gradient fill) + a status pill. Uniswap-asset-card confidence.

### Motion
CountUp on numbers; cards fade-in-and-rise on scroll (IntersectionObserver, stagger). Hover: card lifts + shadow deepens. `:active` press.

### Icons
Clean 1.5-stroke geometric SVG (Phosphor / Tabler style). No emoji.

### Forbidden
Dark bg, neon, scanlines, mesh abuse, gradient-text headlines, purple-AI palette, mono as body font, dense cockpit, emoji, three-equal glass cards.

---

## 5. ④ SPATIAL — Strategy Star-map

**Lineage:** node graphs, React Flow, DAG editors. **Temperament:** a living system topology; relationships and flow, not tables.

### Layout DNA
A **spatial canvas topology.** Dark bg with a faint dot-grid coordinate field. Entities (strategies / signals / agents / risk) are **nodes**; nodes are connected by SVG-path **edges**; **pulse dots flow along the edges** (SMIL `animateMotion` or CSS `offset-path`). Key metrics are **semi-transparent floating HUD panels** overlaid on the canvas. Side: scrollable floating log panel. Bottom: floating dock.

### Palette (star-map cool light — NOT blue-violet)
```
--bg:        #070B0C   /* near-black, cool green cast */
--grid:      rgba(120,180,170,0.06)
--node:      #0F1614
--node-edge: #22403A
--text:      #CFE0DA
--text-dim:  #6C8079
--accent:    #5CE6A8   /* lime signal — active nodes / flow pulses / highlight */
--accent-2:  #3FA9E0   /* cool blue — signal-type edges, distinct from lime data-flow */
--up:        #5CE6A8
--down:      #F0645B
--warn:      #E8B84B
```

### Type
Node titles / display **Space Grotesk** 600; data / coordinates / labels **IBM Plex Mono** (400/500). Labels are small and precise, like an engineering schematic.

### Signature
**Pulse dots flowing along edges** (direction = capital / signal flow) + active nodes with a breathing glow + semi-transparent floating HUD. This is the soul; without the flow it's just a dark dashboard.

### Motion
Edge-flow pulses; node breathing glow; node hover highlight + tooltip. All flow/breathing OFF under reduced-motion (edges become static).

### Backdrop-filter
**Allowed here** for the floating HUD panels — it is part of this system's signature, not decoration.

### Icons
Geometric node symbols (circle / hexagon / diamond) as SVG.

### Forbidden
Traditional card-grid dashboards, mesh, glass abuse (HUD only), gradient text, purple-AI palette, emoji.

### ⚠ Portability note
This system's signature is **structural, not token-level.** You cannot reskin a table into a star-map. It needs a real graph layout (and interactive node dragging needs a graph engine). On the web use a graph lib (React Flow / d3); on Apple platforms this is the one system best served by embedding a web canvas in a WebView rather than re-implementing in pure SwiftUI (see §8).

---

## 6. ⑤ BRUTALIST — Feral Degen

**Lineage:** Blur, Blast, pump.fun. **Temperament:** loud, defiant, anti-polish. Neo-brutalism.

### Layout DNA
Thick-border (2–3px solid) hard blocks that may be **intentionally offset / misaligned.** **Offset hard shadow** `box-shadow: 6px 6px 0 #000` (solid, not blurred). Global `border-radius: 0`. A horizontal big-type **marquee** (pauses on hover). Extreme size contrast (huge vs tiny).

### Palette (black + electric yellow)
```
--bg:        #0A0A0A   /* or local pure #000 */
--block:     #141414
--block-2:   #1A1A1A
--accent:    #E5FF00   /* electric acid yellow — big numbers / marquee / primary button fill */
--accent-on: #000000   /* black text on yellow */
--text:      #FFFFFF
--up:        #00E676   /* feral green */
--down:      #FF3B3B   /* feral red */
--magenta:   #FF2E9A   /* tiny second accent, sparingly */
--border:    #E5FF00   /* or #FFF or #000 */
--shadow:    6px 6px 0 #000
```
High contrast, not soft. Keep body readable (no yellow-on-yellow).

### Type
Display = ultra-bold compressed: **Anton** or **Archivo** (800/900), can be uppercase / skewed / italic. Body / data = **Space Mono** (mono). Size contrast is extreme.

### Signature
Giant compressed-black display number + big-type marquee + offset hard-shadow blocks. **Hover: block translates (3px,3px) so the hard shadow "seats"** — the classic brutalist micro-interaction.

### Motion
Marquee scroll (pauses on hover); block-seat on hover. Off under reduced-motion.

### Icons
Bold geometric glyphs `▲▼ ■ ► ✕` or heavy-stroke SVG. No color emoji.

### Forbidden
Soft shadows, glass, any radius, mesh, gradient text, purple-AI palette, precious micro-interactions, gentle symmetric centering.

---

## 7. ⑥ RWA — Institutional Serif

**Lineage:** Ondo Finance, Ethena, Superstate. **Temperament:** grave, precise, heritage finance. The "wears a suit" of Web3.

### Layout DNA
A dignified **report grid.** Restrained header (serif wordmark + fine divider). Large serif numbers with precise small labels (factsheet: label above, big number below, unit small). Financial tables (fine hairlines, right-aligned numbers, generous whitespace). Reads like a beautifully printed institutional monthly report on screen.

### Palette (deep forest green + gold)
```
--bg:        #0B1310   /* deep forest, near-black */
--panel:     #101B16
--hairline:  #22322B
--text:      #E8E4D6   /* warm off-white */
--text-dim:  #8A9188
--text-mute: #5F6B62
--accent:    #C9A86A   /* gold — key numbers / wordmark / emphasis rules */
--green:     #2E7D5B   /* deep-green accent */
--up:        #3E9B6E   /* composed green */
--down:      #B54A45   /* composed brick-red, NOT bright red */
--warn:      #C9922A
```
Low saturation, weighty, restrained.

### Type
Display serif = **Cormorant Garamond** (600) — heritage feel, titles/big-numbers only. **Never Fraunces, never Instrument Serif** (the two AI-default display serifs). Body = **Inter** (400/500, kept crisp). Data = tabular or IBM Plex Mono for precise alignment.

### Signature
A large serif number with a precise timestamp caption ("as of 2026-07-14") + a factsheet-style precision data grid. The vibe: *a report you could print and hand to an institutional LP.*

### Motion
Hairline draw-in (`scaleX 0→1`) + content fade. Restrained and elegant, never bouncy. Off under reduced-motion.

### Icons
Used sparingly; if any, simple thin-stroke geometric SVG. No emoji.

### Forbidden
Neon, scanlines, glass, mesh, gradient text, purple-AI palette, emoji, cyber vibes, flashy motion.

---

## 8. WEB → SWIFTUI PORT MAP

These systems must ship on Apple platforms too. Here is the honest capability map. **The HTML specs are design direction, not code to transpile** — porting means re-implementing the same visual language natively.

### Universal (every system, no issue)
| Web technique | SwiftUI equivalent |
|---|---|
| Custom fonts (Anton, Cormorant, IBM/JetBrains/Space, Space Grotesk) | Bundle TTFs, register in Info.plist → `.font(.custom(...))`. Renders identically. |
| Color / radius / border / spacing | Native. Define a token struct. |
| Tabular numerals | `.monospacedDigit()` |
| CountUp number roll | `.contentTransition(.numericText())` + `withAnimation` |
| `prefers-reduced-motion` | `@Environment(\.accessibilityReduceMotion)` |
| Hover (tape pause, brutalist seat) | `.onHover` (macOS/iPadOS pointer; not iPhone) |
| Soft tinted shadow (PROTOCOL) | `.shadow(color:radius:x:y:)` |
| Offset hard shadow (BRUTALIST) | `.shadow(color:.black, radius:0, x:6, y:6)` — exact match |
| Frosted glass (PROTOCOL/SPATIAL HUD) | `.ultraThinMaterial` — **more native and better than CSS backdrop-filter** |
| Area/line chart (PROTOCOL curve) | Swift Charts |

### Per-system verdict
- **① LEDGER** — trivial. Ledger stream = `LazyVStack` + `Divider`. Hash/check/progress-bar are standard layout.
- **② DEPTH** — easy. Depth ladder = `ZStack` + `GeometryReader` volume bars. Ticker tape = manual offset animation (moderate).
- **③ PROTOCOL** — easy. Everything maps natively; glass via `.ultraThinMaterial`.
- **⑤ BRUTALIST** — easy. Hard shadow, zero radius, heavy type, marquee all trivial. Brutalism maps *cleanest* of all.
- **⑥ RWA** — easy. Serif bundled; hairline draw-in via `.scaleEffect` + animation; factsheet via `Grid`.
- **④ SPATIAL** — **visual yes, soul expensive.** Cool palette, HUD (`.ultraThinMaterial` + `.blur`), breathing glow all doable. But its signature — nodes + pulse dots flowing along edges — has no cheap native path: SwiftUI `Path` has no SVG `getPointAtLength`, so path-following motion needs manual bézier math, and interactive node dragging means rebuilding a graph engine. **Recommended: embed a web canvas (React Flow) in a WKWebView; SwiftUI does the shell + HUD.** Not a compromise — a legitimate hybrid.

### Web-isms that must be TRANSLATED, not copied
- `color-mix()` → precompute the mixed `Color` / opacity in Swift.
- CSS `@keyframes` / `transition` → `withAnimation` / `.animation` (different API, equivalent result).
- Infinite marquee, path-following flow → hand-implemented (one spot each in DEPTH / SPATIAL).

---

## 9. THEME ARCHITECTURE (switching between systems)

If a product wants **live theme switching**, be precise about which layer you're switching.

### Two layers
1. **Token layer** — color, font, radius, border-width, density (padding), shadow, motion-intensity, letter-spacing, text-transform. **Fully live-switchable.**
2. **Structure layer** — layout DNA (ledger stream vs bento vs node graph). **Cannot be reskinned by tokens.**

### What this means
- **5 of 6 systems (LEDGER / DEPTH / PROTOCOL / RWA / BRUTALIST) differ ~90% at the token layer.** They can share one page layout and swap via a token set — a real, low-maintenance theme switcher.
  - Web: `[data-theme="…"]` on `:root`, override CSS custom properties. Transition `background-color/color/border-color` for a smooth cross-fade.
  - SwiftUI: a `ThemeManager` (`@Observable`) with an `enum Theme`; a `Tokens` provider returns values by `current`; views read tokens → automatic re-render. (This extends the common dark/light `ThemeManager` pattern from 2 themes to N.)
- **④ SPATIAL is not a token skin** — it is a layout/component structure (and best as a WebView hybrid). Don't force it into a one-click reskin switcher; use it as the dedicated layout for graph/relationship pages.

### Token contract for a switchable theme (minimum set)
```
--bg --panel --panel-2 --border --border-w --hairline
--text --text-dim --text-mute
--accent --accent-on --up --down --warn
--radius --radius-lg --shadow
--font-display --font-body --font-mono
--pad(density) --letter --uppercase --marquee(on/off)
```
Note `--marquee` / motion flags: some systems (BRUTALIST) introduce *optional elements* a switch can toggle on/off. That's the boundary where token-switching starts touching structure — keep such toggles few and explicit.

### Light/dark caveat
PROTOCOL is light by default; the others are dark. A switcher that jumps light↔dark is jarring. If a product needs both a system choice AND a light/dark choice, decide up-front whether each system ships a dark+light variant, or whether the system choice implies its brightness.

---

## 10. QUALITY FLOOR (applies to every system)

- **Responsive** to mobile: high-density layouts (DEPTH, LEDGER) collapse to single column < 768px; SPATIAL degrades to a node list + stacked HUD on small screens.
- **Reduced motion:** every loop / marquee / flow / breathing / parallax collapses to static under `prefers-reduced-motion` (`@Environment(\.accessibilityReduceMotion)`).
- **Visible keyboard focus** on all interactive controls (use the system's accent for the ring).
- **WCAG AA** contrast for body text (esp. PROTOCOL's secondary text, RWA's muted text on dark green).
- **Animate only `transform` / `opacity`** (web); keep grain/noise on fixed `pointer-events:none` layers.
- **Fonts self-hosted / bundled**, `font-display: swap` (web) — never a blocking `<link>` in production.
- **Numbers are tabular** everywhere financial (`.monospacedDigit()` / `tabular-nums`).
- **No color emoji as icons** in any system. Each system names its icon vocabulary — stay in it.

---

## 11. ANTI-SLOP GUARDRAILS (system-independent)

These kill the "AI-generated" tell regardless of which system you pick:
- **No AI-purple / blue-violet gradient** anywhere (none of the six use it — if you're reaching for `#8B5CF6`, stop).
- **No aurora/mesh gradient background** as a default (none of the six use it).
- **No glassmorphism on everything** — only PROTOCOL (light, restrained) and SPATIAL (HUD only) touch glass, deliberately.
- **No gradient text** for headlines in any system.
- **No same-wireframe-six-color-swaps.** The whole point is six *layout DNAs*.
- **No generic placeholder data** — "John Doe", "Acme", `99.99%`, `1234567`. Use realistic, messy, domain-true values.
- **Pick one accent and lock it** per system; don't drift a second hue in.
- **One radius scale** per system (LEDGER 4px / DEPTH 2px / PROTOCOL 16–20px / RWA 3px / BRUTALIST 0 / SPATIAL small).
- **Ground every system in its lineage** — when unsure how a component should look, ask "how would Etherscan / Bloomberg / Uniswap / a node graph / Blur / Ondo do it?"

---

## 12. QUICK REFERENCE CARD

| # | System | BG | Accent | Display font | Radius | Motion | Best for |
|---|---|---|---|---|---|---|---|
| ① | LEDGER | `#0D0F0E` | `#2FBF71` | IBM Plex Mono | 4px | minimal | records, logs, tx lists, signal streams |
| ② | DEPTH | `#080807` | `#F5A623` | JetBrains Mono | 2px | ticker | trading terminals, dense data, order books |
| ③ | PROTOCOL | `#F6F7FB` | `#3D5AFE` | Space Grotesk | 16–20px | smooth | consumer DeFi, onboarding, portfolios |
| ④ | SPATIAL | `#070B0C` | `#5CE6A8` | Space Grotesk | small | flow | topology, relationships, agent/signal graphs |
| ⑤ | BRUTALIST | `#0A0A0A` | `#E5FF00` | Anton/Archivo | 0 | marquee | alerts, launch, memecoin, high-attention |
| ⑥ | RWA | `#0B1310` | `#C9A86A` | Cormorant Garamond | 3px | draw-in | asset reports, institutional, LP-facing |

**Motto:** six lineages, six layout DNAs, one quality floor. Never a color swap.
