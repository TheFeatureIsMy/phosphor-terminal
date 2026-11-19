import { useState } from "react";
import { ArrowRight, Check, Wand2 } from "lucide-react";
import { PageHeader } from "@/components/shell/PageHeader";
import { VoltButton } from "@/components/shell/VoltButton";
import { VoltCard } from "@/components/shell/VoltCard";
import { FadeIn } from "@/components/effects/FadeIn";
import { useAdvanceCandidate, useConfirmCandidate, useStrategyCandidates } from "@/lib/hooks";
import { cn } from "@/lib/utils";

function statusTone(s: string): string {
  const k = s.toLowerCase();
  if (k === "confirmed" || k === "applied") return "var(--bull)";
  if (k === "pending" || k === "draft") return "var(--warn)";
  return "var(--text-3)";
}

export default function StrategyOptimizationPage() {
  const { data: candidates } = useStrategyCandidates();
  const advance = useAdvanceCandidate();
  const confirm = useConfirmCandidate();
  const [msg, setMsg] = useState("");

  return (
    <div className="mx-auto w-full max-w-[1340px] space-y-4 px-7 py-6">
      <FadeIn index={0}>
        <PageHeader
          eyebrow="STRATEGY OPTIMIZATION"
          title="策略优化"
          subtitle="复盘引擎产出的优化候选 DSL,确认后进入策略版本流"
        />
      </FadeIn>

      <FadeIn index={1}>
        {(candidates ?? []).length === 0 ? (
          <VoltCard className="flex flex-col items-center gap-3 py-16">
            <Wand2 className="size-8 text-accent-text" />
            <div className="text-[15px] font-semibold text-text">暂无优化候选</div>
            <div className="text-[13px] text-text-2">复盘报告产生改进建议后,候选 DSL 会出现在这里。</div>
          </VoltCard>
        ) : (
          <div className="space-y-3.5">
            {candidates!.map((c) => (
              <VoltCard key={c.id} spotlight className="p-5">
                <div className="flex items-center gap-3">
                  <span className="font-mono text-[13px] font-semibold text-text">
                    #{c.candidate_dsl_hash.slice(0, 10) || c.id.slice(0, 8)}
                  </span>
                  <span className={cn(
                    "rounded-md px-2 py-0.5 text-[11px] font-semibold",
                    c.dsl_valid ? "bg-bull/12 text-bull" : "bg-bear/12 text-bear"
                  )}>
                    {c.dsl_valid ? "DSL 有效" : "DSL 无效"}
                  </span>
                  <span
                    className="rounded-md px-2 py-0.5 text-[11px] font-semibold"
                    style={{
                      color: statusTone(c.status),
                      background: `color-mix(in srgb, ${statusTone(c.status)} 12%, transparent)`,
                    }}
                  >
                    {c.status}
                  </span>
                  <span className="ml-auto font-mono text-[11px] text-text-3">
                    {c.created_at ? new Date(c.created_at).toLocaleString("zh-CN", { hour12: false }) : "—"}
                  </span>
                </div>
                {c.rationale && (
                  <p className="mt-3 text-[13px] leading-relaxed text-text-2">{c.rationale}</p>
                )}
                {/* 操作按钮 */}
                <div className="mt-3.5 flex items-center gap-2 border-t border-border/40 pt-3.5">
                  {c.dsl_valid && c.status !== "confirmed" && c.status !== "applied" && (
                    <>
                      <VoltButton
                        size="sm"
                        variant="secondary"
                        icon={<ArrowRight />}
                        disabled={advance.isPending}
                        onClick={() => {
                          setMsg("");
                          advance.mutate(c.id, {
                            onSuccess: () => setMsg(`候选 #${c.id.slice(0, 8)} 已推进到下一阶段`),
                            onError: (e) => setMsg(e instanceof Error ? e.message : "推进失败"),
                          });
                        }}
                      >
                        推进
                      </VoltButton>
                      <VoltButton
                        size="sm"
                        icon={<Check />}
                        disabled={confirm.isPending}
                        onClick={() => {
                          setMsg("");
                          confirm.mutate(c.id, {
                            onSuccess: () => setMsg(`候选 #${c.id.slice(0, 8)} 已确认为策略版本`),
                            onError: (e) => setMsg(e instanceof Error ? e.message : "确认失败"),
                          });
                        }}
                      >
                        确认为策略
                      </VoltButton>
                    </>
                  )}
                  {(c.status === "confirmed" || c.status === "applied") && (
                    <span className="text-[12px] font-medium text-bull">已确认为策略版本</span>
                  )}
                </div>
              </VoltCard>
            ))}
            {msg && (
              <div className="rounded-lg bg-accent-soft px-3 py-2 text-[12px] font-medium text-accent-text">
                {msg}
              </div>
            )}
          </div>
        )}
      </FadeIn>
    </div>
  );
}
