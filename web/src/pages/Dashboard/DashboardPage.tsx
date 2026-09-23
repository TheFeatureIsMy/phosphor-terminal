import { useMemo } from "react";
import { AlertTriangle, OctagonX, PieChart } from "lucide-react";
import ClickSpark from "@/components/reactbits/ClickSpark/ClickSpark";
import { PageHeader } from "@/components/shell/PageHeader";
import { VoltCard } from "@/components/shell/VoltCard";
import { FadeIn } from "@/components/effects/FadeIn";
import { AnimatedNumber } from "@/components/effects/AnimatedNumber";
import { Skeleton } from "@/components/shell/Skeleton";
import { useDashboard, useDashboardKPIs, useLiveReadiness, useOrdersPositions } from "@/lib/hooks";
import { cn } from "@/lib/utils";
import { EquityCard, EquityCurveCard, ReadinessCard, RiskCard, RuntimeCard } from "./EquityCards";

const fmt2 = (v: number) =>
  v.toLocaleString("zh-CN", { minimumFractionDigits: 2, maximumFractionDigits: 2 });

/** KPI 指令条单格 */
function KpiTile({
  label,
  value,
  unit,
  color,
}: {
  label: string;
  value: React.ReactNode;
  unit?: string;
  color?: string;
}) {
  return (
    <div className="flex-1 px-4">
      <div className="font-mono text-[9.5px] font-semibold uppercase tracking-[0.08em] text-text-3">
        {label}
      </div>
      <div className="mt-1 flex items-baseline gap-1">
        <span
          className="tnum font-mono text-[18px] font-bold"
          style={{ color: color ?? "var(--text)" }}
        >
          {value}
        </span>
        {unit && <span className="font-mono text-[10px] text-text-3">{unit}</span>}
      </div>
    </div>
  );
}

function KpiDivider() {
  return <div className="h-[30px] w-px bg-border" />;
}

export default function DashboardPage() {
  const { data: dash, isLoading: dashLoading } = useDashboard();
  const { data: kpis } = useDashboardKPIs();
  const { data: readiness } = useLiveReadiness();
  const { data: ordersPositions } = useOrdersPositions();

  // 敞口分布
  const exposures = useMemo(() => {
    const positions = ordersPositions?.positions ?? [];
    if (positions.length === 0) return [];
    const bySymbol = new Map<string, { value: number; pnl: number }>();
    for (const p of positions) {
      const val = Math.abs(p.quantity * p.current_price);
      const existing = bySymbol.get(p.symbol) ?? { value: 0, pnl: 0 };
      existing.value += val;
      existing.pnl += p.unrealized_pnl;
      bySymbol.set(p.symbol, existing);
    }
    const total = [...bySymbol.values()].reduce((s, v) => s + v.value, 0);
    return [...bySymbol.entries()]
      .map(([symbol, v]) => ({
        symbol,
        value: v.value,
        pnl: v.pnl,
        pct: total > 0 ? (v.value / total) * 100 : 0,
      }))
      .sort((a, b) => b.value - a.value);
  }, [ordersPositions]);

  const acc = dash?.account;
  const todayPct = acc?.today_pnl_pct ?? kpis?.pnl_change_pct ?? 0;
  const riskState = dash?.risk.global_state?.toUpperCase() ?? "—";
  const ready = readiness?.state === "READY" || (readiness?.score ?? 0) > 0;

  return (
    <div className="mx-auto w-full max-w-[1340px] space-y-4 px-7 py-6">
      <FadeIn index={0}>
        <PageHeader
          eyebrow="OVERVIEW"
          title="驾驶舱"
          subtitle="实时驾驶舱 · 所有指标均为后端真实数据"
          trailing={
            <div className="flex items-center gap-2">
              <span className="flex items-center gap-1.5 rounded-lg border border-border bg-surface px-2.5 py-1 font-mono text-[10px] text-text-3">
                <span className="size-1.5 rounded-full bg-warn" />
                未就绪
              </span>
              <span className="flex items-center gap-1.5 rounded-lg bg-accent-soft px-2.5 py-1 font-mono text-[10px] font-semibold text-accent-text">
                LIVE
              </span>
            </div>
          }
        />
      </FadeIn>

      {/* 建议操作行 */}
      {(dash?.available_actions?.length ?? 0) > 0 && (
        <FadeIn index={1}>
          <div className="flex items-center gap-2.5">
            <span className="text-[12px] text-text-3">建议操作</span>
            {dash!.available_actions.slice(0, 3).map((a) => (
              <ClickSpark key={a.type + a.label} sparkColor="var(--accent)" sparkCount={10} sparkRadius={18}>
              <button
                key={a.type + a.label}
                disabled={!a.enabled}
                className={cn(
                  "flex items-center gap-1.5 rounded-lg border px-3 py-1.5 font-mono text-[11px] font-semibold uppercase tracking-wide transition-colors",
                  a.type.toLowerCase().includes("emergency") || a.label.includes("紧急")
                    ? "border-bear/25 bg-bear/10 text-bear hover:bg-bear/15"
                    : a.type.toLowerCase().includes("tighten") || a.type.toLowerCase().includes("stop")
                      ? "border-warn/25 bg-warn/10 text-warn hover:bg-warn/15"
                      : "border-accent-text/25 bg-accent-soft text-accent-text hover:bg-accent-soft/80"
                )}
              >
                {a.type.toLowerCase().includes("emergency") || a.label.includes("紧急") ? (
                  <OctagonX className="size-3.5" />
                ) : (
                  <AlertTriangle className="size-3.5" />
                )}
                {a.label}
              </button>
              </ClickSpark>
            ))}
          </div>
        </FadeIn>
      )}

      {/* KPI 指令条 */}
      <FadeIn index={2}>
        {dashLoading ? (
          <div className="flex items-center gap-4 rounded-[14px] border border-border bg-card px-4 py-3 shadow-card">
            {Array.from({ length: 5 }, (_, i) => (
              <div key={i} className="flex-1 space-y-1.5">
                <Skeleton className="h-2.5 w-12" />
                <Skeleton className="h-5 w-16" />
              </div>
            ))}
          </div>
        ) : (
        <div className="relative flex items-center rounded-[14px] border border-border bg-card py-3 shadow-card">
          {/* 模拟数据徽标 */}
          {kpis?.data_source?.simulated && (
            <span className="absolute -top-2.5 right-3 rounded-md bg-warn/15 px-2 py-0.5 font-mono text-[10px] font-semibold text-warn">
              模拟数据
            </span>
          )}
          <KpiTile
            label="账户权益"
            value={<AnimatedNumber value={acc?.equity ?? 0} />}
            unit={acc?.currency ?? "USDT"}
          />
          <KpiDivider />
          <KpiTile
            label="今日盈亏"
            value={
              <AnimatedNumber value={Math.abs(todayPct)} prefix={todayPct >= 0 ? "+" : "-"} suffix="%" />
            }
            color={todayPct >= 0 ? "var(--bull)" : "var(--bear)"}
          />
          <KpiDivider />
          <KpiTile
            label="最大回撤"
            value={<AnimatedNumber value={acc?.max_drawdown_pct ?? 0} suffix="%" />}
            color="var(--bear)"
          />
          <KpiDivider />
          <KpiTile
            label="就绪度"
            value={readiness ? `${readiness.score}/100` : "—"}
            color="var(--accent-text)"
          />
          <KpiDivider />
          <KpiTile
            label="风险状态"
            value={riskState}
            color={riskState === "NORMAL" ? "var(--bull)" : "var(--warn)"}
          />
        </div>
        )}
      </FadeIn>

      {/* Bento row 1:Equity 大卡 + 权益曲线 */}
      <FadeIn index={3}>
        <div className="grid grid-cols-12 gap-3.5">
          <div className="col-span-5">
            <EquityCard dash={dash} kpis={kpis} />
          </div>
          <div className="col-span-7">
            <EquityCurveCard />
          </div>
        </div>
      </FadeIn>

      {/* Bento row 2:运行时 / 就绪度 / 风险 */}
      <FadeIn index={4}>
        <div className="grid grid-cols-3 gap-3.5">
          <RuntimeCard dash={dash} kpis={kpis} />
          <ReadinessCard readiness={readiness} />
          <RiskCard dash={dash} />
        </div>
      </FadeIn>

      {/* 敞口分布 */}
      {exposures.length > 0 && (
        <FadeIn index={5}>
          <VoltCard spotlight className="p-[22px]">
            <div className="flex items-center gap-2 font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-2">
              <PieChart className="size-4 text-accent-text" />
              敞口分布
            </div>
            <div className="mt-4 space-y-2.5">
              {exposures.map((e) => (
                <div key={e.symbol} className="flex items-center gap-3">
                  <span className="w-16 font-mono text-[12px] font-semibold text-text">{e.symbol}</span>
                  <div className="flex-1">
                    <div className="h-2 overflow-hidden rounded-full bg-surface">
                      <div
                        className="h-full rounded-full bg-accent-text transition-[width] duration-500"
                        style={{ width: `${Math.min(e.pct, 100)}%` }}
                      />
                    </div>
                  </div>
                  <span className="tnum w-12 text-right font-mono text-[11px] text-text-2">
                    {e.pct.toFixed(0)}%
                  </span>
                  <span className={cn(
                    "tnum w-16 text-right font-mono text-[11px] font-semibold",
                    e.pnl >= 0 ? "text-bull" : "text-bear"
                  )}>
                    {e.pnl >= 0 ? "+" : ""}{e.pnl.toFixed(0)}
                  </span>
                </div>
              ))}
            </div>
          </VoltCard>
        </FadeIn>
      )}

      {/* 决策流 + 告警 */}
      <FadeIn index={6}>
        <div className="grid grid-cols-2 gap-3.5">
          {/* 最近决策 */}
          <VoltCard className="overflow-hidden">
            <div className="border-b border-border px-5 py-3.5 font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-2">
              最近决策
            </div>
            {(dash?.recent_decisions ?? []).length === 0 ? (
              <div className="px-5 py-8 text-center text-[12.5px] text-text-2">
                暂无风控决策记录
              </div>
            ) : (
              <div className="divide-y divide-border/50">
                {(dash?.recent_decisions ?? []).slice(0, 8).map((d, i) => (
                  <div key={i} className="flex items-center gap-3 px-5 py-2.5">
                    <span className="size-1.5 shrink-0 rounded-full bg-accent-text" />
                    <span className="flex-1 truncate text-[12.5px] text-text">
                      {String(d.decision ?? d.symbol ?? "决策")}
                    </span>
                    <span className="font-mono text-[11px] text-text-3">
                      {d.time ? new Date(String(d.time)).toLocaleTimeString("zh-CN", { hour12: false }) : ""}
                    </span>
                  </div>
                ))}
              </div>
            )}
          </VoltCard>

          {/* 告警 */}
          <VoltCard className="overflow-hidden">
            <div className="border-b border-border px-5 py-3.5 font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-2">
              告警
            </div>
            {(dash?.alerts ?? []).length === 0 ? (
              <div className="px-5 py-8 text-center text-[12.5px] text-text-2">
                当前无告警
              </div>
            ) : (
              <div className="divide-y divide-border/50">
                {(dash?.alerts ?? []).slice(0, 8).map((a, i) => (
                  <div key={i} className="flex items-center gap-3 px-5 py-2.5">
                    <span className="size-1.5 shrink-0 rounded-full bg-warn" />
                    <span className="flex-1 truncate text-[12.5px] text-text">
                      {String(a.title ?? a.level ?? "告警")}
                    </span>
                    <span className="font-mono text-[11px] text-text-3">
                      {a.time ? new Date(String(a.time)).toLocaleTimeString("zh-CN", { hour12: false }) : ""}
                    </span>
                  </div>
                ))}
              </div>
            )}
          </VoltCard>
        </div>
      </FadeIn>
    </div>
  );
}
