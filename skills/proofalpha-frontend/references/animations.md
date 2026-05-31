# Animations & Dynamic Effects

## CSS Keyframes

### fadeInUp — Entry animation for cards and sections
```css
@keyframes fadeInUp {
  from { opacity: 0; transform: translateY(12px); }
  to   { opacity: 1; transform: translateY(0); }
}
/* Usage: animation: fadeInUp 0.4s cubic-bezier(0.4, 0, 0.2, 1) both; */
```

### fadeIn — Simple opacity transition
```css
@keyframes fadeIn {
  from { opacity: 0; }
  to   { opacity: 1; }
}
/* Usage: animation: fadeIn 0.3s ease both; */
```

### blink — Terminal cursor blink
```css
@keyframes blink {
  50% { opacity: 0; }
}
/* Usage: animation: blink 1s step-end infinite; */
```

### led-ping — Status LED pulsing ring
```css
@keyframes led-ping {
  0%   { transform: scale(1); opacity: 0.6; }
  100% { transform: scale(2); opacity: 0; }
}
/* Usage: animation: led-ping 2s cubic-bezier(0, 0, 0.2, 1) infinite; */
```

### ping — Status dot pulse
```css
@keyframes ping {
  75%, 100% { transform: scale(1.8); opacity: 0; }
}
/* Usage: animation: ping 2s cubic-bezier(0, 0, 0.2, 1) infinite; */
```

### skeleton-shimmer — Loading skeleton
```css
@keyframes skeleton-shimmer {
  0%   { background-position: -200% 0; }
  100% { background-position: 200% 0; }
}
/* Usage: background: linear-gradient(90deg, rgba(255,255,255,0.04) 25%, rgba(255,255,255,0.08) 50%, rgba(255,255,255,0.04) 75%);
         background-size: 200% 100%;
         animation: skeleton-shimmer 1.5s ease-in-out infinite; */
```

### cq-flow-dash — Animated SVG path flow
```css
@keyframes cq-flow-dash {
  to { stroke-dashoffset: 0; }
}
/* Usage: stroke-dasharray: 6 6; stroke-dashoffset: 48;
         animation: cq-flow-dash 2.6s linear infinite; */
```

### scanline-sweep — CRT scanline effect
```css
@keyframes scanline-sweep {
  0%   { transform: translateY(-100%); }
  100% { transform: translateY(100vh); }
}
/* Usage: animation: scanline-sweep 8s linear infinite; */
```

---

## Framer Motion Patterns

### AnimatedList — Staggered fade-in list items
```tsx
import { motion } from 'framer-motion';

const itemVariants = {
  hidden: { opacity: 0, y: 8, filter: 'blur(4px)' },
  visible: { opacity: 1, y: 0, filter: 'blur(0px)' },
};

<motion.ul initial="hidden" animate="visible">
  {items.map((item, i) => (
    <motion.li
      key={item.id}
      variants={itemVariants}
      transition={{ duration: 0.35, delay: i * 0.035 }}
    >
      {item.content}
    </motion.li>
  ))}
</motion.ul>
```

### BlurText — Scroll-triggered text reveal
```tsx
import { motion } from 'framer-motion';

const wordVariants = {
  hidden: { opacity: 0, filter: 'blur(10px)', y: -50 },
  intermediate: { opacity: 0.5, filter: 'blur(5px)', y: -10 },
  visible: { opacity: 1, filter: 'blur(0px)', y: 0 },
};

// Each word animates from blurred/offset to clear/position
// Stagger by 0.05s per word
```

### DecryptedText — Matrix-style character scramble
```tsx
// Characters cycle through random chars before revealing the final character
// Configurable: direction (start/end/center), sequential mode
// Use for hero text, page titles, or loading states
```

### CountUp — Spring-animated number counter
```tsx
import { useSpring, useTransform, motion, useMotionValue } from 'framer-motion';

const count = useMotionValue(0);
const rounded = useTransform(count, (v) => Math.round(v));
const spring = useSpring(count, { stiffness: 100, damping: 30 });

// Set target: count.set(targetValue)
// Display: <motion.span>{rounded}</motion.span>
```

### FadeInView — Scroll-triggered fade
```tsx
import { useInView, motion } from 'framer-motion';
import { useRef } from 'react';

function FadeInView({ children, className }) {
  const ref = useRef(null);
  const isInView = useInView(ref, { once: true, margin: '-60px' });

  return (
    <motion.div
      ref={ref}
      initial={{ opacity: 0, y: 20 }}
      animate={isInView ? { opacity: 1, y: 0 } : {}}
      transition={{ duration: 0.5, ease: [0.4, 0, 0.2, 1] }}
      className={className}
    >
      {children}
    </motion.div>
  );
}
```

### Page Transitions
```tsx
import { AnimatePresence, motion } from 'framer-motion';

<AnimatePresence mode="wait">
  <motion.div
    key={pathname}
    initial={{ opacity: 0, y: 12 }}
    animate={{ opacity: 1, y: 0 }}
    exit={{ opacity: 0, y: -8 }}
    transition={{ duration: 0.3, ease: [0.4, 0, 0.2, 1] }}
  >
    {pageContent}
  </motion.div>
</AnimatePresence>
```

---

## Interactive Effects

### DepthCard — 3D Tilt with Spotlight
```tsx
// Mouse position → perspective(1100px) + rotateX/rotateY
// Max rotation: 3.5 degrees
// Spotlight: radial-gradient at cursor position, rgba(0,255,157,0.08)
// Top edge: 1px gradient line from transparent through primary/35 to transparent
// Transition: 0.15s for smooth tracking
// Fallback: prefers-reduced-motion disables tilt, keeps spotlight
```

### SpotlightCard — Cursor-Following Glow
```tsx
// Simpler than DepthCard — no 3D tilt, just a spotlight overlay
// Radial gradient follows mouse: rgba(0,255,157,0.10)
// 500ms opacity transition for smooth appearance/disappearance
```

### ClickSpark — Click Ripple Effect
```tsx
// Canvas-based: 8 lines radiate from click point
// Color: #00ff9d
// Duration: 400ms, ease-out
// Lines: 12px length, 2px width, rotate spread
```

---

## WebGL Effects

### Particles — 3D Particle System
```
- Library: OGL (lightweight WebGL)
- Default colors: ['#00ff9d', '#00c2ff', '#a855f7']
- Configurable: particle count, spread radius, speed
- Mouse interaction: particles move away from cursor
- Alpha particles: varying opacity for depth
- Vertex + fragment shaders for GPU-accelerated rendering
```

### SplashCursor — Fluid Simulation
```
- Full Navier-Stokes fluid simulation in WebGL
- Multiple shader programs: advection, divergence, curl, vorticity, pressure, gradient subtract
- Creates colorful ink-splash trails following mouse cursor
- Best used on landing pages or hero sections — heavy on GPU
```

---

## Scroll Effects

### Horizontal Scrolling Cards
```css
@keyframes scroll-left {
  from { transform: translateX(0); }
  to   { transform: translateX(-50%); }
}

@keyframes scroll-right {
  from { transform: translateX(-50%); }
  to   { transform: translateX(0); }
}

/* Apply mask-image for fade edges */
mask-image: linear-gradient(to right, transparent 0%, black 10%, black 90%, transparent 100%);
```

### Scroll Indicator
```tsx
// Bouncing chevron at bottom of hero section
<motion.div
  animate={{ y: [0, 8, 0] }}
  transition={{ duration: 1.5, repeat: Infinity, ease: 'easeInOut' }}
>
  <ChevronDown />
</motion.div>
```

---

## Reduced Motion Support

Always provide fallbacks for users who prefer reduced motion:

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
  .noise-overlay, .grid-overlay {
    display: none;
  }
}
```

```tsx
import { useReducedMotion } from 'framer-motion';

const shouldReduceMotion = useReducedMotion();
// Skip particle effects, 3D tilts, complex animations
// Keep simple opacity transitions
```

---

## Timing Guidelines

| Effect | Duration | Easing |
|--------|----------|--------|
| Hover state | 150–200ms | ease |
| Fade in | 300ms | ease |
| Card entry | 400ms | cubic-bezier(0.4, 0, 0.2, 1) |
| Page transition | 300ms | cubic-bezier(0.4, 0, 0.2, 1) |
| Stagger delay | 35ms per item | — |
| Number counter | spring | stiffness: 100, damping: 30 |
| Scroll reveal | 500ms | ease |
| Status pulse | 2s | cubic-bezier(0, 0, 0.2, 1) |
| Skeleton shimmer | 1.5s | ease-in-out |
