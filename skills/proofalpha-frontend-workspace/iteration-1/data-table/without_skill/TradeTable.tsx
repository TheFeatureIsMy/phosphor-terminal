import React, { useState } from "react";

// ─── Types ───────────────────────────────────────────────────────────────────

type TradeSide = "buy" | "sell";
type TradeStatus = "open" | "closed" | "pending";

interface Trade {
  id: string;
  pair: string;
  side: TradeSide;
  entryPrice: number;
  exitPrice: number | null;
  pnl: number | null;
  status: TradeStatus;
  timestamp: string;
}

interface TradeTableProps {
  trades?: Trade[];
  loading?: boolean;
  skeletonRows?: number;
}

// ─── Color Tokens (ProofAlpha Design System) ─────────────────────────────────

const COLORS = {
  bg: "#0A0A0A",
  surface: "rgba(255,255,255,0.04)",
  surfaceElevated: "rgba(255,255,255,0.06)",
  surfaceHover: "rgba(255,255,255,0.08)",
  border: "rgba(255,255,255,0.08)",
  borderHover: "rgba(255,255,255,0.16)",
  accent: "#00FF9D",
  accentDim: "rgba(0,255,157,0.10)",
  profit: "#00FF9D",
  loss: "#FF3B3B",
  textPrimary: "#E0E0E0",
  textSecondary: "#888888",
  textMuted: "#555555",
  warning: "#FFB800",
  info: "#00C2FF",
} as const;

// ─── Skeleton Component ──────────────────────────────────────────────────────

function SkeletonRow({ index }: { index: number }) {
  const widths = ["w-20", "w-12", "w-24", "w-24", "w-16", "w-16"];
  return (
    <tr
      className="border-b transition-colors"
      style={{
        borderColor: COLORS.border,
        animationDelay: `${index * 80}ms`,
      }}
    >
      {widths.map((w, i) => (
        <td key={i} className="px-4 py-3">
          <div
            className={`${w} h-4 rounded-sm animate-pulse`}
            style={{ background: COLORS.surfaceElevated }}
          />
        </td>
      ))}
    </tr>
  );
}

// ─── Side Badge ──────────────────────────────────────────────────────────────

function SideBadge({ side }: { side: TradeSide }) {
  const isBuy = side === "buy";
  return (
    <span
      className="inline-flex items-center gap-1 rounded-sm px-2 py-0.5 font-mono text-[11px] font-medium uppercase tracking-wider"
      style={{
        background: isBuy ? COLORS.accentDim : "rgba(255,59,59,0.10)",
        color: isBuy ? COLORS.accent : COLORS.loss,
        border: `1px solid ${isBuy ? "rgba(0,255,157,0.20)" : "rgba(255,59,59,0.20)"}`,
      }}
    >
      <span
        className="inline-block h-1.5 w-1.5 rounded-full"
        style={{ background: isBuy ? COLORS.accent : COLORS.loss }}
      />
      {side}
    </span>
  );
}

// ─── Status Dot ──────────────────────────────────────────────────────────────

function StatusDot({ status }: { status: TradeStatus }) {
  const config: Record<TradeStatus, { color: string; label: string; pulse: boolean }> = {
    open: { color: COLORS.accent, label: "Open", pulse: true },
    closed: { color: COLORS.textMuted, label: "Closed", pulse: false },
    pending: { color: COLORS.warning, label: "Pending", pulse: true },
  };
  const { color, label, pulse } = config[status];

  return (
    <span className="inline-flex items-center gap-2 font-mono text-[11px]">
      <span className="relative flex h-2.5 w-2.5 items-center justify-center">
        {pulse && (
          <span
            className="absolute inline-flex h-full w-full animate-ping rounded-full opacity-40"
            style={{ background: color }}
          />
        )}
        <span
          className="relative inline-flex h-2 w-2 rounded-full"
          style={{ background: color }}
        />
      </span>
      <span style={{ color: COLORS.textSecondary }}>{label}</span>
    </span>
  );
}

// ─── PnL Cell ────────────────────────────────────────────────────────────────

function PnLCell({ pnl }: { pnl: number | null }) {
  if (pnl === null || pnl === undefined) {
    return (
      <span className="font-mono text-[13px]" style={{ color: COLORS.textMuted }}>
        --
      </span>
    );
  }
  const isProfit = pnl >= 0;
  return (
    <span
      className="font-mono text-[13px] font-medium tabular-nums"
      style={{ color: isProfit ? COLORS.profit : COLORS.loss }}
    >
      {isProfit ? "+" : ""}
      {pnl.toFixed(2)}%
    </span>
  );
}

// ─── Price Cell ──────────────────────────────────────────────────────────────

function PriceCell({ value }: { value: number | null }) {
  if (value === null || value === undefined) {
    return (
      <span className="font-mono text-[13px]" style={{ color: COLORS.textMuted }}>
        --
      </span>
    );
  }
  return (
    <span className="font-mono text-[13px] tabular-nums" style={{ color: COLORS.textPrimary }}>
      ${value.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
    </span>
  );
}

// ─── Column Definitions ──────────────────────────────────────────────────────

const COLUMNS = [
  { key: "pair", label: "Pair", align: "left" as const },
  { key: "side", label: "Side", align: "left" as const },
  { key: "entryPrice", label: "Entry Price", align: "right" as const },
  { key: "exitPrice", label: "Exit Price", align: "right" as const },
  { key: "pnl", label: "PnL", align: "right" as const },
  { key: "status", label: "Status", align: "left" as const },
];

// ─── Main Component ──────────────────────────────────────────────────────────

export default function TradeTable({
  trades = [],
  loading = false,
  skeletonRows = 6,
}: TradeTableProps) {
  const [hoveredRow, setHoveredRow] = useState<string | null>(null);

  return (
    <div
      className="w-full overflow-hidden rounded-lg border font-mono"
      style={{
        background: COLORS.surface,
        borderColor: COLORS.border,
      }}
    >
      {/* ─── Header ─── */}
      <div className="overflow-x-auto">
        <table className="w-full border-collapse">
          <thead>
            <tr
              style={{
                background: COLORS.surfaceElevated,
                borderBottom: `1px solid ${COLORS.border}`,
              }}
            >
              {COLUMNS.map((col) => (
                <th
                  key={col.key}
                  className={`px-4 py-3 text-[11px] font-medium uppercase tracking-widest ${
                    col.align === "right" ? "text-right" : "text-left"
                  }`}
                  style={{ color: COLORS.textMuted }}
                >
                  {col.label}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {/* ─── Loading Skeleton ─── */}
            {loading &&
              Array.from({ length: skeletonRows }).map((_, i) => (
                <SkeletonRow key={`skeleton-${i}`} index={i} />
              ))}

            {/* ─── Data Rows ─── */}
            {!loading &&
              trades.map((trade) => {
                const isHovered = hoveredRow === trade.id;
                return (
                  <tr
                    key={trade.id}
                    className="cursor-pointer border-b transition-colors duration-150"
                    style={{
                      borderColor: COLORS.border,
                      background: isHovered ? COLORS.surfaceHover : "transparent",
                    }}
                    onMouseEnter={() => setHoveredRow(trade.id)}
                    onMouseLeave={() => setHoveredRow(null)}
                  >
                    {/* Pair */}
                    <td className="px-4 py-3">
                      <span
                        className="text-[13px] font-medium"
                        style={{ color: COLORS.textPrimary }}
                      >
                        {trade.pair}
                      </span>
                    </td>

                    {/* Side */}
                    <td className="px-4 py-3">
                      <SideBadge side={trade.side} />
                    </td>

                    {/* Entry Price */}
                    <td className="px-4 py-3 text-right">
                      <PriceCell value={trade.entryPrice} />
                    </td>

                    {/* Exit Price */}
                    <td className="px-4 py-3 text-right">
                      <PriceCell value={trade.exitPrice} />
                    </td>

                    {/* PnL */}
                    <td className="px-4 py-3 text-right">
                      <PnLCell pnl={trade.pnl} />
                    </td>

                    {/* Status */}
                    <td className="px-4 py-3">
                      <StatusDot status={trade.status} />
                    </td>
                  </tr>
                );
              })}

            {/* ─── Empty State ─── */}
            {!loading && trades.length === 0 && (
              <tr>
                <td colSpan={COLUMNS.length} className="px-4 py-16 text-center">
                  <div className="flex flex-col items-center gap-2">
                    <svg
                      className="h-8 w-8"
                      style={{ color: COLORS.textMuted }}
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                      strokeWidth={1.5}
                    >
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        d="M3 10h18M3 14h18M3 6h18M3 18h18"
                      />
                    </svg>
                    <span
                      className="font-mono text-[12px]"
                      style={{ color: COLORS.textMuted }}
                    >
                      No trades found
                    </span>
                  </div>
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      {/* ─── Footer ─── */}
      {!loading && trades.length > 0 && (
        <div
          className="flex items-center justify-between px-4 py-2.5"
          style={{
            borderTop: `1px solid ${COLORS.border}`,
            background: COLORS.surface,
          }}
        >
          <span className="font-mono text-[11px]" style={{ color: COLORS.textMuted }}>
            {trades.length} trade{trades.length !== 1 ? "s" : ""}
          </span>
          <span className="font-mono text-[11px]" style={{ color: COLORS.textMuted }}>
            {trades.filter((t) => t.status === "open").length} open
          </span>
        </div>
      )}
    </div>
  );
}
