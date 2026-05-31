import { useState } from 'react';
import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

// ---------------------------------------------------------------------------
// Utilities
// ---------------------------------------------------------------------------

function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

function formatCurrency(value: number): string {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(value);
}

function formatPercent(value: number): string {
  return `${value >= 0 ? '+' : ''}${value.toFixed(2)}%`;
}

function getPnlColor(value: number): string {
  if (value > 0) return 'text-[var(--color-profit)]';
  if (value < 0) return 'text-[var(--color-loss)]';
  return 'text-[var(--color-text-secondary)]';
}

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

type TradeSide = 'buy' | 'sell';
type TradeStatus = 'open' | 'closed';

interface Trade {
  id: string;
  pair: string;
  side: TradeSide;
  entryPrice: number;
  exitPrice: number | null;
  pnl: number | null;
  pnlPercent: number | null;
  status: TradeStatus;
  timestamp: string;
}

interface TradeTableProps {
  trades?: Trade[];
  loading?: boolean;
  className?: string;
}

// ---------------------------------------------------------------------------
// Skeleton Rows
// ---------------------------------------------------------------------------

function SkeletonRow() {
  return (
    <tr className="border-b border-white/[0.04]">
      {Array.from({ length: 6 }).map((_, i) => (
        <td key={i} className="px-4 py-3">
          <div
            className="h-4 rounded-sm animate-[skeleton-shimmer_1.5s_ease-in-out_infinite] bg-gradient-to-r from-white/[0.04] via-white/[0.08] to-white/[0.04] bg-[length:200%_100%]"
            style={{ width: i === 0 ? '80px' : i === 4 ? '64px' : '56px' }}
          />
        </td>
      ))}
    </tr>
  );
}

// ---------------------------------------------------------------------------
// Side Badge
// ---------------------------------------------------------------------------

function SideBadge({ side }: { side: TradeSide }) {
  const isBuy = side === 'buy';

  return (
    <span
      className={cn(
        'inline-flex items-center rounded-sm px-2.5 py-0.5',
        'font-mono text-[11px] font-medium uppercase tracking-[0.04em]',
        'border transition-colors',
        isBuy
          ? 'bg-[var(--color-primary-dim)] text-[var(--color-primary)] border-[rgba(0,255,157,0.20)]'
          : 'bg-[var(--color-danger-dim)] text-[var(--color-danger)] border-[rgba(255,59,59,0.20)]',
      )}
    >
      {side}
    </span>
  );
}

// ---------------------------------------------------------------------------
// Status Dot
// ---------------------------------------------------------------------------

function StatusDot({ status }: { status: TradeStatus }) {
  const isOpen = status === 'open';

  return (
    <span className="inline-flex items-center gap-2">
      <span className="relative flex h-2 w-2">
        {isOpen && (
          <span className="absolute inline-flex h-full w-full rounded-full bg-[var(--color-primary)] opacity-75 animate-ping" />
        )}
        <span
          className={cn(
            'relative inline-flex h-2 w-2 rounded-full',
            isOpen ? 'bg-[var(--color-primary)]' : 'bg-[var(--color-text-muted)]',
          )}
        />
      </span>
      <span
        className={cn(
          'font-mono text-[11px] uppercase tracking-[0.04em]',
          isOpen ? 'text-[var(--color-primary)]' : 'text-[var(--color-text-secondary)]',
        )}
      >
        {status}
      </span>
    </span>
  );
}

// ---------------------------------------------------------------------------
// Table Header
// ---------------------------------------------------------------------------

function TableHeader() {
  const columns = ['Pair', 'Side', 'Entry Price', 'Exit Price', 'PnL', 'Status'];

  return (
    <thead>
      <tr className="border-b border-white/[0.06]">
        {columns.map((col) => (
          <th
            key={col}
            className="px-4 py-3 text-left font-mono text-[10px] font-medium uppercase tracking-[0.15em] text-[var(--color-text-muted)]"
          >
            <span className="text-[var(--color-primary)]">//</span> {col}
          </th>
        ))}
      </tr>
    </thead>
  );
}

// ---------------------------------------------------------------------------
// Trade Row
// ---------------------------------------------------------------------------

function TradeRow({ trade }: { trade: Trade }) {
  const [hovered, setHovered] = useState(false);

  return (
    <tr
      className={cn(
        'border-b border-white/[0.04] transition-colors',
        hovered && 'bg-white/[0.03]',
      )}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
    >
      {/* Pair */}
      <td className="px-4 py-3">
        <span className="font-mono text-[13px] font-medium text-[var(--color-text-primary)] tabular-nums">
          {trade.pair}
        </span>
      </td>

      {/* Side */}
      <td className="px-4 py-3">
        <SideBadge side={trade.side} />
      </td>

      {/* Entry Price */}
      <td className="px-4 py-3">
        <span className="font-mono text-[13px] text-[var(--color-text-primary)] tabular-nums">
          {formatCurrency(trade.entryPrice)}
        </span>
      </td>

      {/* Exit Price */}
      <td className="px-4 py-3">
        {trade.exitPrice !== null ? (
          <span className="font-mono text-[13px] text-[var(--color-text-primary)] tabular-nums">
            {formatCurrency(trade.exitPrice)}
          </span>
        ) : (
          <span className="font-mono text-[13px] text-[var(--color-text-muted)]">&mdash;</span>
        )}
      </td>

      {/* PnL */}
      <td className="px-4 py-3">
        {trade.pnl !== null && trade.pnlPercent !== null ? (
          <div className="flex flex-col">
            <span className={cn('font-mono text-[13px] font-medium tabular-nums', getPnlColor(trade.pnl))}>
              {formatCurrency(trade.pnl)}
            </span>
            <span className={cn('font-mono text-[10px] tabular-nums', getPnlColor(trade.pnlPercent))}>
              {formatPercent(trade.pnlPercent)}
            </span>
          </div>
        ) : (
          <span className="font-mono text-[13px] text-[var(--color-text-muted)]">&mdash;</span>
        )}
      </td>

      {/* Status */}
      <td className="px-4 py-3">
        <StatusDot status={trade.status} />
      </td>
    </tr>
  );
}

// ---------------------------------------------------------------------------
// TradeTable (Main Export)
// ---------------------------------------------------------------------------

const MOCK_TRADES: Trade[] = [
  {
    id: '1',
    pair: 'BTC/USDT',
    side: 'buy',
    entryPrice: 67432.5,
    exitPrice: 68910.0,
    pnl: 1477.5,
    pnlPercent: 2.19,
    status: 'closed',
    timestamp: '2026-05-29T08:12:00Z',
  },
  {
    id: '2',
    pair: 'ETH/USDT',
    side: 'sell',
    entryPrice: 3842.8,
    exitPrice: 3756.2,
    pnl: 86.6,
    pnlPercent: 2.25,
    status: 'closed',
    timestamp: '2026-05-29T09:45:00Z',
  },
  {
    id: '3',
    pair: 'SOL/USDT',
    side: 'buy',
    entryPrice: 172.35,
    exitPrice: 168.9,
    pnl: -3.45,
    pnlPercent: -2.0,
    status: 'closed',
    timestamp: '2026-05-29T10:03:00Z',
  },
  {
    id: '4',
    pair: 'BTC/USDT',
    side: 'buy',
    entryPrice: 68950.0,
    exitPrice: null,
    pnl: null,
    pnlPercent: null,
    status: 'open',
    timestamp: '2026-05-29T11:30:00Z',
  },
  {
    id: '5',
    pair: 'AVAX/USDT',
    side: 'sell',
    entryPrice: 38.72,
    exitPrice: 36.15,
    pnl: 257.0,
    pnlPercent: 6.64,
    status: 'closed',
    timestamp: '2026-05-29T12:15:00Z',
  },
  {
    id: '6',
    pair: 'DOGE/USDT',
    side: 'buy',
    entryPrice: 0.1642,
    exitPrice: null,
    pnl: null,
    pnlPercent: null,
    status: 'open',
    timestamp: '2026-05-29T13:00:00Z',
  },
];

export default function TradeTable({ trades, loading = false, className }: TradeTableProps) {
  const data = trades ?? MOCK_TRADES;

  return (
    <div
      className={cn(
        'rounded-lg border border-white/[0.05] bg-[rgba(24,24,27,0.55)]',
        'backdrop-blur-[14px] backdrop-saturate-120',
        'shadow-[0_1px_3px_rgba(0,0,0,0.3)]',
        'transition-colors hover:border-white/[0.09]',
        'overflow-hidden',
        className,
      )}
    >
      {/* Top edge highlight */}
      <div className="absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-[rgba(0,255,157,0.35)] to-transparent" />

      {/* Table header bar */}
      <div className="flex items-center justify-between border-b border-white/[0.06] px-4 py-3">
        <span className="font-mono text-[10px] font-medium uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
          <span className="text-[var(--color-primary)]">//</span> Recent Trades
        </span>
        <span className="inline-flex items-center gap-1.5">
          <span className="relative flex h-1.5 w-1.5">
            <span className="absolute inline-flex h-full w-full rounded-full bg-[var(--color-primary)] opacity-75 animate-ping" />
            <span className="relative inline-flex h-1.5 w-1.5 rounded-full bg-[var(--color-primary)] shadow-[0_0_6px_rgba(0,255,157,0.5)]" />
          </span>
          <span className="font-mono text-[10px] uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
            live
          </span>
        </span>
      </div>

      {/* Table */}
      <div className="overflow-x-auto">
        <table className="w-full">
          <TableHeader />
          <tbody>
            {loading
              ? Array.from({ length: 5 }).map((_, i) => <SkeletonRow key={i} />)
              : data.map((trade) => <TradeRow key={trade.id} trade={trade} />)}
          </tbody>
        </table>
      </div>
    </div>
  );
}
