import React, { useRef, useState, useEffect } from "react";
import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

// ─── Utility ────────────────────────────────────────────────────────────────────

function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

// ─── Formatting Helpers ─────────────────────────────────────────────────────────

function formatCurrency(value: number): string {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(value);
}

function formatPercent(value: number): string {
  return `${value >= 0 ? "+" : ""}${value.toFixed(2)}%`;
}

function formatNumber(value: number): string {
  return new Intl.NumberFormat("en-US").format(value);
}

function getPnlColor(value: number): string {
  if (value > 0) return "text-[#00ff9d]";
  if (value < 0) return "text-[#ff3b3b]";
  return "text-[#888888]";
}

function getPnlBg(value: number): string {
  if (value > 0) return "rgba(0,255,157,0.10)";
  if (value < 0) return "rgba(255,59,59,0.10)";
  return "rgba(255,255,255,0.04)";
}

function getPnlBorder(value: number): string {
  if (value > 0) return "rgba(0,255,157,0.20)";
  if (value < 0) return "rgba(255,59,59,0.20)";
  return "rgba(255,255,255,0.08)";
}

// ─── Types ──────────────────────────────────────────────────────────────────────

interface MetricData {
  id: string;
  label: string;
  value: string;
  change: number;
  changeLabel?: string;
  icon: React.ReactNode;
}

interface Breadcrumb {
  label: string;
  href?: string;
}

// ─── Sub-Components ─────────────────────────────────────────────────────────────

/** Terminal-style section label: `// SECTION NAME` */
function SectionLabel({ children }: { children: React.ReactNode }) {
  return (
    <div className="mb-3 font-mono text-[10px] font-medium uppercase tracking-[0.15em] text-[#555555]">
      <span className="text-[#00ff9d]">//</span> {children}
    </div>
  );
}

/** Breadcrumb navigation */
function Breadcrumbs({ items }: { items: Breadcrumb[] }) {
  return (
    <nav className="mb-2 flex items-center gap-1.5 font-mono text-xs text-[#555555]">
      {items.map((crumb, i) => (
        <span key={i} className="flex items-center gap-1.5">
          {i > 0 && (
            <svg
              className="h-3 w-3 text-[#3f3f46]"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              strokeWidth={2}
            >
              <path strokeLinecap="round" strokeLinejoin="round" d="M9 5l7 7-7 7" />
            </svg>
          )}
          {crumb.href ? (
            <a
              href={crumb.href}
              className="transition-colors hover:text-[#888888]"
            >
              {crumb.label}
            </a>
          ) : (
            <span className="text-[#888888]">{crumb.label}</span>
          )}
        </span>
      ))}
    </nav>
  );
}

/** Spotlight card — cursor-following radial glow overlay */
function SpotlightCard({
  children,
  className,
  spotlightColor = "rgba(0,255,157,0.08)",
}: {
  children: React.ReactNode;
  className?: string;
  spotlightColor?: string;
}) {
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
      className={cn(
        "relative overflow-hidden rounded-lg border border-white/[0.05] bg-[rgba(24,24,27,0.55)] backdrop-blur-[14px] backdrop-saturate-120 shadow-[0_1px_3px_rgba(0,0,0,0.3)] transition-colors hover:border-white/[0.09]",
        className
      )}
      onMouseMove={handleMouseMove}
      onMouseEnter={() => setIsHovered(true)}
      onMouseLeave={() => setIsHovered(false)}
    >
      {/* Top edge highlight */}
      <div className="absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-[#00ff9d]/35 to-transparent" />
      {/* Spotlight overlay */}
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

/** Upward arrow icon for positive change */
function ArrowUpIcon({ className }: { className?: string }) {
  return (
    <svg className={cn("h-3 w-3", className)} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M5 15l7-7 7 7" />
    </svg>
  );
}

/** Downward arrow icon for negative change */
function ArrowDownIcon({ className }: { className?: string }) {
  return (
    <svg className={cn("h-3 w-3", className)} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M19 9l-7 7-7-7" />
    </svg>
  );
}

/** Metric icon wrappers */
function WalletIcon() {
  return (
    <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M21 12a2.25 2.25 0 00-2.25-2.25H15a3 3 0 11-6 0H5.25A2.25 2.25 0 003 12m18 0v6a2.25 2.25 0 01-2.25 2.25H5.25A2.25 2.25 0 013 18v-6m18 0V9M3 12V9m18 0a2.25 2.25 0 00-2.25-2.25H5.25A2.25 2.25 0 003 9m18 0V6a2.25 2.25 0 00-2.25-2.25H5.25A2.25 2.25 0 003 6v3" />
    </svg>
  );
}

function TrendingUpIcon() {
  return (
    <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M2.25 18L9 11.25l4.306 4.307a11.95 11.95 0 015.814-5.519l2.74-1.22m0 0l-5.94-2.28m5.94 2.28l-2.28 5.941" />
    </svg>
  );
}

function PositionsIcon() {
  return (
    <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M3.75 6A2.25 2.25 0 016 3.75h2.25A2.25 2.25 0 0110.5 6v2.25a2.25 2.25 0 01-2.25 2.25H6a2.25 2.25 0 01-2.25-2.25V6zM3.75 15.75A2.25 2.25 0 016 13.5h2.25a2.25 2.25 0 012.25 2.25V18a2.25 2.25 0 01-2.25 2.25H6A2.25 2.25 0 013.75 18v-2.25zM13.5 6a2.25 2.25 0 012.25-2.25H18A2.25 2.25 0 0120.25 6v2.25A2.25 2.25 0 0118 10.5h-2.25a2.25 2.25 0 01-2.25-2.25V6zM13.5 15.75a2.25 2.25 0 012.25-2.25H18a2.25 2.25 0 012.25 2.25V18A2.25 2.25 0 0118 20.25h-2.25A2.25 2.25 0 0113.5 18v-2.25z" />
    </svg>
  );
}

function TargetIcon() {
  return (
    <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M12 21a9 9 0 100-18 9 9 0 000 18z" />
      <path strokeLinecap="round" strokeLinejoin="round" d="M12 15a3 3 0 100-6 3 3 0 000 6z" />
    </svg>
  );
}

// ─── Metric Card ────────────────────────────────────────────────────────────────

function MetricCard({
  metric,
  index,
}: {
  metric: MetricData;
  index: number;
}) {
  const isPositive = metric.change > 0;
  const isNegative = metric.change < 0;

  return (
    <SpotlightCard
      className="animate-[fadeInUp_0.4s_cubic-bezier(0.4,0,0.2,1)_both]"
      spotlightColor={
        isPositive
          ? "rgba(0,255,157,0.08)"
          : isNegative
          ? "rgba(255,59,59,0.06)"
          : "rgba(0,255,157,0.06)"
      }
      // Stagger delay via inline style
    >
      <div
        className="p-5"
        style={{ animationDelay: `${index * 80}ms` }}
      >
        {/* Header: icon + label */}
        <div className="mb-4 flex items-center justify-between">
          <SectionLabel>{metric.label}</SectionLabel>
          <div
            className="flex h-7 w-7 items-center justify-center rounded-sm"
            style={{
              background: isPositive
                ? "rgba(0,255,157,0.08)"
                : isNegative
                ? "rgba(255,59,59,0.08)"
                : "rgba(255,255,255,0.04)",
              color: isPositive
                ? "#00ff9d"
                : isNegative
                ? "#ff3b3b"
                : "#888888",
            }}
          >
            {metric.icon}
          </div>
        </div>

        {/* Main value */}
        <div className="mb-2 font-mono text-2xl font-bold tracking-tight text-[#e0e0e0] tabular-nums">
          {metric.value}
        </div>

        {/* Change indicator */}
        <div className="flex items-center gap-2">
          <span
            className="inline-flex items-center gap-1 rounded-sm px-2 py-0.5 font-mono text-[11px] font-medium tabular-nums"
            style={{
              background: getPnlBg(metric.change),
              color: isPositive ? "#00ff9d" : isNegative ? "#ff3b3b" : "#888888",
              border: `1px solid ${getPnlBorder(metric.change)}`,
            }}
          >
            {isPositive ? (
              <ArrowUpIcon />
            ) : isNegative ? (
              <ArrowDownIcon />
            ) : null}
            {formatPercent(metric.change)}
          </span>
          {metric.changeLabel && (
            <span className="font-mono text-[11px] text-[#555555]">
              {metric.changeLabel}
            </span>
          )}
        </div>
      </div>
    </SpotlightCard>
  );
}

// ─── Background Layers ──────────────────────────────────────────────────────────

function BackgroundLayers() {
  return (
    <>
      {/* Mesh gradient */}
      <div
        className="pointer-events-none fixed inset-0 z-0"
        style={{
          background: [
            "radial-gradient(ellipse at 20% 0%, rgba(0,255,157,0.06), transparent 60%)",
            "radial-gradient(ellipse at 80% 100%, rgba(255,184,0,0.04), transparent 60%)",
            "repeating-linear-gradient(0deg, transparent, transparent 2px, rgba(255,255,255,0.008) 2px, rgba(255,255,255,0.008) 4px)",
          ].join(", "),
        }}
      />
      {/* Grid overlay */}
      <div
        className="pointer-events-none fixed inset-0 z-0"
        style={{
          backgroundImage: [
            "linear-gradient(rgba(255,255,255,0.02) 1px, transparent 1px)",
            "linear-gradient(90deg, rgba(255,255,255,0.02) 1px, transparent 1px)",
          ].join(", "),
          backgroundSize: "60px 60px",
        }}
      />
      {/* Noise overlay */}
      <div
        className="pointer-events-none fixed inset-0 z-0 opacity-[0.025]"
        style={{
          backgroundImage:
            "url(\"data:image/svg+xml,%3Csvg viewBox='0 0 256 256' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)'/%3E%3C/svg%3E\")",
          backgroundSize: "256px 256px",
        }}
      />
    </>
  );
}

// ─── Page Header ────────────────────────────────────────────────────────────────

function PageHeader({
  title,
  subtitle,
  breadcrumbs,
}: {
  title: string;
  subtitle?: string;
  breadcrumbs?: Breadcrumb[];
}) {
  return (
    <div className="animate-[fadeInUp_0.4s_cubic-bezier(0.4,0,0.2,1)_both]">
      {breadcrumbs && <Breadcrumbs items={breadcrumbs} />}
      <h1 className="font-['Instrument_Sans',sans-serif] text-2xl font-bold tracking-tight text-[#e0e0e0] md:text-[2rem]">
        {title}
      </h1>
      {subtitle && (
        <p className="mt-1 font-mono text-sm text-[#888888]">{subtitle}</p>
      )}
    </div>
  );
}

// ─── Dashboard Page ─────────────────────────────────────────────────────────────

const METRICS: MetricData[] = [
  {
    id: "balance",
    label: "Total Balance",
    value: formatCurrency(284739.52),
    change: 3.42,
    changeLabel: "24h",
    icon: <WalletIcon />,
  },
  {
    id: "pnl",
    label: "24h PnL",
    value: formatCurrency(9412.8),
    change: 3.42,
    changeLabel: "vs yesterday",
    icon: <TrendingUpIcon />,
  },
  {
    id: "positions",
    label: "Active Positions",
    value: formatNumber(12),
    change: -2.15,
    changeLabel: "avg PnL",
    icon: <PositionsIcon />,
  },
  {
    id: "winrate",
    label: "Win Rate",
    value: "68.4%",
    change: 1.87,
    changeLabel: "30d avg",
    icon: <TargetIcon />,
  },
];

export default function DashboardPage() {
  return (
    <div className="min-h-screen bg-[#0a0a0a] text-[#e0e0e0]">
      <BackgroundLayers />

      {/* Main content area */}
      <div className="relative z-10 mx-auto max-w-7xl px-4 py-8 md:px-8 md:py-12">
        <div className="space-y-8">
          {/* Page header */}
          <PageHeader
            title="Portfolio"
            subtitle="Real-time crypto portfolio overview and performance metrics"
            breadcrumbs={[
              { label: "Home", href: "/" },
              { label: "Dashboard", href: "/dashboard" },
              { label: "Portfolio" },
            ]}
          />

          {/* Metric cards grid */}
          <section>
            <SectionLabel>Portfolio Summary</SectionLabel>
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
              {METRICS.map((metric, index) => (
                <MetricCard key={metric.id} metric={metric} index={index} />
              ))}
            </div>
          </section>
        </div>
      </div>

      {/* Reduced motion support */}
      <style>{`
        @media (prefers-reduced-motion: reduce) {
          *, *::before, *::after {
            animation-duration: 0.01ms !important;
            animation-iteration-count: 1 !important;
            transition-duration: 0.01ms !important;
          }
        }
      `}</style>
    </div>
  );
}
