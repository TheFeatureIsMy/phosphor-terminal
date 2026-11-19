import { useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { History, PlayCircle, Plus, TrendingDown, TrendingUp, X } from "lucide-react";
import { api } from "@/lib/api";
import { backtestRequestBody } from "@/lib/backtest-request";
import { PageHeader } from "@/components/shell/PageHeader";
import { Skeleton } from "@/components/shell/Skeleton";
import { VoltCard } from "@/components/shell/VoltCard";
import { EmptyState } from "@/components/shell/EmptyState";
import { VoltButton } from "@/components/shell/VoltButton";
import { VoltSelect } from "@/components/shell/VoltSelect";
import { FadeIn } from "@/components/effects/FadeIn";
import { useBacktestDetail, useStrategyRuns } from "@/lib/hooks";
import { cn } from "@/lib/utils";


const TABS = [
  { id: "all", label: "全部" },
  { id: "backtest", label: "回测" },
  { id: "dryrun", label: "模拟" },
] as const;

function statusTone(s: string): string {
  const k = s.toLowerCase();
  if (k === "running") return "var(--bull)";
  if (k === "stopped" || k === "finished" || k === "completed") return "var(--text-3)";
  if (k === "failed" || k === "error") return "var(--bear)";
  return "var(--warn)";
}

interface StrategyBrief {
  id: string;
  name: string;
}

interface BacktestRow {
  id: number;
  status: string;
  symbols: string[];
  start_date: string;
  end_date: string;
  total_trades: number;
  win_rate: number;
  total_return: number;
  created_at: string | null;
  error_message?: string | null;
}

interface DemoProcess {
  reachable: boolean;
  state: string;
  strategy: string | null;
  timeframe: string | null;
  trading_mode: string | null;
  dry_run: boolean | null;
  venue: string;
  stake_currency: string | null;
  stake_amount: string | null;
  max_open_trades: number | null;
  open_trades: number;
  closed_trades: number;
  total: number | null;
  balances: { currency: string; balance: number }[];
}

function asPercent(value: number | null | undefined): string {
  if (value == null || Number.isNaN(Number(value))) return "—";
  const n = Number(value);
  const pct = Math.abs(n) <= 1 ? n * 100 : n;
  return `${pct >= 0 ? "+" : ""}${pct.toFixed(2)}%`;
}

function asWinRate(value: number | null | undefined): string {
  if (value == null || Number.isNaN(Number(value))) return "—";
  const n = Number(value);
  const pct = n <= 1 ? n * 100 : n;
  return `${pct.toFixed(1)}%`;
}

const RUN_LABEL: Record<string, string> = {
  running: "进行中",
  pending: "排队",
  completed: "完成",
  failed: "失败",
  stopped: "已停止",
};

/** 新建运行弹窗(有策略→表单;无策略→引导) */
function NewRunDialog({ onClose, onCreated }: { onClose: () => void; onCreated: () => void }) {
  const { data: strategies } = useQuery({
    queryKey: ["strategies", "list"],
    queryFn: () => api.get<StrategyBrief[]>("/api/v2/strategies"),
    select: (d) => (Array.isArray(d) ? d : []),
  });
  const [strategyId, setStrategyId] = useState("");
  const [symbol, setSymbol] = useState("BTC/USDT");
  const [capital, setCapital] = useState("10000");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const hasStrategies = (strategies ?? []).length > 0;

  const submit = async () => {
    setSubmitting(true);
    setError(null);
    try {
      // 取该策略最新版本的 DSL(回测后端需要完整 rule_dsl)
      const versions = await api.get<Array<{ id: string; version_no?: number; rule_dsl?: Record<string, unknown> }>>(
        `/api/v2/strategies/${strategyId}/versions`
      );
      const list = Array.isArray(versions) ? versions : [];
      if (list.length === 0) {
        throw new Error("该策略还没有可回测的版本,请先在策略工作台保存一个 DSL 版本");
      }
      const latest = [...list].sort((a, b) => (b.version_no ?? 0) - (a.version_no ?? 0))[0];
      if (!latest.rule_dsl) {
        throw new Error("该版本没有规则，先在策略工作台保存。");
      }
      await api.post("/api/v2/backtest", backtestRequestBody({
        dsl: latest.rule_dsl,
        strategyVersionId: latest.id,
        symbols: [symbol],
        initialCapital: parseFloat(capital) || 10000,
      }));
      onCreated();
      onClose();
    } catch (e) {
      setError(e instanceof Error ? e.message : "创建失败");
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/55 p-6" onClick={onClose}>
      <div
        className="w-full max-w-[440px] rounded-[16px] border border-border bg-card p-6 shadow-modal"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center justify-between">
          <div className="text-[16px] font-bold text-text">新建运行</div>
          <button onClick={onClose} className="rounded-lg p-1.5 text-text-3 hover:bg-surface-hover hover:text-text">
            <X className="size-4" />
          </button>
        </div>

        {!hasStrategies ? (
          <div className="mt-5">
            <EmptyState
              compact
              icon={<PlayCircle />}
              title="暂无可选策略"
              description="先在策略工作台创建策略并发布版本,然后回到这里发起回测或模拟。"
              action={
                <Link to="/strategy">
                  <VoltButton size="md">去策略工作台</VoltButton>
                </Link>
              }
            />
          </div>
        ) : (
          <div className="mt-5 space-y-4">
            <div>
              <div className="mb-1.5 font-mono text-[10px] uppercase tracking-[0.08em] text-text-3">策略</div>
              <VoltSelect
                label="选择策略"
                value={strategyId}
                onChange={setStrategyId}
                options={strategies!.map((s) => ({ value: s.id, label: s.name }))}
              />
            </div>
            <div>
              <div className="mb-1.5 font-mono text-[10px] uppercase tracking-[0.08em] text-text-3">标的</div>
              <input
                value={symbol}
                onChange={(e) => setSymbol(e.target.value)}
                className="w-full rounded-lg border border-border bg-surface px-3 py-2.5 font-mono text-[13px] font-semibold text-text outline-none focus:border-accent-text/60"
              />
            </div>
            <div>
              <div className="mb-1.5 font-mono text-[10px] uppercase tracking-[0.08em] text-text-3">初始资金 (USDT)</div>
              <input
                value={capital}
                onChange={(e) => setCapital(e.target.value)}
                inputMode="decimal"
                className="tnum w-full rounded-lg border border-border bg-surface px-3 py-2.5 font-mono text-[13px] font-semibold text-text outline-none focus:border-accent-text/60"
              />
            </div>
            {error && (
              <div className="rounded-lg bg-bear/10 px-3 py-2 font-mono text-[11.5px] text-bear">{error}</div>
            )}
            <VoltButton
              onClick={submit}
              disabled={!strategyId || submitting}
              size="lg"
              className="w-full"
            >
              {submitting ? "创建中…" : "创建并运行"}
            </VoltButton>
          </div>
        )}
      </div>
    </div>
  );
}

function ProcessStat({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border border-border bg-surface px-3 py-2">
      <div className="font-mono text-[10px] uppercase tracking-[0.08em] text-text-3">{label}</div>
      <div className="mt-1 font-mono text-[13px] font-semibold text-text">{value}</div>
    </div>
  );
}

export default function BacktestSimulationPage() {
  const queryClient = useQueryClient();
  const { data: runs } = useStrategyRuns();
  const { data: backtests } = useQuery({
    queryKey: ["backtest", "list"],
    queryFn: () => api.get<BacktestRow[]>("/api/v2/backtest?summary=true&limit=50"),
    refetchInterval: (query) => {
      const rows = query.state.data ?? [];
      return rows.some((row) => row.status === "running" || row.status === "pending") ? 4000 : 15000;
    },
  });
  const { data: process } = useQuery({
    queryKey: ["trading", "demo-process"],
    queryFn: () => api.get<DemoProcess>("/api/trading/demo-process"),
    refetchInterval: 5000,
  });
  const [tab, setTab] = useState<(typeof TABS)[number]["id"]>("all");
  const [showNew, setShowNew] = useState(false);
  const [selectedRunId, setSelectedRunId] = useState<number | null>(null);

  const backtestRows = backtests ?? [];
  const simRuns = useMemo(
    () => (runs ?? []).filter((run) => /dry.?run|paper/i.test(run.mode)),
    [runs],
  );
  const visibleBacktests = tab === "dryrun" ? [] : backtestRows;
  const showProcess = tab !== "backtest";

  return (
    <div className="mx-auto w-full max-w-[1340px] space-y-4 px-7 py-6">
      <FadeIn index={0}>
        <PageHeader
          eyebrow="BACKTEST & DRYRUN"
          title="回测 / 模拟"
          subtitle={`${backtestRows.length} 次回测 · ${process?.reachable ? "模拟进程在跑" : "模拟进程未连接"}`}
          trailing={
            <VoltButton size="md" icon={<Plus />} onClick={() => setShowNew(true)}>
              新建运行
            </VoltButton>
          }
        />
      </FadeIn>

      {/* tab 切换 */}
      <FadeIn index={1}>
        <div className="flex gap-1.5">
          {TABS.map((t) => (
            <button
              key={t.id}
              onClick={() => setTab(t.id)}
              className={cn(
                "rounded-lg px-3.5 py-1.5 text-[12.5px] font-semibold transition-colors",
                tab === t.id
                  ? "bg-accent-soft text-accent-text"
                  : "text-text-2 hover:bg-surface-hover hover:text-text"
              )}
            >
              {t.label}
            </button>
          ))}
        </div>
      </FadeIn>

      {showProcess && (
        <FadeIn index={2}>
          <VoltCard spotlight className="p-5">
            <div className="flex items-start justify-between gap-4">
              <div>
                <div className="font-mono text-[10px] uppercase tracking-[0.08em] text-text-3">模拟进程</div>
                <div className="mt-1 text-[16px] font-bold text-text">
                  {process?.strategy ?? "Freqtrade"}
                  <span className="ml-2 font-mono text-[12px] font-semibold text-text-2">
                    {process?.timeframe ?? "—"} · {process?.venue === "binance_demo" ? "币安 Demo" : "本地执行"}
                  </span>
                </div>
              </div>
              <span
                className="rounded-md px-2 py-0.5 text-[11px] font-semibold"
                style={{
                  color: statusTone(process?.reachable ? process.state : "failed"),
                  background: `color-mix(in srgb, ${statusTone(process?.reachable ? process.state : "failed")} 12%, transparent)`,
                }}
              >
                {process?.reachable ? (process.state === "running" ? "运行中" : process.state) : "未连接"}
              </span>
            </div>
            <div className="mt-4 grid grid-cols-2 gap-3 sm:grid-cols-4">
              <ProcessStat label="持仓" value={String(process?.open_trades ?? 0)} />
              <ProcessStat label="已平仓" value={String(process?.closed_trades ?? 0)} />
              <ProcessStat label="单笔" value={process?.stake_amount ? `${process.stake_amount} ${process.stake_currency ?? ""}` : "—"} />
              <ProcessStat label="最多开仓" value={process?.max_open_trades != null ? String(process.max_open_trades) : "—"} />
            </div>
            <div className="mt-3 font-mono text-[12px] text-text-2">
              {(process?.balances ?? []).map((row) => `${row.currency} ${row.balance}`).join(" · ") || "暂无余额"}
              {process?.total != null ? ` · 合计 ${process.total.toFixed(2)}` : ""}
            </div>
            <div className="mt-2 text-[12px] text-text-3">
              {process?.reachable
                ? process.open_trades === 0 && process.closed_trades === 0
                  ? "进程在跑。这一档还没有成交，要等 15 分钟信号出现才会下单。"
                  : `${process.trading_mode ?? "spot"} · 开仓 ${process.open_trades} · 已平 ${process.closed_trades}`
                : "8080 上的模拟进程没有连上。"}
            </div>
            {simRuns.length > 0 && (
              <div className="mt-3 font-mono text-[11px] text-text-3">
                应用内模拟记录 {simRuns.length} 条
              </div>
            )}
          </VoltCard>
        </FadeIn>
      )}

      {tab !== "dryrun" && (
      <FadeIn index={3}>
        <VoltCard spotlight className="overflow-hidden">
          {visibleBacktests.length === 0 ? (
            <EmptyState
              icon={<History />}
              title="暂无回测记录"
              description="发起一次回测后，进度、交易笔数和收益会显示在这里。"
              action={
                <VoltButton onClick={() => setShowNew(true)}>
                  新建第一次运行
                </VoltButton>
              }
            />
          ) : (
            <table className="w-full text-[13px]">
              <thead>
                <tr className="border-b border-border text-left font-mono text-[10px] uppercase tracking-[0.08em] text-text-3">
                  <th className="px-5 py-3 font-medium">回测</th>
                  <th className="px-3 py-3 font-medium">状态</th>
                  <th className="px-3 py-3 font-medium">标的</th>
                  <th className="px-3 py-3 font-medium">区间</th>
                  <th className="px-3 py-3 font-medium">笔数</th>
                  <th className="px-3 py-3 font-medium">胜率</th>
                  <th className="px-5 py-3 font-medium">收益</th>
                </tr>
              </thead>
              <tbody>
                {visibleBacktests.map((row) => (
                  <tr
                    key={row.id}
                    onClick={() => setSelectedRunId(row.id)}
                    className="cursor-pointer border-b border-border/50 transition-colors last:border-0 hover:bg-surface-hover"
                  >
                    <td className="px-5 py-3 font-mono font-semibold text-text">#{row.id}</td>
                    <td className="px-3 py-3">
                      <span
                        className="rounded-md px-2 py-0.5 text-[11px] font-semibold"
                        style={{
                          color: statusTone(row.status),
                          background: `color-mix(in srgb, ${statusTone(row.status)} 12%, transparent)`,
                        }}
                      >
                        {RUN_LABEL[row.status] ?? row.status}
                      </span>
                    </td>
                    <td className="px-3 py-3 font-mono text-[12px] text-text">{row.symbols.join(", ") || "—"}</td>
                    <td className="px-3 py-3 font-mono text-[11px] text-text-3">{row.start_date} – {row.end_date}</td>
                    <td className="px-3 py-3 font-mono text-[12px] text-text">{row.total_trades}</td>
                    <td className="px-3 py-3 font-mono text-[12px] text-text">{asWinRate(row.win_rate)}</td>
                    <td className="px-5 py-3 font-mono text-[12px] text-text">{asPercent(row.total_return)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </VoltCard>
      </FadeIn>
      )}

      {showNew && (
        <NewRunDialog
          onClose={() => setShowNew(false)}
          onCreated={() => queryClient.invalidateQueries({ queryKey: ["backtest", "list"] })}
        />
      )}

      {/* 回测详情抽屉 */}
      {selectedRunId != null && (
        <BacktestDetailDrawer backtestId={selectedRunId} onClose={() => setSelectedRunId(null)} />
      )}
    </div>
  );
}

/* ================= 回测详情抽屉 ================= */

function BacktestDetailDrawer({ backtestId, onClose }: { backtestId: number; onClose: () => void }) {
  const { data: detail, isLoading } = useBacktestDetail(backtestId);
  const d = detail as Record<string, unknown> | undefined;

  const metrics = useMemo(() => {
    if (!d) return [];
    return [
      { label: "总收益", value: asPercent(d.total_return as number | null), color: Number(d.total_return ?? 0) >= 0 ? "var(--bull)" : "var(--bear)" },
      { label: "Sharpe", value: d.sharpe_ratio != null ? Number(d.sharpe_ratio).toFixed(2) : "—" },
      { label: "最大回撤", value: d.max_drawdown != null ? `${Number(d.max_drawdown).toFixed(1)}%` : "—", color: "var(--bear)" },
      { label: "胜率", value: asWinRate(d.win_rate as number | null) },
      { label: "盈亏比", value: d.profit_factor != null ? Number(d.profit_factor).toFixed(2) : "—" },
      { label: "总交易", value: String(d.total_trades ?? "—") },
    ];
  }, [d]);

  const equityCurve = ((d?.equity_curve ?? []) as Array<Record<string, unknown>>)
    .map((point) => ({
      date: String(point.date ?? point.timestamp ?? ""),
      value: Number(point.value ?? point.equity ?? 0),
    }))
    .filter((point) => point.date && Number.isFinite(point.value));
  const trades = (d?.trades ?? []) as Record<string, unknown>[];

  // SVG equity curve
  const W = 380, H = 120, PAD = 4;
  const { line, area } = useMemo(() => {
    if (equityCurve.length < 2) return { line: "", area: "" };
    const vals = equityCurve.map((p) => p.value);
    const min = Math.min(...vals);
    const max = Math.max(...vals);
    const span = Math.max(max - min, 0.0001);
    const pts = vals.map((v, i) => [
      (W * i) / Math.max(vals.length - 1, 1),
      H - PAD - ((v - min) / span) * (H - PAD * 2),
    ] as [number, number]);
    let line = `M ${pts[0][0]},${pts[0][1]}`;
    for (let i = 1; i < pts.length; i++) {
      const [x0, y0] = pts[i - 1];
      const [x1, y1] = pts[i];
      const cx = (x0 + x1) / 2;
      line += ` C ${cx},${y0} ${cx},${y1} ${x1},${y1}`;
    }
    const area = line + ` L ${pts[pts.length - 1][0]},${H} L ${pts[0][0]},${H} Z`;
    return { line, area };
  }, [equityCurve]);

  return (
    <div className="fixed inset-0 z-50 flex justify-end bg-black/40" onClick={onClose}>
      <div
        className="flex h-full w-[480px] flex-col border-l border-border bg-card shadow-modal"
        onClick={(e) => e.stopPropagation()}
      >
        {/* 头部 */}
        <div className="flex items-center justify-between border-b border-border px-5 py-4">
          <div>
            <div className="text-[15px] font-bold text-text">回测 #{backtestId}</div>
            <div className="mt-0.5 text-[12px] text-text-2">
              {d?.symbols ? (d.symbols as string[]).join(" · ") : ""}
            </div>
          </div>
          <button onClick={onClose} className="rounded-lg p-1.5 text-text-3 hover:bg-surface-hover hover:text-text">
            <X className="size-4" />
          </button>
        </div>

        {/* 内容 */}
        <div className="flex-1 space-y-4 overflow-y-auto p-5">
          {isLoading ? (
            <div className="space-y-3">
              {[0, 1, 2, 3].map((i) => (
                <Skeleton key={i} className="h-16" style={{ opacity: 1 - i * 0.15 } as React.CSSProperties} />
              ))}
            </div>
          ) : !d ? (
            <EmptyState compact icon={<History />} title="加载失败" description="无法获取回测详情。" />
          ) : (
            <>
              {/* 指标 */}
              <div className="grid grid-cols-3 gap-2.5">
                {metrics.map((m) => (
                  <div key={m.label} className="rounded-lg border border-border bg-surface p-3">
                    <div className="font-mono text-[10px] uppercase tracking-[0.08em] text-text-3">{m.label}</div>
                    <div className="tnum mt-1 font-display text-[18px] font-bold" style={{ color: m.color ?? "var(--text)" }}>
                      {m.value}
                    </div>
                  </div>
                ))}
              </div>

              {/* 权益曲线(含基准参考线) */}
              {equityCurve.length >= 2 && (
                <div>
                  <div className="mb-2 flex items-center justify-between">
                    <span className="font-mono text-[10px] font-semibold uppercase tracking-[0.08em] text-text-3">
                      权益曲线
                    </span>
                    <span className="flex items-center gap-3 font-mono text-[10px] text-text-3">
                      <span className="flex items-center gap-1">
                        <span className="inline-block h-0.5 w-4 bg-accent-text" style={{ height: 2 }} />
                        策略
                      </span>
                      <span className="flex items-center gap-1">
                        <span className="inline-block h-0.5 w-4 border-t border-dashed border-text-3" style={{ height: 0 }} />
                        初始资金
                      </span>
                    </span>
                  </div>
                  <div className="rounded-lg border border-border bg-surface p-3">
                    <svg viewBox={`0 0 ${W} ${H}`} className="w-full" preserveAspectRatio="none">
                      <defs>
                        <linearGradient id="btEqFill" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="0%" stopColor="var(--accent)" stopOpacity="0.2" />
                          <stop offset="100%" stopColor="var(--accent)" stopOpacity="0" />
                        </linearGradient>
                      </defs>
                      {/* 初始资金参考线 */}
                      <line
                        x1="0" y1={H - PAD - ((equityCurve[0].value - Math.min(...equityCurve.map(p => p.value))) / Math.max(Math.max(...equityCurve.map(p => p.value)) - Math.min(...equityCurve.map(p => p.value)), 0.0001)) * (H - PAD * 2)}
                        x2={W} y2={H - PAD - ((equityCurve[0].value - Math.min(...equityCurve.map(p => p.value))) / Math.max(Math.max(...equityCurve.map(p => p.value)) - Math.min(...equityCurve.map(p => p.value)), 0.0001)) * (H - PAD * 2)}
                        stroke="var(--text-3)" strokeWidth="1" strokeDasharray="4 3" opacity="0.5"
                      />
                      <path d={area} fill="url(#btEqFill)" />
                      <path d={line} fill="none" stroke="var(--accent-text)" strokeWidth="2" strokeLinecap="round" />
                    </svg>
                    <div className="mt-1 flex justify-between font-mono text-[10px] text-text-3">
                      <span>{equityCurve[0]?.date ?? ""}</span>
                      <span>{equityCurve[equityCurve.length - 1]?.date ?? ""}</span>
                    </div>
                    {/* 超额收益 */}
                    <div className="mt-2 flex items-center gap-4 border-t border-border/40 pt-2 font-mono text-[11px]">
                      <span className="text-text-3">
                        初始: <span className="font-semibold text-text">{equityCurve[0]?.value.toFixed(0)}</span>
                      </span>
                      <span className="text-text-3">
                        最终: <span className="font-semibold text-text">{equityCurve[equityCurve.length - 1]?.value.toFixed(0)}</span>
                      </span>
                      <span className={cn(
                        "ml-auto font-semibold",
                        (equityCurve[equityCurve.length - 1]?.value ?? 0) >= (equityCurve[0]?.value ?? 0) ? "text-bull" : "text-bear"
                      )}>
                        {(((equityCurve[equityCurve.length - 1]?.value ?? 0) - (equityCurve[0]?.value ?? 0)) / (equityCurve[0]?.value || 1) * 100).toFixed(1)}%
                      </span>
                    </div>
                  </div>
                </div>
              )}

              {/* 月度收益热力图 */}
              {equityCurve.length >= 30 && (
                <MonthlyHeatmap equityCurve={equityCurve} />
              )}

              {/* 回撤区间表 */}
              {equityCurve.length >= 10 && (
                <DrawdownTable equityCurve={equityCurve} />
              )}

              {/* 交易明细 */}
              {trades.length > 0 && (
                <div>
                  <div className="mb-2 font-mono text-[10px] font-semibold uppercase tracking-[0.08em] text-text-3">
                    交易明细 · {trades.length}
                  </div>
                  <div className="space-y-1.5">
                    {trades.slice(0, 20).map((t, i) => {
                      const hasPct = t.profit_pct != null;
                      const profit = Number(t.profit_pct ?? t.profit ?? 0);
                      const isWin = profit >= 0;
                      return (
                        <div key={i} className="flex items-center gap-3 rounded-lg border border-border bg-surface px-3 py-2">
                          {isWin ? (
                            <TrendingUp className="size-3.5 shrink-0 text-bull" />
                          ) : (
                            <TrendingDown className="size-3.5 shrink-0 text-bear" />
                          )}
                          <span className="font-mono text-[12px] font-semibold text-text">
                            {String(t.symbol ?? t.pair ?? "—")}
                          </span>
                          <span className={cn(
                            "ml-auto tnum font-mono text-[12px] font-bold",
                            isWin ? "text-bull" : "text-bear"
                          )}>
                            {isWin ? "+" : ""}{profit.toFixed(2)}{hasPct ? "%" : " USDT"}
                          </span>
                          <span className="font-mono text-[10px] text-text-3">
                            {t.close_time || t.close_date
                              ? new Date(String(t.close_time ?? t.close_date)).toLocaleDateString("zh-CN")
                              : ""}
                          </span>
                        </div>
                      );
                    })}
                    {trades.length > 20 && (
                      <div className="py-2 text-center font-mono text-[11px] text-text-3">
                        还有 {trades.length - 20} 笔交易…
                      </div>
                    )}
                  </div>
                </div>
              )}
            </>
          )}
        </div>
      </div>
    </div>
  );
}

/* ================= 月度收益热力图 ================= */

function MonthlyHeatmap({ equityCurve }: { equityCurve: { date: string; value: number }[] }) {
  const monthlyReturns = useMemo(() => {
    const byMonth = new Map<string, { start: number; end: number }>();
    for (const p of equityCurve) {
      const ym = p.date.slice(0, 7); // "2026-07"
      if (!byMonth.has(ym)) byMonth.set(ym, { start: p.value, end: p.value });
      byMonth.get(ym)!.end = p.value;
    }
    return [...byMonth.entries()].map(([ym, { start, end }]) => ({
      month: ym,
      returnPct: start > 0 ? ((end - start) / start) * 100 : 0,
    }));
  }, [equityCurve]);

  if (monthlyReturns.length === 0) return null;

  const years = [...new Set(monthlyReturns.map((m) => m.month.slice(0, 4)))];
  const months = ["01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12"];
  const monthLabels = ["1月", "2月", "3月", "4月", "5月", "6月", "7月", "8月", "9月", "10月", "11月", "12月"];

  const returnMap = new Map(monthlyReturns.map((m) => [m.month, m.returnPct]));

  function cellColor(ret: number | undefined): string {
    if (ret == null) return "var(--surface)";
    if (ret > 5) return "color-mix(in srgb, var(--bull) 60%, transparent)";
    if (ret > 2) return "color-mix(in srgb, var(--bull) 35%, transparent)";
    if (ret > 0) return "color-mix(in srgb, var(--bull) 15%, transparent)";
    if (ret > -2) return "color-mix(in srgb, var(--bear) 15%, transparent)";
    if (ret > -5) return "color-mix(in srgb, var(--bear) 35%, transparent)";
    return "color-mix(in srgb, var(--bear) 60%, transparent)";
  }

  return (
    <div>
      <div className="mb-2 font-mono text-[10px] font-semibold uppercase tracking-[0.08em] text-text-3">
        月度收益热力图
      </div>
      <div className="rounded-lg border border-border bg-surface p-3">
        {years.map((year) => (
          <div key={year} className="mb-2 last:mb-0">
            <div className="mb-1 font-mono text-[10px] text-text-3">{year}</div>
            <div className="grid grid-cols-12 gap-1">
              {months.map((m, i) => {
                const key = `${year}-${m}`;
                const ret = returnMap.get(key);
                return (
                  <div
                    key={m}
                    className="flex aspect-square items-center justify-center rounded-sm text-[9px] font-mono font-semibold"
                    style={{ background: cellColor(ret), color: ret != null ? "var(--text)" : "var(--text-3)" }}
                    title={ret != null ? `${monthLabels[i]}: ${ret >= 0 ? "+" : ""}${ret.toFixed(1)}%` : monthLabels[i]}
                  >
                    {ret != null ? `${ret >= 0 ? "+" : ""}${ret.toFixed(0)}` : ""}
                  </div>
                );
              })}
            </div>
          </div>
        ))}
        <div className="mt-2 flex items-center gap-3 font-mono text-[9px] text-text-3">
          <span>亏损</span>
          <div className="flex gap-0.5">
            {[-5, -2, 0, 2, 5].map((v) => (
              <div key={v} className="size-3 rounded-sm" style={{ background: cellColor(v) }} />
            ))}
          </div>
          <span>盈利</span>
        </div>
      </div>
    </div>
  );
}

/* ================= 回撤区间表 ================= */

interface DrawdownPeriod {
  start: string;
  end: string;
  depth: number;
  recoveryDays: number | null;
}

function DrawdownTable({ equityCurve }: { equityCurve: { date: string; value: number }[] }) {
  const periods = useMemo(() => {
    const result: DrawdownPeriod[] = [];
    let peak = -Infinity;
    let peakDate = "";
    let trough = Infinity;
    let troughDate = "";
    let inDrawdown = false;

    for (const p of equityCurve) {
      if (p.value > peak) {
        if (inDrawdown && trough < Infinity) {
          // Recovered
          const recoveryDate = p.date;
          const startDate = new Date(peakDate);
          const endDate = new Date(recoveryDate);
          const recoveryDays = Math.round((endDate.getTime() - startDate.getTime()) / (1000 * 60 * 60 * 24));
          result.push({
            start: peakDate,
            end: recoveryDate,
            depth: peak > 0 ? ((trough - peak) / peak) * 100 : 0,
            recoveryDays,
          });
        }
        peak = p.value;
        peakDate = p.date;
        trough = Infinity;
        inDrawdown = false;
      } else if (p.value < peak) {
        if (!inDrawdown) {
          inDrawdown = true;
          trough = p.value;
          troughDate = p.date;
        } else if (p.value < trough) {
          trough = p.value;
          troughDate = p.date;
        }
      }
    }

    // If still in drawdown at the end
    if (inDrawdown && trough < Infinity) {
      result.push({
        start: peakDate,
        end: equityCurve[equityCurve.length - 1]?.date ?? "",
        depth: peak > 0 ? ((trough - peak) / peak) * 100 : 0,
        recoveryDays: null,
      });
    }

    return result.sort((a, b) => a.depth - b.depth).slice(0, 5);
  }, [equityCurve]);

  if (periods.length === 0) return null;

  return (
    <div>
      <div className="mb-2 font-mono text-[10px] font-semibold uppercase tracking-[0.08em] text-text-3">
        回撤区间 · Top {periods.length}
      </div>
      <div className="space-y-1.5">
        {periods.map((p, i) => (
          <div key={i} className="flex items-center gap-3 rounded-lg border border-border bg-surface px-3 py-2">
            <span className="tnum font-mono text-[12px] font-bold text-bear">
              {p.depth.toFixed(1)}%
            </span>
            <span className="font-mono text-[11px] text-text-2">
              {p.start} → {p.end}
            </span>
            <span className="ml-auto font-mono text-[11px] text-text-3">
              {p.recoveryDays != null ? `${p.recoveryDays}天恢复` : "未恢复"}
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}
