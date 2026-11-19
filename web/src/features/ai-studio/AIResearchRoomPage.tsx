import { useState } from "react";
import { Link } from "react-router-dom";
import { Brain, Play, Plus, Square, TestTube, X } from "lucide-react";
import TextType from "@/components/reactbits/TextType/TextType";
import { EmptyState } from "@/components/shell/EmptyState";
import { PageHeader } from "@/components/shell/PageHeader";
import { VoltButton } from "@/components/shell/VoltButton";
import { VoltCard } from "@/components/shell/VoltCard";
import { FadeIn } from "@/components/effects/FadeIn";
import {
  useAdminProviders,
  useAIResearchRuns,
  useCreateResearchRun,
  useExecuteResearchRun,
  useTestProvider,
  useToggleProvider,
} from "@/lib/hooks";
import { cn } from "@/lib/utils";

function ratingTone(rating: string | null): string {
  const k = (rating ?? "").toLowerCase();
  if (k === "buy" || k === "overweight") return "var(--bull)";
  if (k === "sell" || k === "underweight") return "var(--bear)";
  return "var(--warn)";
}

export default function AIResearchRoomPage() {
  const { data: runs } = useAIResearchRuns();
  const createRun = useCreateResearchRun();
  const executeRun = useExecuteResearchRun();
  const [showNew, setShowNew] = useState(false);
  const [symbol, setSymbol] = useState("BTC/USDT");
  const [msg, setMsg] = useState("");

  const handleStart = () => {
    setMsg("");
    const today = new Date().toISOString().slice(0, 10);
    createRun.mutate(
      { symbol, analysis_date: today },
      {
        onSuccess: (run) => {
          setShowNew(false);
          setMsg(`研究运行 #${run.id} 已创建,正在执行…`);
          executeRun.mutate(run.id, {
            onSuccess: () => setMsg(`研究运行 #${run.id} 执行完成`),
            onError: (e) => setMsg(e instanceof Error ? e.message : "执行失败"),
          });
        },
        onError: (e) => setMsg(e instanceof Error ? e.message : "创建失败"),
      }
    );
  };

  return (
    <div className="mx-auto w-full max-w-[1340px] space-y-4 px-7 py-6">
      <FadeIn index={0}>
        <PageHeader
          eyebrow="MULTI-AGENT RESEARCH · 多 AGENT 投研辩论"
          title="让多位分析师为你辩一场"
          subtitle="对标的展开多 Agent 研究、多空辩论、风控裁定,产出可读的投研结论与可发布信号。"
          trailing={
            <VoltButton size="md" icon={<Plus />} onClick={() => setShowNew(true)}>
              发起研究
            </VoltButton>
          }
        />
      </FadeIn>

      <FadeIn index={1}>
        {(runs ?? []).length === 0 ? (
          <VoltCard>
            <EmptyState icon={<Brain />} title="暂无研究运行" description="发起一次多 Agent 投研后,结论会在这里呈现。" />
          </VoltCard>
        ) : (
          <div className="space-y-3.5">
            {runs!.map((r) => (
              <VoltCard key={r.id} spotlight className="p-5">
                <div className="flex items-center gap-3">
                  <span className="font-display text-[16px] font-bold text-text">{r.symbol}</span>
                  <span className="rounded-md bg-surface px-2 py-0.5 font-mono text-[11px] text-text-2">
                    {r.provider}
                  </span>
                  <span
                    className="rounded-md px-2 py-0.5 text-[11px] font-semibold"
                    style={{
                      color: ratingTone(r.rating),
                      background: `color-mix(in srgb, ${ratingTone(r.rating)} 12%, transparent)`,
                    }}
                  >
                    {r.rating ?? "—"}
                  </span>
                  {r.confidence != null && (
                    <span className="tnum font-mono text-[12px] font-semibold text-accent-text">
                      {(r.confidence * 100).toFixed(0)}%
                    </span>
                  )}
                  {/* pending 任务给执行入口,否则会永远卡住 */}
                  {r.status === "pending" && (
                    <VoltButton
                      size="sm"
                      disabled={executeRun.isPending}
                      onClick={() => executeRun.mutate(r.id, {
                        onSuccess: () => setMsg(`研究运行 #${r.id} 执行完成`),
                        onError: (e) => setMsg(e instanceof Error ? e.message : "执行失败"),
                      })}
                    >
                      <Play className="size-3.5" />执行
                    </VoltButton>
                  )}
                  <span className={cn(
                    "ml-auto rounded-md px-2 py-0.5 text-[11px] font-semibold",
                    r.status === "completed" ? "bg-bull/12 text-bull"
                      : r.status === "failed" ? "bg-bear/12 text-bear"
                      : "bg-warn/12 text-warn"
                  )}>
                    {r.status}
                  </span>
                </div>
                {r.final_decision && (
                  <div className="mt-3 line-clamp-3 text-[13px] leading-relaxed text-text-2">
                    <TextType
                      text={r.final_decision}
                      typingSpeed={8}
                      showCursor={false}
                      loop={false}
                    />
                  </div>
                )}
                {r.error_message && (
                  <p className="mt-2 font-mono text-[11px] text-bear">{r.error_message}</p>
                )}
              </VoltCard>
            ))}
          </div>
        )}
      </FadeIn>

      {/* LLM Provider 管理 */}
      {msg && (
        <FadeIn index={2}>
          <div className="rounded-lg bg-accent-soft px-3 py-2 text-[12px] font-medium text-accent-text">
            {msg}
          </div>
        </FadeIn>
      )}

      <FadeIn index={3}>
        <LLMProviderSection />
      </FadeIn>

      {/* 发起研究弹窗 */}
      {showNew && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/55 p-6" onClick={() => setShowNew(false)}>
          <div className="w-full max-w-[380px] rounded-[16px] border border-border bg-card p-6 shadow-modal" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-center justify-between">
              <div className="text-[16px] font-bold text-text">发起研究</div>
              <button onClick={() => setShowNew(false)} className="rounded-lg p-1.5 text-text-3 hover:bg-surface-hover hover:text-text">
                <X className="size-4" />
              </button>
            </div>
            <div className="mt-5 space-y-4">
              <div>
                <div className="mb-1.5 font-mono text-[10px] uppercase tracking-[0.08em] text-text-3">标的</div>
                <input
                  value={symbol}
                  onChange={(e) => setSymbol(e.target.value)}
                  placeholder="BTC/USDT"
                  className="w-full rounded-lg border border-border bg-surface px-3 py-2.5 font-mono text-[13px] text-text outline-none focus:border-accent-text/60"
                />
              </div>
              <VoltButton onClick={handleStart} disabled={!symbol || createRun.isPending || executeRun.isPending} size="lg" className="w-full">
                {createRun.isPending ? "创建中…" : executeRun.isPending ? "执行中…" : "开始研究"}
              </VoltButton>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

/* ---------------- LLM Provider 管理 ---------------- */

function LLMProviderSection() {
  const { data: providers } = useAdminProviders();
  const toggle = useToggleProvider();
  const test = useTestProvider();

  const llmProviders = (providers ?? []).filter(
    (p) => String(p.category) === "llm"
  );

  if (llmProviders.length === 0) {
    return (
      <VoltCard className="flex items-center gap-3 px-5 py-4">
        <Brain className="size-4 text-accent-text" />
        <span className="text-[13px] text-text-2">尚未配置 LLM Provider,多 Agent 研究需要至少一个可用的模型服务。</span>
        <Link
          to="/connections?group=model"
          className="ml-auto rounded-lg bg-accent-soft px-3 py-1.5 text-[12px] font-semibold text-accent-text transition-colors hover:bg-accent-soft/80"
        >
          去连接配置 →
        </Link>
      </VoltCard>
    );
  }

  return (
    <VoltCard spotlight className="overflow-hidden">
      <div className="flex items-center justify-between border-b border-border px-5 py-3.5">
        <span className="font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-2">
          LLM Provider
        </span>
        <span className="font-mono text-[10px] text-text-3">
          {llmProviders.length} 个已配置
        </span>
      </div>
      <div className="divide-y divide-border/50">
        {llmProviders.map((p) => {
          const id = Number(p.id);
          const enabled = p.enabled !== false;
          return (
            <div key={String(p.id)} className="flex items-center gap-3 px-5 py-3">
              <span className="font-semibold text-text">{String(p.provider_name ?? p.name ?? p.id)}</span>
              {p.instance_name != null && (
                <span className="font-mono text-[11px] text-text-3">{String(p.instance_name)}</span>
              )}
              {p.config != null && typeof p.config === "object" && (p.config as Record<string, unknown>).model != null && (
                <span className="rounded-md bg-surface px-2 py-0.5 font-mono text-[10px] text-text-3">
                  {String((p.config as Record<string, unknown>).model)}
                </span>
              )}
              <div className="ml-auto flex items-center gap-2">
                <button
                  onClick={() => test.mutate(id)}
                  disabled={test.isPending}
                  className="rounded-lg p-1.5 text-text-3 transition-colors hover:bg-surface-hover hover:text-text"
                  title="测试连接"
                >
                  <TestTube className="size-3.5" />
                </button>
                <button
                  onClick={() => toggle.mutate({ id, enable: !enabled })}
                  disabled={toggle.isPending}
                  className={cn(
                    "rounded-lg p-1.5 transition-colors",
                    enabled ? "text-bull hover:bg-bull/10" : "text-text-3 hover:bg-surface-hover hover:text-text"
                  )}
                  title={enabled ? "停用" : "启用"}
                >
                  {enabled ? <Square className="size-3.5" /> : <Play className="size-3.5" />}
                </button>
                <span className={cn(
                  "rounded-md px-2 py-0.5 text-[11px] font-semibold",
                  !enabled ? "bg-surface text-text-3" : String(p.status) === "active" ? "bg-bull/12 text-bull" : "bg-warn/12 text-warn"
                )}>
                  {!enabled ? "disabled" : String(p.status ?? "unknown")}
                </span>
              </div>
            </div>
          );
        })}
      </div>
    </VoltCard>
  );
}
