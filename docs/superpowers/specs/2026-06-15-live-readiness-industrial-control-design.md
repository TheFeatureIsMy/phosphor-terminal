---
title: Live Readiness — Industrial Control Room Redesign
status: approved
date: 2026-06-15
authors: claude (frontend-design + brainstorming skills)
supersedes: none (enhances existing LiveReadinessView)
related:
  - docs/product/ia_backend_redesign.md (§4.2 Live Readiness)
  - docs/superpowers/specs/2026-06-07-krypton-pro-ui-overhaul-design.md
  - docs/superpowers/specs/2026-06-15-dashboard-bento-command-grid-design.md
mockup: docs/ui-references/mockups/live-readiness-v3-industrial.html
---

# Live Readiness — Industrial Control Room

## 1. Problem

The current LiveReadinessView is functional but visually generic — flat cards, uniform borders, horizontal-scroll gate pipeline. It looks like every other dashboard page. For a page whose job is "should we commit real money?", it lacks the gravitas and tension this decision deserves.

## 2. Goals

1. Redesign with an **industrial control room** aesthetic that creates appropriate tension for a "go-live" decision.
2. Use the **existing ProofAlpha/Krypton design system** (PulseColors, PulseFonts, PulseSpacing, PulseRadii, KryptonCard) — industrial flavor through layout/concept, not through a separate token set.
3. All strings via **L10n.LiveReadiness** (new localization file).
4. Keep the existing `LiveReadinessViewModel` and `APIOverview` data layer — only rewrite the view.
5. Maintain cross-navigation to `.riskCenter` and `.circuitBreakers`.

## 3. Non-Goals

- Not changing the backend API or ViewModel data structures.
- Not implementing real `POST /api/trading/start-paper` or `start-live-small` (keep as stubs).
- Not changing the Dashboard's LiveReadinessCard (mini card).

## 4. Layout — Three Zones

```
┌──────────────────────────────────────────────────────────────────┐
│ MASTHEAD                                                          │
│ ┌─────────┬──────────────────────────────────┬──────────────────┐ │
│ │ Analog  │ State Lamp + Label + Description │ [RE-CHECK]       │ │
│ │ Gauge   │ ■ PAPER  ■ SMALL  ■ FULL        │                  │ │
│ │  (86)   │ toggles                          │                  │ │
│ └─────────┴──────────────────────────────────┴──────────────────┘ │
├──────────────────────┬───────────────────────────────────────────┤
│ GATE PIPELINE (380px)│ RIGHT STACK                               │
│                      │ ┌─────────────────────────────────────┐   │
│  01 Version    [GO]  │ │ System Health (3x2 strip)           │   │
│  02 Backtest   [GO]  │ └─────────────────────────────────────┘   │
│  03 Dry-Run    [GO]  │ ┌─────────────────────────────────────┐   │
│  04 Health     [GO]  │ │ Risk Firewall (3 gauge bars)        │   │
│  05 No Dup     [GO]  │ └─────────────────────────────────────┘   │
│  06 Risk Bind [NOGO] │ ┌─────────────────────────────────────┐   │
│  07 Confirm   [NOGO] │ │ Capital Readout (2x2 grid)          │   │
│                      │ └─────────────────────────────────────┘   │
├──────────────────────┴───────────────────────────────────────────┤
│ LAUNCH CONSOLE (full width)                                       │
│ ┌── blockers ──────────────┬── actions ─────────────────────────┐ │
│ │ ✗ risk_binding           │ [PAPER TRADE] [GO LIVE ▸] [FULL]  │ │
│ │ ✗ human_confirm          │                                    │ │
│ └──────────────────────────┴────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────┘
```

## 5. Component Specifications

### 5.1 Masthead (KryptonCard, emphasis: .bold)

Three horizontal zones:

**Left — Analog Gauge (180px)**:
- Arc gauge drawn with SwiftUI `Path` or `Shape` (not SVG)
- Track arc: 180° sweep, `colors.border` stroke
- Fill arc: colored portion based on score (accent if ≥80, warning if ≥50, danger if <50)
- Needle: thin rectangle rotated to score position, accent color
- Center: score number (PulseFonts.tabularLarge, accent) + "READINESS" label (PulseFonts.micro)
- Background: `colors.surfaceElevated` or `colors.cardBackground`

**Center — State Info**:
- State lamp: 14px pulsing circle (same pattern as Dashboard LiveReadinessCard)
- State label: PulseFonts.displaySubheading, state color, uppercase
- Description: PulseFonts.body, `colors.textSecondary`
- Permission toggles: Three horizontal items, each a visual toggle indicator (not interactive — read-only state display)
  - ON: accent dot + uppercase label in accent
  - OFF: danger dot + uppercase label in danger/muted

**Right — RE-CHECK button**:
- Bordered button, `colors.accent` border, PulseFonts.monoLabel
- Hover: accent glow via `.hoverGlassStyle()` or custom hover

### 5.2 Gate Pipeline (Left column, 380px)

Inside a KryptonCard(emphasis: .subtle) with no padding (edge-to-edge rows).

Each gate is a horizontal row with:
- **Left status strip**: 4px wide, full-height. Passed = `PulseColors.accent`, Failed = 45° hazard stripes in `PulseColors.danger`
- **Sequence number**: PulseFonts.tabularLarge, 2-digit, colored (accent/danger)
- **Gate info**: Name (PulseFonts.bodyMedium), sub-detail (PulseFonts.caption, muted), remedy if failed (PulseFonts.caption, danger)
- **Verdict badge**: "GO" (accent bg, accent text) or "NO-GO" (danger bg, danger text), PulseFonts.micro, uppercase

Rows separated by `colors.border` 1px lines.

### 5.3 System Health Strip (Right column)

3×2 grid, no card wrapper — each cell is a compact row inside a single bordered container:
- LED dot (8px, colored: accent/warning/danger)
- Service name (PulseFonts.monoLabel, uppercase)
- Value (PulseFonts.body)
- Threshold (PulseFonts.micro, muted)

Cells separated by border lines (like a hardware instrument panel).

### 5.4 Risk Firewall Panel

KryptonCard(emphasis: .subtle). Three gauge bars (daily/weekly/consecutive losses):
- Label (PulseFonts.micro, uppercase)
- Horizontal bar with colored fill (accent if safe, warning if close to limit)
- Value text (PulseFonts.body, right-aligned)

Status chips: "KILL SWITCH: OFF" / "BREAKER: NORMAL" — using existing accent chip style.

Cross-navigation: tappable area → `.riskCenter` / `.circuitBreakers`.

### 5.5 Capital Readout Panel

KryptonCard(emphasis: .subtle). 2×2 grid of readout cells:
- Value: PulseFonts.tabularLarge (22pt mono)
- Unit: PulseFonts.caption, muted
- Label: PulseFonts.micro, uppercase

Safety badges row: accent-tinted chips with icons.

### 5.6 Launch Console (Full width)

Distinctive bottom section with subtle accent border tint.

**Left — Blockers**:
- List of blocking reasons with danger "✗" prefix + code + message
- Background: slightly darker inset panel

**Right — Action buttons**:
- PAPER TRADE: ghost button, `colors.textSecondary` border
- GO LIVE: accent-filled, prominent glow on hover
- FULL LIVE: disabled/locked, muted

Button triggers existing `LaunchConfirmationSheet`.

## 6. Distinctive Industrial Elements (via existing tokens)

| Concept | Implementation |
|---------|---------------|
| Analog gauge | SwiftUI Shape/Path arc, not a library |
| Hazard stripes on failed gates | `Capsule` with 45° striped pattern via `GeometryReader` |
| Physical toggle indicators | Circle (8px) + label, ON/OFF colored differently |
| GO/NO-GO verdict | Small badges, not checkmarks |
| Panel inset feel | Using `colors.surfaceElevated` + `PulseRadii.xs` (4pt, sharper) instead of `.card` (14pt) |
| Metal texture hint | Very subtle gradient on panel backgrounds |

## 7. File Changes

### New
- `macos-app/AlphaLoop/Localization/L10n+LiveReadiness.swift` — All bilingual strings
- `macos-app/AlphaLoop/Views/LiveReadiness/ReadinessGaugeView.swift` — Analog arc gauge
- `macos-app/AlphaLoop/Views/LiveReadiness/GatePipelineView.swift` — 7-gate vertical list
- `macos-app/AlphaLoop/Views/LiveReadiness/LaunchConsoleView.swift` — Bottom launch section

### Modify
- `macos-app/AlphaLoop/Views/LiveReadiness/LiveReadinessView.swift` — Full rewrite, compose new sub-views

### Keep (no changes)
- `macos-app/AlphaLoop/ViewModels/LiveReadinessViewModel.swift` — Data layer unchanged
- `macos-app/AlphaLoop/Services/APIOverview.swift` — API unchanged

## 8. L10n Keys (L10n.LiveReadiness)

All under `extension L10n { enum LiveReadiness { ... } }`:

**Masthead**: readinessScore, recheck, stateDescription(_:), paper, small, full
**States**: liveReady("实盘就绪"/"LIVE READY"), liveSmallReady("小仓就绪"/"LIVE SMALL READY"), paperOnly("仅模拟"/"PAPER ONLY"), riskLocked("风控锁定"/"RISK LOCKED"), emergencyLocked("紧急锁定"/"EMERGENCY LOCKED"), notReady("未就绪"/"NOT READY")
**Gates**: strategyGates("策略准入门"/"STRATEGY GATES"), gateCount(_:_:) → "N / M", go("通过"/"GO"), noGo("未通过"/"NO-GO"), versionStatus/backtest/dryrunDuration/dryrunHealth/riskBinding/humanConfirm/noDuplicate (names + descriptions)
**Health**: systemHealth("系统健康"/"SYSTEM HEALTH"), fastTrack, redis, freqtrade, exchangeApi, postgresql, aiCache
**Risk**: riskFirewall("风控防火墙"/"RISK FIREWALL"), daily, weekly, consecutive, killSwitch, breaker
**Capital**: capitalPool("资金配置"/"CAPITAL POOL"), totalBudget, stakePerTrade, maxOpenTrades, maxDailyLoss, noLeverage, spotOnly, humanConfirmRequired, autoTradeOff
**Launch**: launchSequence("启动序列"/"LAUNCH SEQUENCE"), paperTrade("模拟交易"/"PAPER TRADE"), goLive("小仓实盘"/"GO LIVE"), fullLive("全仓实盘"/"FULL LIVE"), confirmTitle, confirmMessage, confirmPhrase
