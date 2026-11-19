import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import type { DeskCandle } from "@/components/desk/DeskChart";
import { useLiveReadiness } from "@/lib/hooks";

export interface DeskFacts {
  price: number | null;
  change: number | null;
  asOf: number | null;
  candles: DeskCandle[];
  candleError: boolean;
  running: boolean;
  strategy: string;
  timeframe: string;
  venue: string;
  openTrades: number;
  closedTrades: number;
  total: number | null;
  balances: { currency: string; balance: number }[];
  stake: string;
  backtest: { id: number; trades: number; win: string; ret: string; range: string } | null;
  gates: { label: string; detail: string }[];
  liveAllowed: boolean;
}

function percent(value: number | null | undefined): string {
  if (value == null || Number.isNaN(Number(value))) return "—";
  const n = Number(value);
  const pct = Math.abs(n) <= 1 ? n * 100 : n;
  return `${pct >= 0 ? "+" : ""}${pct.toFixed(2)}%`;
}

function winRate(value: number | null | undefined): string {
  if (value == null || Number.isNaN(Number(value))) return "—";
  const n = Number(value);
  return `${(n <= 1 ? n * 100 : n).toFixed(1)}%`;
}

export function useDeskFacts(): DeskFacts {
  const candles = useQuery({
    queryKey: ["preview", "candles"],
    queryFn: () => api.get<{ candles: DeskCandle[] }>("/api/v2/trace/candles?timeframe=15m"),
    refetchInterval: 30_000,
  });
  const tick = useQuery({
    queryKey: ["preview", "tick"],
    queryFn: () => api.get<{ price: number; now: number }>("/api/v2/trace/tick?timeframe=15m"),
    refetchInterval: 2_000,
  });
  const process = useQuery({
    queryKey: ["preview", "demo"],
    queryFn: () =>
      api.get<{
        reachable: boolean;
        strategy: string | null;
        timeframe: string | null;
        venue: string;
        open_trades: number;
        closed_trades: number;
        total: number | null;
        stake_amount: string | null;
        stake_currency: string | null;
        balances: { currency: string; balance: number }[];
      }>("/api/trading/demo-process"),
    refetchInterval: 5_000,
  });
  const backtests = useQuery({
    queryKey: ["preview", "backtest"],
    queryFn: () =>
      api.get<{ id: number; symbols: string[]; total_trades: number; win_rate: number; total_return: number; start_date: string; end_date: string }[]>(
        "/api/v2/backtest?summary=true&limit=1",
      ),
  });
  const readiness = useLiveReadiness();
  const bars = candles.data?.candles ?? [];
  const prev = bars.at(-2);
  const price = tick.data?.price ?? bars.at(-1)?.close ?? null;
  const latest = backtests.data?.[0];
  const failed = (readiness.data?.checks ?? []).filter((c) => c.status === "failed" || c.status === "warning");
  return {
    price,
    change: price != null && prev ? price - prev.close : null,
    asOf: tick.data?.now ?? null,
    candles: bars,
    candleError: candles.isError,
    running: Boolean(process.data?.reachable),
    strategy: process.data?.strategy ?? "PulseDeskUniversalStrategy",
    timeframe: process.data?.timeframe ?? "15m",
    venue: process.data?.venue === "binance_demo" ? "币安 Demo" : "模拟",
    openTrades: process.data?.open_trades ?? 0,
    closedTrades: process.data?.closed_trades ?? 0,
    total: process.data?.total ?? null,
    balances: process.data?.balances ?? [],
    stake: process.data?.stake_amount ? `${process.data.stake_amount} ${process.data.stake_currency ?? ""}` : "100 USDT",
    backtest: latest
      ? {
          id: latest.id,
          trades: latest.total_trades,
          win: winRate(latest.win_rate),
          ret: percent(latest.total_return),
          range: `${latest.start_date} 到 ${latest.end_date}`,
        }
      : null,
    gates: failed.slice(0, 4).map((c) => ({ label: c.label, detail: c.detail || c.value })),
    liveAllowed: Boolean(readiness.data?.can_start_live_small),
  };
}

export function money(value: number | null | undefined): string {
  if (value == null || Number.isNaN(Number(value))) return "—";
  return value.toLocaleString("zh-CN", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}
