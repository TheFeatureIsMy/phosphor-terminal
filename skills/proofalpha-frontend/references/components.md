# Component Patterns

## cn() Utility

All class merging uses this pattern (install `clsx` + `tailwind-merge`):

```tsx
import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}
```

---

## Cards

### Base Card
```tsx
<div className="rounded-lg border border-white/[0.05] bg-[rgba(24,24,27,0.55)]
                backdrop-blur-[14px] backdrop-saturate-120 shadow-[0_1px_3px_rgba(0,0,0,0.3)]
                transition-colors hover:border-white/[0.09]">
  {children}
</div>
```

### Accent Card (green-tinted)
```tsx
<div className="rounded-sm border border-primary/[0.12] bg-primary/[0.04]">
  {children}
</div>
```

### Glass Panel
```tsx
<div className="rounded-lg bg-[rgba(24,24,27,0.55)] backdrop-blur-[14px]
                transition-colors hover:border-primary/20">
  {children}
</div>
```

### Strong Glass
```tsx
<div className="rounded-lg border border-white/[0.08] bg-[rgba(24,24,27,0.72)]
                backdrop-blur-[20px] backdrop-saturate-140">
  {children}
</div>
```

### DepthCard (3D Tilt + Spotlight)
```tsx
'use client';
import { motion, useMotionValue, useSpring, useTransform } from 'framer-motion';
import { useRef, useState } from 'react';

interface DepthCardProps {
  children: React.ReactNode;
  className?: string;
  maxRotate?: number;      // default 3.5
  spotlightColor?: string;  // default 'rgba(0,255,157,0.08)'
}

export function DepthCard({
  children, className, maxRotate = 3.5, spotlightColor = 'rgba(0,255,157,0.08)'
}: DepthCardProps) {
  const ref = useRef<HTMLDivElement>(null);
  const [isHovered, setIsHovered] = useState(false);
  const mouseX = useMotionValue(0.5);
  const mouseY = useMotionValue(0.5);

  const rotateX = useSpring(useTransform(mouseY, [0, 1], [maxRotate, -maxRotate]), { stiffness: 150, damping: 20 });
  const rotateY = useSpring(useTransform(mouseX, [0, 1], [-maxRotate, maxRotate]), { stiffness: 150, damping: 20 });

  const handleMouseMove = (e: React.MouseEvent) => {
    if (!ref.current) return;
    const rect = ref.current.getBoundingClientRect();
    mouseX.set((e.clientX - rect.left) / rect.width);
    mouseY.set((e.clientY - rect.top) / rect.height);
  };

  return (
    <motion.div
      ref={ref}
      className={cn('relative rounded-lg border border-white/[0.05] bg-[rgba(24,24,27,0.55)] backdrop-blur-[14px] overflow-hidden', className)}
      style={{ perspective: 1100, rotateX, rotateY, transformStyle: 'preserve-3d' }}
      onMouseMove={handleMouseMove}
      onMouseEnter={() => setIsHovered(true)}
      onMouseLeave={() => { setIsHovered(false); mouseX.set(0.5); mouseY.set(0.5); }}
    >
      {/* Top edge highlight */}
      <div className="absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-primary/35 to-transparent" />
      {/* Spotlight overlay */}
      <motion.div
        className="pointer-events-none absolute inset-0 rounded-lg"
        style={{
          background: useTransform([mouseX, mouseY], ([x, y]) =>
            `radial-gradient(circle at ${(x as number)*100}% ${(y as number)*100}%, ${spotlightColor}, transparent 60%)`
          ),
          opacity: isHovered ? 1 : 0,
          transition: 'opacity 0.15s',
        }}
      />
      <div className="relative z-10">{children}</div>
    </motion.div>
  );
}
```

### SpotlightCard (Cursor Glow, No Tilt)
```tsx
import { useRef, useState } from 'react';

interface SpotlightCardProps {
  children: React.ReactNode;
  className?: string;
  spotlightColor?: string;
}

export function SpotlightCard({
  children, className, spotlightColor = 'rgba(0,255,157,0.10)'
}: SpotlightCardProps) {
  const ref = useRef<HTMLDivElement>(null);
  const [position, setPosition] = useState({ x: 0, y: 0 });
  const [isHovered, setIsHovered] = useState(false);

  const handleMouseMove = (e: React.MouseEvent) => {
    if (!ref.current) return;
    const rect = ref.current.getBoundingClientRect();
    setPosition({ x: e.clientX - rect.left, y: e.clientY - rect.top });
  };

  return (
    <div
      ref={ref}
      className={cn('relative overflow-hidden rounded-lg border border-white/[0.05] bg-[rgba(24,24,27,0.55)]', className)}
      onMouseMove={handleMouseMove}
      onMouseEnter={() => setIsHovered(true)}
      onMouseLeave={() => setIsHovered(false)}
    >
      <div
        className="pointer-events-none absolute inset-0 rounded-lg transition-opacity duration-500"
        style={{
          background: `radial-gradient(circle at ${position.x}px ${position.y}px, ${spotlightColor}, transparent 60%)`,
          opacity: isHovered ? 1 : 0,
        }}
      />
      <div className="relative z-10">{children}</div>
    </div>
  );
}
```

---

## Buttons

### Primary Button
```tsx
<button className="inline-flex h-10 items-center justify-center rounded-sm bg-primary px-4
                   font-mono text-xs font-bold uppercase tracking-[0.08em] text-background
                   transition-all hover:bg-primary-hover hover:shadow-[0_0_20px_rgba(0,255,157,0.2)]
                   focus-visible:outline-2 focus-visible:outline-primary/50
                   disabled:opacity-50 disabled:cursor-not-allowed">
  {children}
</button>
```

### Ghost Button
```tsx
<button className="inline-flex h-10 items-center justify-center rounded-sm
                   border border-dashed border-white/[0.12] bg-transparent px-4
                   font-mono text-xs uppercase tracking-wider text-text-secondary
                   transition-all hover:border-primary hover:text-primary hover:bg-primary-dim">
  {children}
</button>
```

### Icon Button
```tsx
<button className="inline-flex h-8 w-8 items-center justify-center rounded-sm
                   text-text-secondary transition-colors hover:bg-surface-hover hover:text-text-primary">
  <Icon className="h-4 w-4" />
</button>
```

---

## Inputs

### Text Input
```tsx
<input className="h-10 w-full rounded-sm border border-white/[0.08] bg-white/[0.03] px-3
                  font-mono text-sm text-text-primary placeholder:text-text-muted
                  transition-all focus:border-primary/50 focus:bg-primary/[0.03]
                  focus:outline-none focus:shadow-[0_0_0_4px_rgba(0,255,157,0.1),0_0_15px_rgba(0,255,157,0.06)]" />
```

### Select
```tsx
<select className="h-10 w-full appearance-none rounded-sm border border-white/[0.08]
                   bg-white/[0.03] px-3 pr-8 font-mono text-sm text-text-primary
                   transition-all focus:border-primary/50 focus:outline-none
                   focus:shadow-[0_0_0_4px_rgba(0,255,157,0.1)]"
        style={{ backgroundImage: `url("data:image/svg+xml,...") /* custom arrow SVG */` }}>
  {options}
</select>
```

### Toggle Switch
```tsx
<button
  role="switch"
  className={cn(
    'relative h-5 w-9 rounded-full transition-colors',
    checked ? 'bg-primary' : 'bg-white/[0.12]'
  )}
>
  <span className={cn(
    'absolute top-0.5 left-0.5 h-4 w-4 rounded-full bg-white transition-transform',
    checked && 'translate-x-4'
  )} />
</button>
```

### Checkbox
```tsx
<label className="flex items-center gap-2 cursor-pointer">
  <input type="checkbox" className="peer sr-only" />
  <div className="h-4 w-4 rounded-sm border border-white/[0.12] bg-white/[0.03]
                  transition-all peer-checked:border-primary peer-checked:bg-primary
                  peer-focus-visible:ring-2 peer-focus-visible:ring-primary/50">
    {/* Check icon visible when checked */}
  </div>
  <span className="font-mono text-sm text-text-primary">{label}</span>
</label>
```

---

## Badges

### Standard Badge
```tsx
<span className="inline-flex items-center rounded-sm px-2.5 py-0.5
                 font-mono text-[11px] font-medium uppercase tracking-[0.04em]
                 border bg-primary/10 text-primary border-primary/20">
  {label}
</span>
```

### Color Variants
| Variant | Background | Text | Border |
|---------|-----------|------|--------|
| success | `bg-primary/10` | `text-primary` | `border-primary/20` |
| warning | `bg-accent/10` | `text-accent` | `border-accent/20` |
| danger | `bg-danger/10` | `text-danger` | `border-danger/20` |
| info | `bg-info/10` | `text-info` | `border-info/20` |
| purple | `bg-purple-500/10` | `text-purple-400` | `border-purple-500/20` |
| neutral | `bg-white/[0.06]` | `text-text-secondary` | `border-white/[0.08]` |

---

## Status Indicators

### Status Dot with Ping
```tsx
<span className="relative flex h-2 w-2">
  <span className={cn(
    'absolute inline-flex h-full w-full rounded-full opacity-75 animate-ping',
    status === 'online'  && 'bg-primary',
    status === 'offline' && 'bg-danger',
    status === 'warning' && 'bg-accent',
  )} />
  <span className={cn(
    'relative inline-flex h-2 w-2 rounded-full',
    status === 'online'  && 'bg-primary',
    status === 'offline' && 'bg-danger',
    status === 'warning' && 'bg-accent',
  )} />
</span>
```

### LED Indicator (with glow)
```tsx
<span className={cn(
  'inline-block h-1.5 w-1.5 rounded-full',
  'shadow-[0_0_6px_var(--glow-color)]',
  status === 'online'  && 'bg-primary [--glow-color:rgba(0,255,157,0.5)]',
  status === 'offline' && 'bg-danger [--glow-color:rgba(255,59,59,0.5)]',
)} />
```

---

## Loading States

### Skeleton
```tsx
<div className="h-4 w-3/4 rounded-sm animate-[skeleton-shimmer_1.5s_ease-in-out_infinite]
                bg-gradient-to-r from-white/[0.04] via-white/[0.08] to-white/[0.04]
                bg-[length:200%_100%]" />
```

### Spinner
```tsx
<svg className="h-4 w-4 animate-spin text-primary" viewBox="0 0 24 24" fill="none">
  <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
  <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
</svg>
```

---

## Typography Components

### Terminal Label
```tsx
<span className="font-mono text-[10px] font-medium uppercase tracking-[0.15em] text-text-muted">
  <span className="text-primary">//</span> SECTION NAME
</span>
```

### Page Heading
```tsx
<h1 className="font-display text-[2.5rem] md:text-[3.25rem] font-bold leading-[1.1]
               tracking-[-0.02em] text-text-primary">
  {title}
</h1>
```

### Gradient Text
```tsx
<span className="bg-gradient-to-r from-primary to-info bg-clip-text text-transparent">
  {text}
</span>
```

### Tabular Numbers
```tsx
<span className="font-mono tabular-nums">{formattedValue}</span>
```

---

## Utility Patterns

### PnL Color Helper
```tsx
function getPnlColor(value: number): string {
  if (value > 0) return 'text-primary';   // green
  if (value < 0) return 'text-danger';     // red
  return 'text-text-secondary';
}
```

### Number Formatting
```tsx
function formatCurrency(value: number): string {
  return new Intl.NumberFormat('en-US', {
    style: 'currency', currency: 'USD',
    minimumFractionDigits: 2, maximumFractionDigits: 2,
  }).format(value);
}

function formatPercent(value: number): string {
  return `${value >= 0 ? '+' : ''}${value.toFixed(2)}%`;
}

function formatNumber(value: number): string {
  return new Intl.NumberFormat('en-US').format(value);
}
```
