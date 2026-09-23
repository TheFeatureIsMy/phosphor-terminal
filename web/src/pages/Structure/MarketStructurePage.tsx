import { useState } from "react";
import { Waves, Layers } from "lucide-react";
import { PageHeader } from "@/components/shell/PageHeader";
import { EmptyState } from "@/components/shell/EmptyState";
import { VoltCard } from "@/components/shell/VoltCard";
import { MetricTileGrid } from "@/components/shell/MetricTile";
import { FadeIn } from "@/components/effects/FadeIn";
import { useMarketStructure } from "@/lib/hooks";
import { cn } from "@/lib/utils";

const TIMEFRAMES = ["5m", "15m", "1h", "4h"];

const REGIME_LABELS: Record<string, string> = {
  trending: "趋势",
  ranging: "震荡",
  unknown: "识别中",
};
function regimeLabel(r?: string) {
  return REGIME_LABELS[(r ?? "").toLowerCase()] ?? "识别中";
}
function pdLabel(p?: string) {
  const k = (p ?? "").toLowerCase();
  if (k === "premium") return "溢价区";
  if (k === "discount") return "折价区";
  return "均衡区";
}

function zoneTone(direction: string, status: string): string {
  if (status !== "active") return "var(--text-3)";
  return direction === "bullish" ? "var(--bull)" : "var(--bear)";
}

export default function MarketStructurePage() {
  const [tf, setTf] = useState("5m");
  const { data } = useMarketStructure("BTC/USDT", tf);

  return (
    <div className="mx-auto w-full max-w-[1340px] space-y-4 px-7 py-6">
      <FadeIn index={0}>
        <PageHeader
          eyebrow="MARKET STRUCTURE"
          title="市场结构"
          subtitle={`${data?.symbol ?? "BTC/USDT"} · ${regimeLabel(data?.market_regime)} · ${pdLabel(data?.premium_discount)}`}
          trailing={
            <div className="flex gap-1">
              {TIMEFRAMES.map((t) => (
                <button
                  key={t}
                  onClick={() => setTf(t)}
                  className={cn(
                    "rounded-lg px-3 py-1.5 font-mono text-[12px] font-semibold transition-colors",
                    tf === t ? "bg-accent-soft text-accent-text" : "text-text-2 hover:text-text"
                  )}
                >
                  {t}
                </button>
              ))}
            </div>
          }
        />
      </FadeIn>

      <FadeIn index={1}>
        <MetricTileGrid
          columns={4}
          tiles={[
            { label: "结构评分", value: (data?.structure_score ?? 0).toFixed(1), color: "var(--accent-text)" },
            { label: "活跃区域", value: `${(data?.zones ?? []).filter((z) => z.status === "active").length}`, color: "var(--bull)" },
            { label: "流动性池", value: `${data?.liquidity_pools.length ?? 0}`, color: "var(--violet)" },
            { label: "结构事件", value: `${data?.events.length ?? 0}`, color: "var(--warn)" },
          ]}
        />
      </FadeIn>

      <div className="grid grid-cols-2 gap-3.5">
        {/* 结构区域 */}
        <FadeIn index={2}>
          <VoltCard spotlight className="overflow-hidden">
            <div className="border-b border-border px-5 py-3.5 font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-2">
              结构区域
            </div>
            {(data?.zones ?? []).length === 0 ? (
              <EmptyState compact icon={<Layers />} title="暂无区域数据" description="FVG / 订单块 / 流动性区域识别后会显示在这里。" />
            ) : (
              <div className="divide-y divide-border/50">
                {data!.zones.map((z) => (
                  <div key={z.zone_id} className="flex items-center gap-3 px-5 py-3">
                    <span
                      className="rounded-md px-2 py-0.5 font-mono text-[11px] font-semibold"
                      style={{
                        color: zoneTone(z.direction, z.status),
                        background: `color-mix(in srgb, ${zoneTone(z.direction, z.status)} 12%, transparent)`,
                      }}
                    >
                      {z.zone_type}
                    </span>
                    <span className="tnum flex-1 font-mono text-[12px] text-text-2">
                      {z.price_bottom.toFixed(1)} — {z.price_top.toFixed(1)}
                    </span>
                    <span className="tnum font-mono text-[11px] text-text-3">
                      {(z.current_strength * 100).toFixed(0)}%
                    </span>
                    <span className={cn(
                      "rounded px-1.5 py-0.5 text-[10px] font-semibold",
                      z.status === "active" ? "bg-bull/12 text-bull" : "bg-surface text-text-3"
                    )}>
                      {z.status}
                    </span>
                  </div>
                ))}
              </div>
            )}
          </VoltCard>
        </FadeIn>

        {/* 流动性池 */}
        <FadeIn index={3}>
          <VoltCard spotlight className="overflow-hidden">
            <div className="border-b border-border px-5 py-3.5 font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-2">
              流动性池
            </div>
            {(data?.liquidity_pools ?? []).length === 0 ? (
              <EmptyState compact icon={<Waves />} title="暂无流动性池" description="等高/等低/摆动点流动性识别后会显示在这里。" />
            ) : (
              <div className="divide-y divide-border/50">
                {data!.liquidity_pools.map((p) => (
                  <div key={p.pool_id} className="flex items-center gap-3 px-5 py-3">
                    <span className={cn(
                      "rounded-md px-2 py-0.5 font-mono text-[11px] font-semibold",
                      p.side === "buy_side" ? "bg-bull/12 text-bull" : "bg-bear/12 text-bear"
                    )}>
                      {p.pool_type}
                    </span>
                    <span className="tnum flex-1 font-mono text-[12px] text-text-2">
                      {p.price_level.toFixed(1)}
                    </span>
                    <span className="font-mono text-[11px] text-text-3">触达 {p.touched_count}×</span>
                  </div>
                ))}
              </div>
            )}
          </VoltCard>
        </FadeIn>
      </div>

      {/* 结构事件流 */}
      <FadeIn index={4}>
        <VoltCard spotlight className="overflow-hidden">
          <div className="border-b border-border px-5 py-3.5 font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-2">
            结构事件
          </div>
          {(data?.events ?? []).length === 0 ? (
            <EmptyState compact icon={<Waves />} title="暂无结构事件" description="BOS / CHoCH / 扫流动性等结构事件会实时推送在这里。" />
          ) : (
            <div className="divide-y divide-border/50">
              {data!.events.map((e) => (
                <div key={e.event_id} className="flex items-center gap-3 px-5 py-2.5 font-mono text-[12px]">
                  <span className="rounded bg-accent-soft px-2 py-0.5 text-[11px] font-semibold text-accent-text">
                    {e.event_type}
                  </span>
                  <span className="text-text-2">{e.direction}</span>
                  <span className="tnum flex-1 text-text">{e.price.toFixed(1)}</span>
                  <span className="text-[11px] text-text-3">{e.timeframe}</span>
                </div>
              ))}
            </div>
          )}
        </VoltCard>
      </FadeIn>
    </div>
  );
}
