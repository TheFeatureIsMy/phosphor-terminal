import { Grid3x3 } from "lucide-react";
import { PageHeader } from "@/components/shell/PageHeader";
import { VoltCard } from "@/components/shell/VoltCard";
import { MetricTileGrid } from "@/components/shell/MetricTile";
import { FadeIn } from "@/components/effects/FadeIn";
import { useFailureClustering } from "@/lib/hooks";
import { cn } from "@/lib/utils";

const fmt2 = (v: number) =>
  v.toLocaleString("zh-CN", { minimumFractionDigits: 2, maximumFractionDigits: 2 });

function severityTone(s: string): string {
  const k = s.toLowerCase();
  if (k === "low") return "var(--bull)";
  if (k === "medium") return "var(--warn)";
  return "var(--bear)";
}

export default function FailureClusteringPage() {
  const { data } = useFailureClustering();

  return (
    <div className="mx-auto w-full max-w-[1340px] space-y-4 px-7 py-6">
      <FadeIn index={0}>
        <PageHeader
          eyebrow="FAILURE CLUSTERING"
          title="失败聚类"
          subtitle="把亏损交易聚成可修复的失败模式"
        />
      </FadeIn>

      <FadeIn index={1}>
        <MetricTileGrid
          columns={3}
          tiles={[
            { label: "亏损交易", value: `${data?.total_loss_trades ?? 0}`, color: "var(--bear)", icon: <Grid3x3 /> },
            { label: "亏损总额", value: fmt2(data?.total_loss_amount ?? 0), color: "var(--bear)" },
            { label: "失败模式", value: `${data?.clusters.length ?? 0}`, color: "var(--accent-text)" },
          ]}
        />
      </FadeIn>

      <FadeIn index={2}>
        {(data?.clusters ?? []).length === 0 ? (
          <VoltCard className="flex flex-col items-center gap-3 py-16">
            <Grid3x3 className="size-8 text-accent-text" />
            <div className="text-[15px] font-semibold text-text">暂无失败聚类</div>
            <div className="text-[13px] text-text-2">积累足够亏损交易后,聚类引擎会识别失败模式。</div>
          </VoltCard>
        ) : (
          <div className="grid grid-cols-2 gap-3.5">
            {data!.clusters.map((c) => (
              <VoltCard key={c.cluster_name} spotlight className="p-5">
                <div className="flex items-center gap-2.5">
                  <span className="font-semibold text-text">{c.label || c.cluster_name}</span>
                  <span
                    className="ml-auto rounded-md px-2 py-0.5 text-[11px] font-semibold"
                    style={{
                      color: severityTone(c.severity),
                      background: `color-mix(in srgb, ${severityTone(c.severity)} 12%, transparent)`,
                    }}
                  >
                    {c.severity}
                  </span>
                </div>
                <div className="mt-3 flex gap-6 font-mono text-[12px]">
                  <span className="text-text-2">{c.trade_count} 笔</span>
                  <span className="tnum text-bear">-{fmt2(Math.abs(c.total_loss))}</span>
                  <span className="tnum text-text-3">均 {fmt2(c.avg_loss_pct)}%</span>
                </div>
                {c.suggested_fix && (
                  <div className="mt-3 rounded-lg bg-accent-soft px-3 py-2 text-[12px] text-accent-text">
                    建议:{c.suggested_fix}
                  </div>
                )}
              </VoltCard>
            ))}
          </div>
        )}
      </FadeIn>
    </div>
  );
}
