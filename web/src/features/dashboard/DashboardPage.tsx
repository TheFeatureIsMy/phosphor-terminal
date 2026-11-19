import { Link } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { PageHeader } from "@/components/shell/PageHeader";
import { VoltCard } from "@/components/shell/VoltCard";
import { DeskChart, type DeskCandle } from "@/components/desk/DeskChart";
import { useLiveReadiness, useOrdersPositions } from "@/lib/hooks";

interface DemoProcess {
  reachable: boolean;
  state: string;
  strategy: string | null;
  timeframe: string | null;
  venue: string;
  stake_amount: string | null;
  stake_currency: string | null;
  max_open_trades: number | null;
  open_trades: number;
  closed_trades: number;
  total: number | null;
  balances: { currency: string; balance: number }[];
}

interface BacktestRow {
  id: number;
  status: string;
  symbols: string[];
  total_trades: number;
  win_rate: number;
  total_return: number;
  start_date: string;
  end_date: string;
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

function money(value: number | null | undefined): string {
  if (value == null || Number.isNaN(Number(value))) return "—";
  return value.toLocaleString("zh-CN", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-baseline justify-between gap-3 border-b border-border/60 py-2 last:border-0">
      <span className="text-[12px] text-text-2">{label}</span>
      <span className="tnum font-mono text-[13px] font-semibold text-text">{value}</span>
    </div>
  );
}

export default function DashboardPage() {
  const candles = useQuery({
    queryKey: ["desk", "candles", "15m"],
    queryFn: () => api.get<{ candles: DeskCandle[] }>("/api/v2/trace/candles?timeframe=15m"),
    refetchInterval: 30_000,
  });
  const tick = useQuery({
    queryKey: ["desk", "tick", "15m"],
    queryFn: () => api.get<{ price: number; now: number }>("/api/v2/trace/tick?timeframe=15m"),
    refetchInterval: 2_000,
  });
  const process = useQuery({
    queryKey: ["trading", "demo-process"],
    queryFn: () => api.get<DemoProcess>("/api/trading/demo-process"),
    refetchInterval: 5_000,
  });
  const backtests = useQuery({
    queryKey: ["backtest", "list", "desk"],
    queryFn: () => api.get<BacktestRow[]>("/api/v2/backtest?summary=true&limit=1"),
    refetchInterval: 15_000,
  });
  const readiness = useLiveReadiness();
  const book = useOrdersPositions();

  const bars = candles.data?.candles ?? [];
  const prev = bars.at(-2);
  const price = tick.data?.price ?? bars.at(-1)?.close ?? null;
  const change = price != null && prev ? price - prev.close : null;
  const latest = backtests.data?.[0];
  const positions = book.data?.positions ?? [];
  const failed = (readiness.data?.checks ?? []).filter(
    (check) => check.status === "failed" || check.status === "warning",
  );
  const venue = process.data?.venue === "binance_demo" ? "币安 Demo" : "模拟进程";

  return (
    <div className="mx-auto flex w-full max-w-[1440px] flex-col gap-4 px-7 py-6">
      <PageHeader
        eyebrow="DESK"
        title="总览"
        subtitle="15 分钟行情、正在跑的模拟，以及还没通过的实盘门禁"
      />

      <div className="grid grid-cols-1 items-start gap-4 xl:grid-cols-[minmax(0,1fr)_320px]">
        <VoltCard className="overflow-hidden">
          <div className="flex items-end justify-between gap-4 border-b border-border px-5 py-4">
            <div>
              <div className="font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-3">
                BTC/USDT · 15 分钟 · 币安公开行情
              </div>
              <div className="mt-1 flex items-baseline gap-3">
                <span className="tnum font-display text-[32px] font-black leading-none text-text">
                  {price == null ? "—" : money(price)}
                </span>
                <span className={`tnum font-mono text-[13px] font-semibold ${change == null ? "text-text-3" : change >= 0 ? "text-bull" : "text-bear"}`}>
                  {change == null ? "等待报价" : `${change >= 0 ? "+" : ""}${change.toFixed(2)}`}
                </span>
              </div>
            </div>
            <div className="font-mono text-[11px] text-text-3">
              {tick.data?.now ? new Date(tick.data.now * 1000).toLocaleTimeString("zh-CN", { hour12: false }) : ""}
            </div>
          </div>
          <div className="h-[480px]">
            {candles.isError ? (
              <div className="px-5 py-8 text-[13px] text-text-2">K 线没有取到。刷新页面再试。</div>
            ) : (
              <DeskChart candles={bars} />
            )}
          </div>
        </VoltCard>

        <div className="flex flex-col gap-4">
          <VoltCard className="p-5">
            <div className="flex items-center justify-between">
              <div className="font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-3">{venue}</div>
              <span className={`rounded-md px-2 py-0.5 text-[11px] font-semibold ${process.data?.reachable ? "bg-bull/12 text-bull" : "bg-bear/12 text-bear"}`}>
                {process.data?.reachable ? "运行中" : "未连接"}
              </span>
            </div>
            <div className="mt-2 text-[14px] font-semibold text-text">
              {process.data?.strategy ?? "—"}
              <span className="ml-2 font-mono text-[12px] font-medium text-text-2">{process.data?.timeframe ?? ""}</span>
            </div>
            <div className="mt-3">
              <Stat label="估值" value={money(process.data?.total)} />
              <Stat label="持仓" value={String(process.data?.open_trades ?? "—")} />
              <Stat label="已平仓" value={String(process.data?.closed_trades ?? "—")} />
              <Stat
                label="单笔"
                value={process.data?.stake_amount ? `${process.data.stake_amount} ${process.data.stake_currency ?? ""}` : "—"}
              />
            </div>
            <div className="mt-3 font-mono text-[12px] text-text-2">
              {(process.data?.balances ?? []).map((row) => `${row.currency} ${money(row.balance)}`).join("   ") || "余额还没读到"}
            </div>
            {process.data?.reachable && process.data.open_trades === 0 && process.data.closed_trades === 0 && (
              <p className="mt-3 text-[12px] leading-5 text-text-3">进程在跑。这一档还没有成交，要等 15 分钟信号出现才会下单。</p>
            )}
          </VoltCard>

          <VoltCard className="p-5">
            <div className="flex items-center justify-between">
              <div className="font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-3">最近回测</div>
              <Link to="/backtest" className="text-[12px] font-semibold text-accent-text hover:underline">
                全部记录
              </Link>
            </div>
            {latest ? (
              <div className="mt-3">
                <div className="font-mono text-[13px] font-semibold text-text">
                  #{latest.id} · {latest.symbols.join(", ") || "BTC/USDT"}
                </div>
                <div className="mt-2 grid grid-cols-3 gap-2">
                  <div>
                    <div className="text-[11px] text-text-3">笔数</div>
                    <div className="tnum font-mono text-[16px] font-bold text-text">{latest.total_trades}</div>
                  </div>
                  <div>
                    <div className="text-[11px] text-text-3">胜率</div>
                    <div className="tnum font-mono text-[16px] font-bold text-text">{winRate(latest.win_rate)}</div>
                  </div>
                  <div>
                    <div className="text-[11px] text-text-3">收益</div>
                    <div className="tnum font-mono text-[16px] font-bold text-bull">{percent(latest.total_return)}</div>
                  </div>
                </div>
                <div className="mt-2 font-mono text-[11px] text-text-3">{latest.start_date} – {latest.end_date}</div>
              </div>
            ) : (
              <p className="mt-3 text-[13px] text-text-2">还没有回测。</p>
            )}
          </VoltCard>
        </div>
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <VoltCard className="overflow-hidden">
          <div className="border-b border-border px-5 py-3 font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-3">
            持仓
          </div>
          {positions.length === 0 ? (
            <div className="px-5 py-8 text-[13px] text-text-2">没有持仓。</div>
          ) : (
            <table className="w-full text-[13px]">
              <thead>
                <tr className="text-left text-[11px] text-text-3">
                  <th className="px-5 py-2 font-medium">标的</th>
                  <th className="px-3 py-2 text-right font-medium">数量</th>
                  <th className="px-5 py-2 text-right font-medium">浮动盈亏</th>
                </tr>
              </thead>
              <tbody>
                {positions.map((row) => (
                  <tr key={row.id} className="border-t border-border/60">
                    <td className="px-5 py-2.5 font-mono font-semibold">{row.symbol}</td>
                    <td className="tnum px-3 py-2.5 text-right font-mono">{row.quantity}</td>
                    <td className={`tnum px-5 py-2.5 text-right font-mono font-semibold ${row.unrealized_pnl >= 0 ? "text-bull" : "text-bear"}`}>
                      {row.unrealized_pnl >= 0 ? "+" : ""}{row.unrealized_pnl.toFixed(2)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </VoltCard>

        <VoltCard className="overflow-hidden">
          <div className="flex items-center justify-between border-b border-border px-5 py-3">
            <div className="font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-3">实盘门禁</div>
            <span className={`text-[12px] font-semibold ${readiness.data?.can_start_live_small ? "text-bull" : "text-bear"}`}>
              {readiness.data?.can_start_live_small ? "可以启动" : "未通过"}
            </span>
          </div>
          {failed.length === 0 && !readiness.isLoading ? (
            <div className="px-5 py-8 text-[13px] text-text-2">没有未通过的检查。</div>
          ) : (
            <ul className="divide-y divide-border/60">
              {failed.slice(0, 5).map((check) => (
                <li key={check.key} className="px-5 py-3">
                  <div className="text-[13px] font-semibold text-text">{check.label}</div>
                  <div className="mt-0.5 text-[12px] leading-5 text-text-2">{check.detail || check.value}</div>
                </li>
              ))}
            </ul>
          )}
        </VoltCard>
      </div>
    </div>
  );
}
