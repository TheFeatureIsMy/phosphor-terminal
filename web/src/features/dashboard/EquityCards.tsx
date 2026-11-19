import { useMemo, useState } from "react";
import {
  ArrowDownRight,
  ArrowUpRight,
  ChartLine,
  CheckCircle2,
  Clock,
  Shield,
} from "lucide-react";
import { VoltCard, VoltCardTitle } from "@/components/shell/VoltCard";
import StarBorder from "@/components/reactbits/StarBorder/StarBorder";
import { Tilt } from "@/components/effects/Tilt";
import { AnimatedNumber } from "@/components/effects/AnimatedNumber";
import Counter from "@/components/reactbits/Counter/Counter";
import { useEquityCurve } from "@/lib/hooks";
import type {
  DashboardKPIs,
  DashboardResponse,
  EquityPoint,
  LiveReadinessResponse,
} from "@/lib/types";
import { cn } from "@/lib/utils";

const fmt2 = (v: number) =>
  v.toLocaleString("zh-CN", { minimumFractionDigits: 2, maximumFractionDigits: 2 });

/* ================= Equity 大卡(voltBorder) ================= */

export function EquityCard({
  dash,
  kpis,
}: {
  dash?: DashboardResponse;
  kpis?: DashboardKPIs;
}) {
  const acc = dash?.account;
  const equity = acc?.equity ?? 0;
  const pnlPct = acc?.today_pnl_pct ?? kpis?.pnl_change_pct ?? 0;
  const pnlAbs = kpis?.total_pnl ?? (equity * pnlPct) / 100;
  const isUp = pnlPct >= 0;

  return (
    <Tilt className="h-full" amplitude={6}>
    <StarBorder as="div" color="var(--accent)" speed="5s" thickness={1} className="h-full w-full rounded-[14px]">
      <div className="flex h-full flex-col gap-4 rounded-[14px] bg-card p-[22px] shadow-card">
        <div className="flex items-center justify-between">
          <span className="flex items-center gap-1.5 rounded-lg bg-surface px-2.5 py-1 font-mono text-[10px] text-text-2">
            <span className="size-1.5 rounded-full bg-bull" />
            实盘账户 · {acc?.currency ?? "USDT"}
          </span>
          <span
            className={cn(
              "flex items-center gap-1 rounded-lg px-2.5 py-1 font-mono text-[11px] font-semibold",
              isUp ? "bg-bull text-on-bull" : "bg-bear text-on-bear"
            )}
          >
            {isUp ? <ArrowUpRight className="size-3" /> : <ArrowDownRight className="size-3" />}
            {isUp ? "+" : ""}
            {fmt2(pnlPct)}% TODAY
          </span>
        </div>

        <div>
          <div className="font-mono text-[10px] font-semibold uppercase tracking-[0.14em] text-text-3">
            账户权益
          </div>
          <div className="mt-1 flex items-baseline gap-2">
            <span className="inline-flex h-[62px] items-end overflow-hidden">
              <Counter
                value={equity}
                fontSize={52}
                fontWeight={900}
                textColor="var(--text)"
                gradientHeight={0}
                gap={2}
              />
            </span>
            <span className="pb-1 font-display text-[16px] font-semibold text-text-3">
              {acc?.currency ?? "USDT"}
            </span>
          </div>
        </div>

        <div className="flex gap-5">
          <MiniStat label="今日盈亏" value={`${isUp ? "+" : ""}${fmt2(pnlAbs)}`} color={isUp ? "var(--bull)" : "var(--bear)"} />
          <MiniStat label="最大回撤" value={`${fmt2(acc?.max_drawdown_pct ?? 0)}%`} color="var(--bear)" />
          <MiniStat label="对账中" value={`${dash?.runtime.reconciling_count ?? 0}`} />
        </div>

        <div className="mt-auto flex gap-7 border-t border-border/60 pt-4">
          <SubItem k="活跃策略" v={`${kpis?.active_strategies ?? dash?.runtime.running_strategies ?? 0}`} />
          <SubItem k="开放持仓" v={`${dash?.runtime.open_positions ?? kpis?.open_positions ?? 0}`} />
          <SubItem k="今日成交" v={`${kpis?.todays_trades ?? 0}`} />
          <SubItem k="待处理单" v={`${dash?.runtime.pending_orders ?? 0}`} />
        </div>
      </div>
    </StarBorder>
    </Tilt>
  );
}

function MiniStat({ label, value, color }: { label: string; value: string; color?: string }) {
  return (
    <div>
      <div className="font-mono text-[10px] uppercase tracking-[0.08em] text-text-3">{label}</div>
      <div className="tnum font-mono text-[13px] font-bold" style={{ color: color ?? "var(--text)" }}>
        {value}
      </div>
    </div>
  );
}

function SubItem({ k, v }: { k: string; v: string }) {
  return (
    <div>
      <div className="font-mono text-[10px] uppercase tracking-[0.08em] text-text-3">{k}</div>
      <div className="tnum font-display text-[19px] font-bold text-text">{v}</div>
    </div>
  );
}

/* ================= 权益曲线卡(SVG 自绘,主题自动跟随) ================= */

const RANGES = [7, 30, 90] as const;

function smoothPath(pts: [number, number][], close: boolean, h: number): string {
  if (pts.length < 2) return "";
  let d = `M ${pts[0][0]},${pts[0][1]}`;
  for (let i = 1; i < pts.length; i++) {
    const [x0, y0] = pts[i - 1];
    const [x1, y1] = pts[i];
    const cx = (x0 + x1) / 2;
    d += ` C ${cx},${y0} ${cx},${y1} ${x1},${y1}`;
  }
  if (close) d += ` L ${pts[pts.length - 1][0]},${h} L ${pts[0][0]},${h} Z`;
  return d;
}

export function EquityCurveCard() {
  const { data } = useEquityCurve();
  const [range, setRange] = useState<number>(30);

  const filtered = useMemo(() => {
    const pts = data ?? [];
    return range >= pts.length ? pts : pts.slice(-range);
  }, [data, range]);

  const W = 640;
  const H = 210;
  const PAD = 8;

  const { line, area, last } = useMemo(() => {
    if (filtered.length < 2) return { line: "", area: "", last: null as [number, number] | null };
    const vals = filtered.map((p: EquityPoint) => p.value);
    const min = Math.min(...vals);
    const max = Math.max(...vals);
    const span = Math.max(max - min, 0.0001);
    const pts: [number, number][] = vals.map((v, i) => [
      (W * i) / Math.max(vals.length - 1, 1),
      H - PAD - ((v - min) / span) * (H - PAD * 2),
    ]);
    return {
      line: smoothPath(pts, false, H),
      area: smoothPath(pts, true, H),
      last: pts[pts.length - 1],
    };
  }, [filtered]);

  return (
    <Tilt className="h-full" amplitude={6}>
      <VoltCard spotlight className="h-full p-[22px]">
      <div className="flex h-full flex-col">
        <div className="flex items-center justify-between">
          <VoltCardTitle icon={<ChartLine />}>权益曲线</VoltCardTitle>
          <div className="flex gap-1">
            {RANGES.map((r) => (
              <button
                key={r}
                onClick={() => setRange(r)}
                className={cn(
                  "rounded-lg px-2.5 py-1 text-[12.5px] font-semibold transition-colors",
                  range === r
                    ? "bg-accent-soft text-accent-text"
                    : "text-text-2 hover:text-text"
                )}
              >
                {r}D
              </button>
            ))}
          </div>
        </div>

        <div className="mt-3 flex-1">
          {filtered.length >= 2 ? (
            <svg viewBox={`0 0 ${W} ${H}`} className="h-full w-full" preserveAspectRatio="none">
              <defs>
                <linearGradient id="eqFill" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor="var(--accent)" stopOpacity="0.2" />
                  <stop offset="100%" stopColor="var(--accent)" stopOpacity="0" />
                </linearGradient>
              </defs>
              {[0.25, 0.5, 0.75].map((f) => (
                <line key={f} x1="0" y1={H * f} x2={W} y2={H * f} stroke="var(--border)" strokeWidth="1" />
              ))}
              <path d={area} fill="url(#eqFill)" />
              <path
                d={line}
                fill="none"
                stroke="var(--accent-text)"
                strokeWidth="2.5"
                strokeLinecap="round"
                strokeLinejoin="round"
                vectorEffect="non-scaling-stroke"
              />
              {last && (
                <circle cx={last[0]} cy={last[1]} r="4.5" fill="var(--accent-text)" stroke="var(--card)" strokeWidth="2.5" />
              )}
            </svg>
          ) : (
            <div className="flex h-full min-h-[210px] items-center justify-center rounded-xl bg-surface text-[13px] text-text-2">
              暂无曲线数据
            </div>
          )}
        </div>

        <div className="mt-2 flex justify-between text-[11.5px] text-text-2">
          <span>{filtered[0]?.date ?? ""}</span>
          <span>今日</span>
        </div>
      </div>
    </VoltCard>
    </Tilt>
  );
}

/* ================= 运行时 / 就绪度 / 风险 三卡 ================= */

function StatRow({ k, v }: { k: string; v: string }) {
  return (
    <div className="flex items-center justify-between">
      <span className="font-mono text-[10px] uppercase tracking-[0.08em] text-text-3">{k}</span>
      <span className="tnum font-display text-[19px] font-bold text-text">{v}</span>
    </div>
  );
}

export function RuntimeCard({ dash, kpis }: { dash?: DashboardResponse; kpis?: DashboardKPIs }) {
  return (
    <VoltCard className="p-[22px]">
      <div className="flex items-center justify-between">
        <VoltCardTitle icon={<Clock />}>运行时</VoltCardTitle>
        <span className="rounded-lg bg-bull/12 px-2 py-0.5 text-[11.5px] font-semibold text-bull">在线</span>
      </div>
      <div className="mt-4 space-y-3">
        <StatRow k="活跃策略" v={`${dash?.runtime.running_strategies ?? kpis?.active_strategies ?? 0}`} />
        <StatRow k="开放持仓" v={`${dash?.runtime.open_positions ?? 0}`} />
        <StatRow k="待处理单" v={`${dash?.runtime.pending_orders ?? 0}`} />
        <StatRow k="对账中" v={`${dash?.runtime.reconciling_count ?? 0}`} />
      </div>
    </VoltCard>
  );
}

export function ReadinessCard({ readiness }: { readiness?: LiveReadinessResponse }) {
  const score = readiness?.score ?? 0;
  const checks = readiness?.checks ?? [];
  const passed = checks.filter((c) => ["pass", "ok", "healthy"].includes(c.status.toLowerCase())).length;

  return (
    <VoltCard className="p-[22px]">
      <div className="flex items-center justify-between">
        <VoltCardTitle icon={<CheckCircle2 />}>实盘就绪度</VoltCardTitle>
        <span className="font-mono text-[10px] font-semibold uppercase tracking-[0.14em] text-accent-text">
          GATE
        </span>
      </div>
      <div className="mt-3 flex items-baseline gap-2.5">
        <AnimatedNumber
          value={score}
          decimals={0}
          separator={false}
          className="font-display text-[48px] font-black leading-none text-accent-text"
        />
        <span className="font-display text-[14px] font-semibold text-text-3">/ 100</span>
        {checks.length > 0 && (
          <span className="ml-auto font-mono text-[11px] text-text-2">
            {passed} / {checks.length} 检查通过
          </span>
        )}
      </div>
      <div className="mt-3 h-2.5 overflow-hidden rounded-full bg-surface">
        <div
          className="h-full rounded-full transition-[width] duration-700"
          style={{
            width: `${Math.min(score, 100)}%`,
            background: "linear-gradient(to right, var(--accent-text), var(--bull))",
            boxShadow: "0 0 8px color-mix(in srgb, var(--accent-text) 35%, transparent)",
          }}
        />
      </div>
    </VoltCard>
  );
}

export function RiskCard({ dash }: { dash?: DashboardResponse }) {
  const normal = dash?.risk.global_state?.toLowerCase() === "normal";
  return (
    <VoltCard className="p-[22px]">
      <div className="flex items-center justify-between">
        <VoltCardTitle icon={<Shield />}>全局风险</VoltCardTitle>
        <span
          className={cn(
            "rounded-lg px-2 py-0.5 text-[11.5px] font-semibold",
            normal ? "bg-bull/12 text-bull" : "bg-warn/12 text-warn"
          )}
        >
          {normal ? "正常" : "关注"}
        </span>
      </div>
      <div className="mt-4 flex gap-7">
        <div>
          <div className="font-mono text-[10px] uppercase tracking-[0.08em] text-text-3">当前回撤</div>
          <div className="tnum font-display text-[22px] font-bold text-bear">
            {fmt2(dash?.account.max_drawdown_pct ?? 0)}%
          </div>
        </div>
        <div>
          <div className="font-mono text-[10px] uppercase tracking-[0.08em] text-text-3">日损剩余</div>
          <div className="tnum font-display text-[22px] font-bold text-warn">
            {fmt2(dash?.risk.daily_loss_remaining_pct ?? 100)}%
          </div>
        </div>
      </div>
    </VoltCard>
  );
}