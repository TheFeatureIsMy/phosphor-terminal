import { OctagonX } from "lucide-react";
import { EmptyState } from "@/components/shell/EmptyState";
import { PageHeader } from "@/components/shell/PageHeader";
import { VoltCard } from "@/components/shell/VoltCard";
import { FadeIn } from "@/components/effects/FadeIn";
import { useStopProtection } from "@/lib/hooks";
import { cn } from "@/lib/utils";

const fmt2 = (v: number) =>
  v.toLocaleString("zh-CN", { minimumFractionDigits: 2, maximumFractionDigits: 2 });

function StopCell({ label, value, highlight }: { label: string; value: number | null; highlight?: boolean }) {
  return (
    <div>
      <div className="font-mono text-[9.5px] uppercase tracking-[0.08em] text-text-3">{label}</div>
      <div className={cn(
        "tnum font-mono text-[13px] font-semibold",
        highlight ? "text-accent-text" : "text-text"
      )}>
        {value != null ? fmt2(value) : "—"}
      </div>
    </div>
  );
}

export default function StopProtectionPage() {
  const { data } = useStopProtection();
  const positions = data?.positions ?? [];

  return (
    <div className="mx-auto w-full max-w-[1340px] space-y-4 px-7 py-6">
      <FadeIn index={0}>
        <PageHeader
          eyebrow="STOP PROTECTION"
          title="止损保护"
          subtitle={`${positions.length} 个持仓的四层止损水位 · 结构止损 / 已知良好 / 运行时 / 交易所保护`}
        />
      </FadeIn>

      <FadeIn index={1}>
        <VoltCard spotlight className="overflow-hidden">
          {positions.length === 0 ? (
            <EmptyState compact icon={<OctagonX />} title="暂无持仓需要止损保护" description="开放持仓后,四层止损水位会显示在这里。" />
          ) : (
            <div className="divide-y divide-border/50">
              {positions.map((p) => (
                <div key={p.position_id} className="flex items-center gap-6 px-5 py-4">
                  <div className="w-40">
                    <div className="font-semibold text-text">{p.symbol}</div>
                    <div className="font-mono text-[11px] text-text-3">
                      {p.side} · 入场 {fmt2(p.entry_price)}
                    </div>
                  </div>
                  <div className="grid flex-1 grid-cols-4 gap-4">
                    <StopCell label="结构止损" value={p.stops.raw_structure_stop} />
                    <StopCell label="已知良好" value={p.stops.last_known_good_stop} />
                    <StopCell label="运行时" value={p.stops.secure_runtime_stop} highlight />
                    <StopCell label="交易所保护" value={p.stops.exchange_protective_stop} />
                  </div>
                  <div className="flex w-28 flex-col items-end gap-1">
                    <span className="tnum font-mono text-[13px] font-semibold text-text">
                      {fmt2(p.current_price)}
                    </span>
                    {p.stops.volatility_locked && (
                      <span className="rounded-md bg-warn/12 px-1.5 py-0.5 text-[10px] font-semibold text-warn">
                        波动锁定
                      </span>
                    )}
                  </div>
                </div>
              ))}
            </div>
          )}
        </VoltCard>
      </FadeIn>
    </div>
  );
}
