import { useState } from "react";
import { Sparkles, TrendingUp } from "lucide-react";
import { PageHeader } from "@/components/shell/PageHeader";
import { VoltButton } from "@/components/shell/VoltButton";
import { VoltCard } from "@/components/shell/VoltCard";
import { FadeIn } from "@/components/effects/FadeIn";
import { useCreateDailyReview, useGrowthReports } from "@/lib/hooks";
import { cn } from "@/lib/utils";

const fmt2 = (v: number) =>
  v.toLocaleString("zh-CN", { minimumFractionDigits: 2, maximumFractionDigits: 2 });

export default function GrowthReviewPage() {
  const { data: reports } = useGrowthReports();
  const createReview = useCreateDailyReview();
  const [msg, setMsg] = useState("");

  const handleGenerate = () => {
    setMsg("");
    createReview.mutate(7, {
      onSuccess: () => setMsg("每日复盘已生成"),
      onError: (e) => setMsg(e instanceof Error ? e.message : "生成失败"),
    });
  };

  return (
    <div className="mx-auto w-full max-w-[1340px] space-y-4 px-7 py-6">
      <FadeIn index={0}>
        <PageHeader
          eyebrow="GROWTH REVIEW"
          title="成长复盘"
          subtitle="每日复盘与运行复盘报告,把交易结果变成可执行的改进"
          trailing={
            <VoltButton size="md" onClick={handleGenerate} disabled={createReview.isPending}>
              <Sparkles className="size-4" />
              {createReview.isPending ? "生成中…" : "生成每日复盘"}
            </VoltButton>
          }
        />
      </FadeIn>

      {msg && (
        <FadeIn index={1}>
          <div className="rounded-lg bg-accent-soft px-3 py-2 text-[12px] font-medium text-accent-text">
            {msg}
          </div>
        </FadeIn>
      )}

      <FadeIn index={2}>
        {(reports ?? []).length === 0 ? (
          <VoltCard className="flex flex-col items-center gap-3 py-16">
            <TrendingUp className="size-8 text-accent-text" />
            <div className="text-[15px] font-semibold text-text">暂无复盘报告</div>
            <div className="text-[13px] text-text-2">完成交易运行后,复盘引擎会在这里生成报告。也可以手动生成一份近 7 日的复盘。</div>
            <VoltButton size="sm" onClick={handleGenerate} disabled={createReview.isPending}>
              <Sparkles className="size-3.5" />
              {createReview.isPending ? "生成中…" : "生成每日复盘"}
            </VoltButton>
          </VoltCard>
        ) : (
          <div className="space-y-3.5">
            {reports!.map((r) => {
              const m = r.metrics;
              const pnl = m.total_pnl ?? 0;
              return (
                <VoltCard key={r.id} spotlight className="p-[22px]">
                  <div className="flex items-center gap-3">
                    <span className="rounded-md bg-accent-soft px-2 py-0.5 font-mono text-[11px] font-semibold text-accent-text">
                      {r.report_type}
                    </span>
                    <span className="font-mono text-[11px] text-text-3">
                      {r.period_start ? new Date(r.period_start).toLocaleDateString("zh-CN") : "—"}
                      {" → "}
                      {r.period_end ? new Date(r.period_end).toLocaleDateString("zh-CN") : "—"}
                    </span>
                    <span className={cn(
                      "tnum ml-auto font-display text-[20px] font-bold",
                      pnl >= 0 ? "text-bull" : "text-bear"
                    )}>
                      {pnl >= 0 ? "+" : ""}{fmt2(pnl)}
                    </span>
                  </div>
                  <div className="mt-4 grid grid-cols-6 gap-4">
                    {[
                      { k: "总交易", v: `${m.total_trades ?? 0}` },
                      { k: "胜率", v: `${fmt2((m.win_rate ?? 0) * 100)}%` },
                      { k: "盈亏比", v: fmt2(m.profit_factor ?? 0) },
                      { k: "最大回撤", v: `${fmt2(m.max_drawdown_pct ?? 0)}%` },
                      { k: "最佳单笔", v: `${fmt2(m.best_trade_pct ?? 0)}%` },
                      { k: "最差单笔", v: `${fmt2(m.worst_trade_pct ?? 0)}%` },
                    ].map((it) => (
                      <div key={it.k}>
                        <div className="font-mono text-[9.5px] uppercase tracking-[0.08em] text-text-3">{it.k}</div>
                        <div className="tnum mt-0.5 font-display text-[16px] font-bold text-text">{it.v}</div>
                      </div>
                    ))}
                  </div>
                </VoltCard>
              );
            })}
          </div>
        )}
      </FadeIn>
    </div>
  );
}
