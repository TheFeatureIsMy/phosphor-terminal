import React from 'react';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface MetricCard {
  id: string;
  label: string;
  value: string;
  change: number; // percentage, positive = up, negative = down
  changeLabel: string;
  icon: React.ReactNode;
}

// ---------------------------------------------------------------------------
// Inline Icons (avoid external deps)
// ---------------------------------------------------------------------------

const TrendUpIcon = () => (
  <svg width="14" height="14" viewBox="0 0 14 14" fill="none" xmlns="http://www.w3.org/2000/svg">
    <path d="M1 10L5 6L8 9L13 2" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
    <path d="M9 2H13V6" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
  </svg>
);

const TrendDownIcon = () => (
  <svg width="14" height="14" viewBox="0 0 14 14" fill="none" xmlns="http://www.w3.org/2000/svg">
    <path d="M1 4L5 8L8 5L13 12" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
    <path d="M9 12H13V8" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
  </svg>
);

const WalletIcon = () => (
  <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
    <rect x="2" y="6" width="20" height="14" rx="2" />
    <path d="M2 10h20" />
    <circle cx="17" cy="15" r="1.5" fill="currentColor" stroke="none" />
  </svg>
);

const BarChartIcon = () => (
  <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
    <rect x="3" y="12" width="4" height="9" rx="1" />
    <rect x="10" y="6" width="4" height="15" rx="1" />
    <rect x="17" y="2" width="4" height="19" rx="1" />
  </svg>
);

const PositionsIcon = () => (
  <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
    <path d="M12 2L2 7l10 5 10-5-10-5z" />
    <path d="M2 17l10 5 10-5" />
    <path d="M2 12l10 5 10-5" />
  </svg>
);

const TrophyIcon = () => (
  <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
    <path d="M6 9H4a2 2 0 01-2-2V5h4" />
    <path d="M18 9h2a2 2 0 002-2V5h-4" />
    <path d="M4 5h16v4a6 6 0 01-12 0V5z" />
    <path d="M12 15v3" />
    <path d="M8 22h8" />
    <path d="M9 19h6" />
  </svg>
);

const ChevronRightIcon = () => (
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <path d="M9 18l6-6-6-6" />
  </svg>
);

// ---------------------------------------------------------------------------
// Data
// ---------------------------------------------------------------------------

const METRICS: MetricCard[] = [
  {
    id: 'balance',
    label: 'Total Balance',
    value: '$284,912.56',
    change: 3.42,
    changeLabel: 'vs last 24h',
    icon: <WalletIcon />,
  },
  {
    id: 'pnl',
    label: '24h PnL',
    value: '+$8,241.30',
    change: 1.87,
    changeLabel: 'vs yesterday',
    icon: <BarChartIcon />,
  },
  {
    id: 'positions',
    label: 'Active Positions',
    value: '14',
    change: -2.5,
    changeLabel: 'vs last week',
    icon: <PositionsIcon />,
  },
  {
    id: 'winrate',
    label: 'Win Rate',
    value: '68.4%',
    change: 4.1,
    changeLabel: 'vs last 30d',
    icon: <TrophyIcon />,
  },
];

// ---------------------------------------------------------------------------
// Sub-components
// ---------------------------------------------------------------------------

interface BreadcrumbItem {
  label: string;
  href?: string;
}

const Breadcrumbs: React.FC<{ items: BreadcrumbItem[] }> = ({ items }) => (
  <nav aria-label="Breadcrumb" className="flex items-center gap-1.5 text-sm">
    {items.map((item, i) => (
      <React.Fragment key={item.label}>
        {i > 0 && <ChevronRightIcon />}
        {item.href ? (
          <a
            href={item.href}
            className="text-zinc-400 transition-colors hover:text-white"
          >
            {item.label}
          </a>
        ) : (
          <span className="font-medium text-zinc-100">{item.label}</span>
        )}
      </React.Fragment>
    ))}
  </nav>
);

const ChangeBadge: React.FC<{ value: number }> = ({ value }) => {
  const positive = value >= 0;
  return (
    <span
      className={`inline-flex items-center gap-1 rounded-full px-2.5 py-0.5 text-xs font-medium ${
        positive
          ? 'bg-emerald-500/10 text-emerald-400'
          : 'bg-red-500/10 text-red-400'
      }`}
    >
      {positive ? <TrendUpIcon /> : <TrendDownIcon />}
      {positive ? '+' : ''}
      {value.toFixed(2)}%
    </span>
  );
};

const MetricCardView: React.FC<{ metric: MetricCard; index: number }> = ({
  metric,
  index,
}) => {
  const positive = metric.change >= 0;
  return (
    <article
      className="group relative overflow-hidden rounded-2xl border border-white/[0.06] bg-gradient-to-br from-white/[0.04] to-white/[0.01] p-5 backdrop-blur-sm transition-all duration-300 hover:border-white/[0.12] hover:shadow-lg hover:shadow-black/20 sm:p-6"
      style={{ animationDelay: `${index * 75}ms` }}
    >
      {/* Glow on hover */}
      <div
        className={`pointer-events-none absolute -right-8 -top-8 h-32 w-32 rounded-full opacity-0 blur-2xl transition-opacity duration-500 group-hover:opacity-100 ${
          positive ? 'bg-emerald-500/20' : 'bg-red-500/20'
        }`}
      />

      {/* Header: icon + label */}
      <div className="mb-4 flex items-center gap-3">
        <div
          className={`flex h-9 w-9 items-center justify-center rounded-lg ${
            positive
              ? 'bg-emerald-500/10 text-emerald-400'
              : 'bg-red-500/10 text-red-400'
          }`}
        >
          {metric.icon}
        </div>
        <span className="text-sm font-medium text-zinc-400">
          {metric.label}
        </span>
      </div>

      {/* Value */}
      <p className="mb-2 text-2xl font-bold tracking-tight text-white sm:text-3xl">
        {metric.value}
      </p>

      {/* Change + label */}
      <div className="flex items-center gap-2">
        <ChangeBadge value={metric.change} />
        <span className="text-xs text-zinc-500">{metric.changeLabel}</span>
      </div>
    </article>
  );
};

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

const BREADCRUMBS: BreadcrumbItem[] = [
  { label: 'Home', href: '/' },
  { label: 'Portfolio' },
];

const DashboardPage: React.FC = () => {
  return (
    <div className="min-h-screen bg-[#09090b] text-white antialiased">
      {/* Ambient glow */}
      <div className="pointer-events-none fixed inset-0 overflow-hidden">
        <div className="absolute -left-40 -top-40 h-[600px] w-[600px] rounded-full bg-emerald-600/[0.04] blur-[120px]" />
        <div className="absolute -bottom-40 -right-40 h-[500px] w-[500px] rounded-full bg-cyan-600/[0.03] blur-[120px]" />
      </div>

      <div className="relative mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        {/* Header */}
        <header className="mb-10">
          <Breadcrumbs items={BREADCRUMBS} />
          <div className="mt-4 flex flex-col gap-1 sm:flex-row sm:items-end sm:justify-between">
            <div>
              <h1 className="text-2xl font-bold tracking-tight sm:text-3xl">
                Portfolio Overview
              </h1>
              <p className="mt-1 text-sm text-zinc-500">
                Real-time performance across all connected exchanges
              </p>
            </div>
            <span className="mt-2 inline-flex w-fit items-center gap-2 rounded-full border border-white/[0.06] bg-white/[0.03] px-3 py-1 text-xs text-zinc-400 sm:mt-0">
              <span className="relative flex h-2 w-2">
                <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-emerald-400 opacity-75" />
                <span className="relative inline-flex h-2 w-2 rounded-full bg-emerald-500" />
              </span>
              Live
            </span>
          </div>
        </header>

        {/* Metric cards — responsive grid */}
        <section
          className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4"
          aria-label="Portfolio metrics"
        >
          {METRICS.map((metric, i) => (
            <MetricCardView key={metric.id} metric={metric} index={i} />
          ))}
        </section>
      </div>
    </div>
  );
};

export default DashboardPage;
