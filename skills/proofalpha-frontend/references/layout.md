# Layout Patterns

## AppShell — Full Application Layout

The root layout. Three background layers, fixed sidebar, fixed topbar, scrollable content.

```tsx
export function AppShell({ children }: { children: React.ReactNode }) {
  return (
    <div className="h-dvh overflow-hidden bg-background text-text-primary">
      {/* Background layers */}
      <div className="bg-mesh" />
      <div className="grid-overlay" />
      <div className="noise-overlay" />

      {/* Sidebar */}
      <Sidebar />

      {/* TopBar — spans from sidebar to right edge */}
      <TopBar />

      {/* Main content */}
      <main className="fixed left-[232px] top-12 right-0 bottom-0 overflow-y-auto p-8">
        {children}
      </main>
    </div>
  );
}
```

### Key CSS
```css
.bg-mesh {
  position: fixed; inset: 0; z-index: 0; pointer-events: none;
  background:
    radial-gradient(ellipse at 20% 0%, rgba(0,255,157,0.06), transparent 60%),
    radial-gradient(ellipse at 80% 100%, rgba(255,184,0,0.04), transparent 60%),
    repeating-linear-gradient(0deg, transparent, transparent 2px, rgba(255,255,255,0.008) 2px, rgba(255,255,255,0.008) 4px);
}

.grid-overlay {
  position: fixed; inset: 0; z-index: 0; pointer-events: none;
  background-image:
    linear-gradient(rgba(255,255,255,0.02) 1px, transparent 1px),
    linear-gradient(90deg, rgba(255,255,255,0.02) 1px, transparent 1px);
  background-size: 60px 60px;
}

.noise-overlay {
  position: fixed; inset: 0; z-index: 0; pointer-events: none;
  opacity: 0.025;
  background-image: url("data:image/svg+xml,%3Csvg viewBox='0 0 256 256' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)'/%3E%3C/svg%3E");
  background-size: 256px 256px;
}
```

---

## Sidebar

Fixed left panel, 232px wide, full viewport height.

```tsx
export function Sidebar() {
  return (
    <aside className="fixed left-0 top-0 bottom-0 w-[232px] z-30
                      border-r border-white/[0.06]
                      bg-[rgba(12,12,14,0.65)] backdrop-blur-[20px] backdrop-saturate-140">
      {/* Logo */}
      <div className="flex h-12 items-center px-4 border-b border-white/[0.06]">
        <ProductLogo />
      </div>

      {/* Navigation sections */}
      <nav className="flex-1 overflow-y-auto px-2 py-4 space-y-6">
        {/* Section with label */}
        <div>
          <div className="px-3 mb-2 font-mono text-[9px] font-medium uppercase tracking-[0.15em] text-[#3f3f46]">
            Trading
          </div>
          <NavItem icon={BarChart3} label="Dashboard" active />
          <NavItem icon={TrendingUp} label="Strategies" />
          <NavItem icon={Activity} label="Backtest" />
        </div>
      </nav>

      {/* Bottom: status + language toggle */}
      <div className="border-t border-white/[0.06] p-3">
        <StatusIndicator />
      </div>
    </aside>
  );
}

function NavItem({ icon: Icon, label, active, badge }: NavItemProps) {
  return (
    <button className={cn(
      'flex w-full items-center gap-2.5 rounded-sm px-3 py-1.5 text-xs transition-colors',
      active
        ? 'bg-primary/[0.08] text-primary border-l-2 border-primary'
        : 'text-text-secondary hover:bg-surface-hover hover:text-text-primary'
    )}>
      <Icon className="h-4 w-4" />
      <span>{label}</span>
      {badge && <NavBadge variant={badge.variant}>{badge.label}</NavBadge>}
    </button>
  );
}
```

### Sidebar Specs
| Property | Value |
|----------|-------|
| Width | 232px (fixed) |
| Background | `rgba(12, 12, 14, 0.65)` |
| Blur | `blur(20px) saturate(140%)` |
| Border | `border-r border-white/[0.06]` |
| Section label | 9px, uppercase, `#3f3f46` |
| Nav item font | 12px, IBM Plex Mono |
| Active state | Green bg, green left border, green text |

---

## TopBar

Fixed top bar, 48px tall, spans from sidebar right edge to viewport right.

```tsx
export function TopBar() {
  return (
    <header className="fixed left-[232px] top-0 right-0 h-12 z-20
                       flex items-center justify-between px-4
                       border-b border-white/[0.06]
                       bg-[rgba(12,12,14,0.65)] backdrop-blur-[20px] backdrop-saturate-140">
      {/* Left: Breadcrumb */}
      <Breadcrumb />

      {/* Right: System metrics + Clock + Actions */}
      <div className="flex items-center gap-3">
        <SystemMetrics />    {/* CPU/MEM/NET bars */}
        <TerminalClock />     {/* HH:MM:SS with blinking colon */}
        <StatusLED />
        <LanguageToggle />
        <SearchButton />
        <NotificationBell />
        <UserMenu />
      </div>
    </header>
  );
}
```

### TopBar Specs
| Property | Value |
|----------|-------|
| Height | 48px |
| Left offset | 232px (sidebar width) |
| Background | Same as sidebar |
| Border | `border-b border-white/[0.06]` |
| Content | Right-aligned, gap-3 between items |

### Terminal Clock
```tsx
function TerminalClock() {
  const [time, setTime] = useState(new Date());
  useEffect(() => {
    const interval = setInterval(() => setTime(new Date()), 1000);
    return () => clearInterval(interval);
  }, []);

  const formatted = time.toLocaleTimeString('en-US', { hour12: false });
  // Render with blinking colon: "14" <span className="animate-blink">:</span> "32" <span className="animate-blink">:</span> "07"
}
```

---

## Page Layout

All authenticated pages follow this pattern:

```tsx
export default function SomePage() {
  return (
    <div className="space-y-5">
      {/* Page Header */}
      <PageHeader
        title="Dashboard"
        subtitle="Real-time portfolio overview"
        breadcrumbs={[
          { label: 'Home', href: '/' },
          { label: 'Dashboard' },
        ]}
        actions={
          <Button variant="primary">
            <Plus className="h-4 w-4" />
            New Strategy
          </Button>
        }
      />

      {/* Content sections */}
      <section>
        <SectionLabel>Portfolio Summary</SectionLabel>
        <div className="grid grid-cols-3 gap-4">
          <MetricCard />
          <MetricCard />
          <MetricCard />
        </div>
      </section>

      <section>
        <SectionLabel>Recent Activity</SectionLabel>
        <Card>
          {/* Table or list */}
        </Card>
      </section>
    </div>
  );
}
```

### PageHeader Component
```tsx
interface PageHeaderProps {
  title: string;
  subtitle?: string;
  breadcrumbs?: { label: string; href?: string }[];
  actions?: React.ReactNode;
}

export function PageHeader({ title, subtitle, breadcrumbs, actions }: PageHeaderProps) {
  return (
    <div className="flex items-start justify-between">
      <div>
        {breadcrumbs && (
          <nav className="mb-2 flex items-center gap-1.5 font-mono text-xs text-text-muted">
            {breadcrumbs.map((crumb, i) => (
              <span key={i} className="flex items-center gap-1.5">
                {i > 0 && <ChevronRight className="h-3 w-3" />}
                {crumb.href ? (
                  <Link to={crumb.href} className="hover:text-text-secondary transition-colors">
                    {crumb.label}
                  </Link>
                ) : (
                  <span className="text-text-secondary">{crumb.label}</span>
                )}
              </span>
            ))}
          </nav>
        )}
        <h1 className="font-display text-2xl font-bold tracking-tight">{title}</h1>
        {subtitle && <p className="mt-1 font-mono text-sm text-text-secondary">{subtitle}</p>}
      </div>
      {actions && <div className="flex items-center gap-2">{actions}</div>}
    </div>
  );
}
```

### SectionLabel Component
```tsx
export function SectionLabel({ children }: { children: React.ReactNode }) {
  return (
    <div className="mb-3 font-mono text-[10px] font-medium uppercase tracking-[0.15em] text-text-muted">
      <span className="text-primary">//</span> {children}
    </div>
  );
}
```

---

## Grid Patterns

### Metric Cards Row
```tsx
<div className="grid grid-cols-2 gap-4 md:grid-cols-3 lg:grid-cols-4">
  {metrics.map((m) => (
    <Card key={m.label}>
      <SectionLabel>{m.label}</SectionLabel>
      <div className="font-mono text-2xl font-bold tabular-nums">{m.value}</div>
      <div className={cn('font-mono text-xs tabular-nums', getPnlColor(m.change))}>
        {formatPercent(m.change)}
      </div>
    </Card>
  ))}
</div>
```

### Two-Column Layout
```tsx
<div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
  <Card>{/* Left panel */}</Card>
  <Card>{/* Right panel */}</Card>
</div>
```

### Sidebar + Content Layout (within a page)
```tsx
<div className="flex gap-4">
  <aside className="w-64 shrink-0">
    <Card>{/* Filter/sidebar content */}</Card>
  </aside>
  <div className="flex-1 min-w-0">
    <Card>{/* Main content */}</Card>
  </div>
</div>
```

---

## Responsive Considerations

- Sidebar collapses to icons on small screens (64px width)
- TopBar height stays 48px
- Content padding reduces from 32px to 16px on mobile
- Grid columns reduce: `grid-cols-3` → `grid-cols-2` → `grid-cols-1`
- Font sizes scale down slightly on mobile
- DepthCard tilt effect disabled on touch devices
