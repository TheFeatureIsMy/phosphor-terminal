# Design Tokens

## Color Palette

### Core Backgrounds
```css
--color-background: #0a0a0a;          /* Page background — near-black */
--color-surface: rgba(255,255,255,0.04);  /* Card/panel default */
--color-surface-hover: rgba(255,255,255,0.06);
--color-surface-active: rgba(255,255,255,0.08);
```

### Borders
```css
--color-border: rgba(255,255,255,0.08);       /* Default — almost invisible */
--color-border-hover: rgba(255,255,255,0.16); /* Hover — slightly visible */
```

### Primary (Electric Green)
```css
--color-primary: #00ff9d;
--color-primary-hover: #33ffb1;
--color-primary-dim: rgba(0,255,157,0.10);
```

### Accent (Amber/Gold)
```css
--color-accent: #ffb800;
--color-accent-dim: rgba(255,184,0,0.10);
```

### Semantic Colors
```css
--color-success: #00ff9d;   /* Same as primary */
--color-warning: #ffb800;   /* Same as accent */
--color-danger: #ff3b3b;
--color-danger-dim: rgba(255,59,59,0.10);
--color-info: #00c2ff;
```

### Text
```css
--color-text-primary: #e0e0e0;   /* Light gray, NOT pure white */
--color-text-secondary: #888888;
--color-text-muted: #555555;
```

### Financial
```css
--color-profit: #00ff9d;  /* Green for positive */
--color-loss: #ff3b3b;    /* Red for negative */
```

### Extended Palette (use inline)
| Color | Hex | Background Range | Border Range |
|-------|-----|-----------------|--------------|
| Purple | `#a855f7` | `rgba(168,85,247, 0.03–0.08)` | `rgba(168,85,247, 0.1–0.2)` |
| Cyan | `#06b6d4` | `rgba(6,182,212, 0.07)` | — |
| Zinc | `#a1a1aa` | — | `#3f3f46` |

---

## Typography

### Font Families
```css
--font-display: 'Instrument Sans', sans-serif;  /* Headings only */
--font-body: 'IBM Plex Mono', monospace;         /* Everything else */
--font-mono: 'IBM Plex Mono', monospace;
```

### Scale
| Style | Size | Weight | Spacing | Line Height | Font | Use |
|-------|------|--------|---------|-------------|------|-----|
| heading-xl | 2.5rem (3.25rem md+) | 700 | -0.02em | 1.1 | Instrument Sans | Hero, page title |
| heading-lg | 1.75rem | 700 | -0.01em | 1.2 | Instrument Sans | Section title |
| heading-md | 1.125rem | 600 | -0.005em | — | Instrument Sans | Card title |
| body | 13px | 400 | — | 1.5 | IBM Plex Mono | Default text |
| terminal-label | 10px | 500 | 0.15em | — | IBM Plex Mono | `// SECTION NAME` |
| section-label | 10px | 500 | 0.15em | — | IBM Plex Mono | Uppercase category |
| badge | 11px | 500 | 0.04em | — | IBM Plex Mono | Status labels |

### Special
```css
font-variant-numeric: tabular-nums;  /* For all financial/numerical data */
```

---

## Spacing & Sizing

| Element | Value |
|---------|-------|
| Base font size | 13px |
| Sidebar width | 232px |
| TopBar height | 48px |
| Content padding | 32px |
| Card border-radius | 8px |
| Button/input/badge radius | 2px |
| Button min-height | 40px |
| Input min-height | 40px |

---

## Shadows

```css
/* Card default */
box-shadow: 0 1px 3px rgba(0,0,0,0.3);

/* Dropdown */
box-shadow: 0 16px 48px rgba(0,0,0,0.6);

/* Glow (subtle) */
box-shadow: 0 0 15px rgba(0,255,157,0.1), 0 0 40px rgba(0,255,157,0.04);

/* Glow (strong) */
box-shadow: 0 0 25px rgba(0,255,157,0.15), 0 0 60px rgba(0,255,157,0.06);

/* Text glow */
text-shadow: 0 0 20px rgba(0,255,157,0.3), 0 0 40px rgba(0,255,157,0.1);

/* Focus ring */
outline: 2px solid rgba(0,255,157,0.5);
box-shadow: 0 0 0 4px rgba(0,255,157,0.1);

/* Button hover glow */
box-shadow: 0 0 20px rgba(0,255,157,0.2);
```

---

## Gradients

```css
/* Gradient text */
background: linear-gradient(135deg, #00ff9d 0%, #00c2ff 100%);
-webkit-background-clip: text;
-webkit-text-fill-color: transparent;

/* Background mesh (page-level) */
background:
  radial-gradient(ellipse at 20% 0%, rgba(0,255,157,0.06) 0%, transparent 60%),
  radial-gradient(ellipse at 80% 100%, rgba(255,184,0,0.04) 0%, transparent 60%);

/* Card top highlight (1px line) */
background: linear-gradient(to right, transparent, rgba(0,255,157,0.35), transparent);

/* Chart area fill */
background: linear-gradient(to top, rgba(0,255,157,0.12), transparent);
```

---

## Background Overlays

Three-layer system applied to the page background:

```css
/* 1. Mesh gradient — fixed, covers viewport */
.bg-mesh {
  position: fixed; inset: 0; z-index: 0; pointer-events: none;
  background:
    radial-gradient(ellipse at 20% 0%, rgba(0,255,157,0.06), transparent 60%),
    radial-gradient(ellipse at 80% 100%, rgba(255,184,0,0.04), transparent 60%),
    repeating-linear-gradient(
      0deg, transparent, transparent 2px,
      rgba(255,255,255,0.008) 2px, rgba(255,255,255,0.008) 4px
    );
}

/* 2. Grid overlay — subtle dot grid */
.grid-overlay {
  position: fixed; inset: 0; z-index: 0; pointer-events: none;
  background-image:
    linear-gradient(rgba(255,255,255,0.02) 1px, transparent 1px),
    linear-gradient(90deg, rgba(255,255,255,0.02) 1px, transparent 1px);
  background-size: 60px 60px;
}

/* 3. Noise overlay — SVG fractal noise */
.noise-overlay {
  position: fixed; inset: 0; z-index: 0; pointer-events: none;
  opacity: 0.025;
  background-image: url("data:image/svg+xml,..."); /* SVG with feTurbulence */
  background-size: 256px 256px;
}
```

---

## Tailwind v4 @theme Block

For Tailwind CSS v4 projects, define tokens in `index.css`:

```css
@theme {
  --color-background: #0a0a0a;
  --color-surface: rgba(255, 255, 255, 0.04);
  --color-surface-hover: rgba(255, 255, 255, 0.06);
  --color-surface-active: rgba(255, 255, 255, 0.08);
  --color-border: rgba(255, 255, 255, 0.08);
  --color-border-hover: rgba(255, 255, 255, 0.16);
  --color-primary: #00ff9d;
  --color-primary-hover: #33ffb1;
  --color-primary-dim: rgba(0, 255, 157, 0.10);
  --color-accent: #ffb800;
  --color-accent-dim: rgba(255, 184, 0, 0.10);
  --color-success: #00ff9d;
  --color-warning: #ffb800;
  --color-danger: #ff3b3b;
  --color-danger-dim: rgba(255, 59, 59, 0.10);
  --color-info: #00c2ff;
  --color-text-primary: #e0e0e0;
  --color-text-secondary: #888888;
  --color-text-muted: #555555;
  --color-profit: #00ff9d;
  --color-loss: #ff3b3b;
  --font-display: 'Instrument Sans', sans-serif;
  --font-body: 'IBM Plex Mono', monospace;
  --font-mono: 'IBM Plex Mono', monospace;
}
```
