---
name: proofalpha-frontend
description: >
  Build production-grade dark cyberpunk frontend UIs with glass-morphism, glow effects, terminal aesthetics,
  and rich micro-interactions. Use this skill whenever creating or modifying frontend components, pages,
  dashboards, or any web UI — especially dark-themed interfaces, data-heavy dashboards, fintech/trading UIs,
  developer tools, or anything that should look premium and futuristic. Also use when asked about design systems,
  UI polish, animation effects, hover interactions, card designs, or layout patterns for React/Tailwind projects.
  MUST trigger on: "design", "UI", "component", "dashboard", "dark theme", "cyberpunk", "glass effect", "glow",
  "animation", "hover effect", "card", "layout", "frontend style", "make it look good", "polish the UI",
  "build a page", "create a form", "dark mode", "terminal style", "hacker aesthetic", "data table", "metric card".
---

# ProofAlpha Frontend Design System

A dark cyberpunk glass-morphism design system for building premium, futuristic web interfaces.

## Before You Build Anything

Read the relevant reference files in this skill's `references/` directory:

1. **`references/design-tokens.md`** — Colors, typography, spacing, shadows, gradients. Read this first.
2. **`references/components.md`** — Card, button, input, badge patterns with exact code.
3. **`references/animations.md`** — CSS keyframes, Framer Motion patterns, WebGL effects.
4. **`references/layout.md`** — AppShell, sidebar, topbar, page structure.

## Quick Reference — Exact Values

These are the exact values to use. Do not substitute with Tailwind defaults.

### Colors (use these, NOT Tailwind defaults)
```
Background:     #0a0a0a                          (NOT #09090b, NOT #000)
Surface:        rgba(255,255,255,0.04)
Surface hover:  rgba(255,255,255,0.06)
Border:         rgba(255,255,255,0.08)            (NOT white/10, NOT white/20)
Border hover:   rgba(255,255,255,0.16)
Primary:        #00ff9d                           (NOT emerald-500, NOT green-500)
Primary hover:  #33ffb1
Danger:         #ff3b3b                           (NOT red-500, NOT red-600)
Text primary:   #e0e0e0                           (NOT white, NOT gray-100)
Text secondary: #888888                           (NOT gray-400)
Text muted:     #555555                           (NOT gray-500)
Info:           #00c2ff
Warning/accent: #ffb800
```

### Glass-Morphism (every card/panel must have this)
```
bg-[rgba(24,24,27,0.55)]    backdrop-blur-[14px]    backdrop-saturate-120
border border-white/[0.05]  shadow-[0_1px_3px_rgba(0,0,0,0.3)]
hover:border-white/[0.09]
```

### Border Radius
```
Cards:          rounded-lg    (8px)
Buttons:        rounded-sm    (2px)
Inputs:         rounded-sm    (2px)
Badges:         rounded-sm    (2px)
```
NEVER use rounded-xl or rounded-2xl — the aesthetic is sharp and technical, not soft.

### Typography
```
Body/data:      font-mono     (IBM Plex Mono)
Headings:       font-['Instrument_Sans',sans-serif]
Labels:         text-[10px] font-medium uppercase tracking-[0.15em]
Numbers:        tabular-nums  (always on financial/numerical data)
Badges:         text-[11px] font-medium uppercase tracking-[0.04em]
```

### Terminal Labels
Every section/card header uses this pattern:
```tsx
<span className="font-mono text-[10px] font-medium uppercase tracking-[0.15em] text-[#555555]">
  <span className="text-[#00ff9d]">//</span> SECTION NAME
</span>
```

### Focus States
```
focus:border-[rgba(0,255,157,0.5)] focus:shadow-[0_0_0_4px_rgba(0,255,157,0.1),0_0_15px_rgba(0,255,157,0.06)]
```

### Glow Effects
```
Subtle:  box-shadow: 0 0 15px rgba(0,255,157,0.1), 0 0 40px rgba(0,255,157,0.04)
Strong:  box-shadow: 0 0 25px rgba(0,255,157,0.15), 0 0 60px rgba(0,255,157,0.06)
Button:  box-shadow: 0 0 20px rgba(0,255,157,0.2)
Text:    text-shadow: 0 0 20px rgba(0,255,157,0.3), 0 0 40px rgba(0,255,157,0.1)
```

### Background Layers (always on page root)
Three layers, all `position: fixed; inset: 0; pointer-events: none; z-index: 0`:
1. **Mesh gradient** — dual radial gradients (green top-left, amber bottom-right) + scanlines
2. **Grid overlay** — 60px grid lines at 2% opacity
3. **Noise overlay** — SVG fractal noise at 2.5% opacity

See `references/design-tokens.md` for the exact CSS.

## Core Design Principles

### 1. Dark-First, Layered Depth
Everything lives on a near-black (`#0a0a0a`) canvas. Depth is created through semi-transparent overlays at different opacities — not through solid background colors.

### 2. Electric Green as the Signal Color
`#00ff9d` draws the eye to what matters: active states, primary actions, positive values, focus indicators, glows. Use sparingly but consistently.

### 3. Monospace Everywhere
Body text, labels, buttons, data — all `font-mono`. Only large headings use display sans-serif. This creates the terminal aesthetic and ensures `tabular-nums` aligns financial data.

### 4. Ultra-Subtle Borders
`rgba(255,255,255,0.05–0.08)` — almost invisible. On hover, lighten to `0.12–0.16`.

### 5. Glass-Morphism on Every Panel
`backdrop-filter: blur(14px) saturate(120%)` with semi-transparent dark backgrounds. This is the signature look.

### 6. Small Border Radius
2px for buttons/inputs/badges, 8px for cards. Sharp and technical, not rounded.

### 7. Uppercase Terminal Labels
10px, uppercase, 0.15em letter-spacing, prefixed with `//` in green.

### 8. Opacity-Based Color System
Never use solid colors for backgrounds/tints. Always rgba:
- Backgrounds: `rgba(color, 0.03–0.08)`
- Tints: `rgba(color, 0.10)`
- Borders: `rgba(color, 0.12–0.20)`

## Common Mistakes to Avoid

| Mistake | Correct |
|---------|---------|
| `rounded-2xl` or `rounded-xl` on cards | `rounded-lg` (8px) |
| `rounded-full` on badges | `rounded-sm` (2px) |
| `backdrop-blur-sm` or `backdrop-blur` | `backdrop-blur-[14px]` |
| `bg-emerald-500` or `bg-green-500` | `bg-[#00ff9d]` or `bg-primary` |
| `bg-red-500` or `bg-red-600` | `bg-[#ff3b3b]` or `bg-danger` |
| `text-white` for body text | `text-[#e0e0e0]` |
| `text-gray-400` for secondary text | `text-[#888888]` |
| `border-white/10` or `border-white/20` | `border-white/[0.05]` to `border-white/[0.08]` |
| Missing `tabular-nums` on numbers | Always add `tabular-nums` to financial data |
| No terminal labels on sections | Add `// SECTION NAME` labels |
| `animate-pulse` for skeleton | Use `skeleton-shimmer` gradient animation |
| No glass-morphism on panels | Add `backdrop-blur-[14px]` + `bg-[rgba(24,24,27,0.55)]` |
| Solid background colors | Always use rgba with low opacity |

## Animation Quick Reference

```css
/* Entry animation */
animation: fadeInUp 0.4s cubic-bezier(0.4, 0, 0.2, 1) both;

/* Skeleton loading */
background: linear-gradient(90deg, rgba(255,255,255,0.04) 25%, rgba(255,255,255,0.08) 50%, rgba(255,255,255,0.04) 75%);
background-size: 200% 100%;
animation: skeleton-shimmer 1.5s ease-in-out infinite;

/* Status LED pulse */
animation: ping 2s cubic-bezier(0, 0, 0.2, 1) infinite;

/* Reduced motion fallback */
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
  }
}
```

## Tech Stack

- **React 18/19** + TypeScript
- **Tailwind CSS v4** (config in `@theme` block)
- **Framer Motion** for complex animations
- **clsx + tailwind-merge** → `cn()` utility

Adapt principles to other stacks — tokens and patterns are framework-agnostic.

## Customization

To rebrand: change `--color-primary`, update glow/shadow rgba values. Keep dark background, opacity system, glass-morphism — these define the aesthetic more than the specific green.
