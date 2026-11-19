import { Crosshair, ShieldAlert } from "lucide-react";
import { EmptyState } from "@/components/shell/EmptyState";
import { PageHeader } from "@/components/shell/PageHeader";
import { VoltCard } from "@/components/shell/VoltCard";
import { FadeIn } from "@/components/effects/FadeIn";
import { useManipulationCases, useManipulationScores } from "@/lib/hooks";
import { cn } from "@/lib/utils";

function riskTone(level: string): string {
  const k = level.toLowerCase();
  if (k === "low") return "var(--bull)";
  if (k === "medium") return "var(--warn)";
  return "var(--bear)";
}

function ScoreBar({ label, value }: { label: string; value: number }) {
  const pct = Math.min(Math.max(value * 100, 0), 100);
  const tone = pct < 30 ? "var(--bull)" : pct < 60 ? "var(--warn)" : "var(--bear)";
  return (
    <div className="flex items-center gap-2.5">
      <span className="w-24 font-mono text-[10px] uppercase tracking-wide text-text-3">{label}</span>
      <div className="h-1.5 flex-1 overflow-hidden rounded-full bg-surface">
        <div className="h-full rounded-full" style={{ width: `${pct}%`, background: tone }} />
      </div>
      <span className="tnum w-10 text-right font-mono text-[11px] font-semibold" style={{ color: tone }}>
        {pct.toFixed(0)}
      </span>
    </div>
  );
}

export default function ManipulationRadarPage() {
  const { data: scores } = useManipulationScores();
  const { data: cases } = useManipulationCases();

  return (
    <div className="mx-auto w-full max-w-[1340px] space-y-4 px-7 py-6">
      <FadeIn index={0}>
        <PageHeader
          eyebrow="MANIPULATION RADAR"
          title="操纵雷达"
          subtitle="多维操纵评分 · 主动案例追踪 · 生命周期裁决"
        />
      </FadeIn>

      <div className="grid grid-cols-2 gap-3.5">
        {/* 操纵评分 */}
        <FadeIn index={1}>
          <VoltCard spotlight className="overflow-hidden">
            <div className="border-b border-border px-5 py-3.5 font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-2">
              操纵评分
            </div>
            {(scores ?? []).length === 0 ? (
              <div className="flex flex-col items-center gap-3 py-12">
                <ShieldAlert className="size-7 text-accent-text" />
                <div className="text-[13px] text-text-2">暂无评分数据</div>
              </div>
            ) : (
              <div className="divide-y divide-border/50">
                {scores!.map((s) => (
                  <div key={s.id} className="space-y-2 px-5 py-4">
                    <div className="flex items-center gap-2.5">
                      <span className="font-semibold text-text">{s.symbol}</span>
                      <span className="font-mono text-[11px] text-text-3">{s.timeframe}</span>
                      <span
                        className="ml-auto rounded-md px-2 py-0.5 text-[11px] font-semibold"
                        style={{
                          color: riskTone(s.risk_level),
                          background: `color-mix(in srgb, ${riskTone(s.risk_level)} 12%, transparent)`,
                        }}
                      >
                        {s.risk_level}
                      </span>
                    </div>
                    <ScoreBar label="综合" value={s.manipulation_score} />
                    <ScoreBar label="猎杀止损" value={s.stop_hunt_score} />
                    <ScoreBar label="拉砸" value={s.pump_dump_score} />
                    <ScoreBar label="流动性陷阱" value={s.liquidity_trap_score} />
                  </div>
                ))}
              </div>
            )}
          </VoltCard>
        </FadeIn>

        {/* 主动案例 */}
        <FadeIn index={2}>
          <VoltCard spotlight className="overflow-hidden">
            <div className="border-b border-border px-5 py-3.5 font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-2">
              主动案例
            </div>
            {(cases ?? []).length === 0 ? (
              <EmptyState compact icon={<Crosshair />} title="暂无追踪案例" description="疑似操纵行为形成案例后会进入生命周期追踪。" />
            ) : (
              <div className="divide-y divide-border/50">
                {cases!.map((c) => (
                  <div key={c.id} className="flex items-center gap-3 px-5 py-3">
                    <span className="font-semibold text-text">{c.symbol}</span>
                    <span className="rounded-md bg-violet/12 px-2 py-0.5 text-[11px] font-semibold text-violet">
                      {c.manipulation_type}
                    </span>
                    <span className="flex-1 font-mono text-[11px] text-text-3">{c.lifecycle_stage}</span>
                    <span className="tnum font-mono text-[12px] font-semibold text-accent-text">
                      {(c.confidence * 100).toFixed(0)}%
                    </span>
                  </div>
                ))}
              </div>
            )}
          </VoltCard>
        </FadeIn>
      </div>
    </div>
  );
}
