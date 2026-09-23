import { ArrowRight, RefreshCcw, TerminalSquare } from "lucide-react";
import { EmptyState } from "@/components/shell/EmptyState";
import { PageHeader } from "@/components/shell/PageHeader";
import { VoltCard } from "@/components/shell/VoltCard";
import { FadeIn } from "@/components/effects/FadeIn";
import { useReconciliationBus } from "@/lib/hooks";
import { cn } from "@/lib/utils";

function statusChip(s: string) {
  const k = s.toLowerCase();
  if (k === "completed" || k === "success" || k === "done") return "bg-bull/12 text-bull";
  if (k === "failed" || k === "error") return "bg-bear/12 text-bear";
  if (k === "running" || k === "pending") return "bg-warn/12 text-warn";
  return "bg-surface text-text-2";
}

export default function ReconciliationBusPage() {
  const { data } = useReconciliationBus();

  return (
    <div className="mx-auto w-full max-w-[1340px] space-y-4 px-7 py-6">
      <FadeIn index={0}>
        <PageHeader
          eyebrow="RECONCILIATION"
          title="对账总线"
          subtitle="命令总线事件流 · 对账运行记录 · 活跃租约"
        />
      </FadeIn>

      <div className="grid grid-cols-2 gap-3.5">
        {/* 命令事件流 */}
        <FadeIn index={1}>
          <VoltCard spotlight className="overflow-hidden">
            <div className="border-b border-border px-5 py-3.5 font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-2">
              最近命令
            </div>
            {(data?.recent_commands ?? []).length === 0 ? (
              <EmptyState compact icon={<TerminalSquare />} title="暂无命令事件" description="回测、部署、同步等命令进入总线后会形成事件流。" />
            ) : (
              <div className="divide-y divide-border/50">
                {data!.recent_commands.map((c) => (
                  <div key={c.id} className="flex items-center gap-3 px-5 py-3">
                    <ArrowRight className="size-3.5 text-accent-text" />
                    <span className="flex-1 truncate font-mono text-[12.5px] text-text">{c.command_type}</span>
                    <span className={cn("rounded-md px-2 py-0.5 text-[11px] font-semibold", statusChip(c.status))}>
                      {c.status}
                    </span>
                    <span className="font-mono text-[11px] text-text-3">
                      {c.created_at ? new Date(c.created_at).toLocaleTimeString("zh-CN", { hour12: false }) : "—"}
                    </span>
                  </div>
                ))}
              </div>
            )}
          </VoltCard>
        </FadeIn>

        {/* 对账运行 */}
        <FadeIn index={2}>
          <VoltCard spotlight className="overflow-hidden">
            <div className="border-b border-border px-5 py-3.5 font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-2">
              对账运行
            </div>
            {(data?.reconciliation_runs ?? []).length === 0 ? (
              <div className="flex flex-col items-center gap-3 py-12">
                <RefreshCcw className="size-7 text-accent-text" />
                <div className="text-[13px] text-text-2">暂无对账运行记录</div>
              </div>
            ) : (
              <div className="divide-y divide-border/50">
                {data!.reconciliation_runs.map((r) => (
                  <div key={r.id} className="flex items-center gap-3 px-5 py-3">
                    <span className="flex-1 truncate font-mono text-[12.5px] text-text">
                      #{r.id.slice(0, 8)}
                    </span>
                    <span className={cn(
                      "tnum font-mono text-[12px] font-semibold",
                      r.discrepancies > 0 ? "text-bear" : "text-bull"
                    )}>
                      {r.discrepancies} 差异
                    </span>
                    <span className={cn("rounded-md px-2 py-0.5 text-[11px] font-semibold", statusChip(r.status))}>
                      {r.status}
                    </span>
                  </div>
                ))}
              </div>
            )}
          </VoltCard>
        </FadeIn>
      </div>

      {/* 活跃租约 */}
      <FadeIn index={3}>
        <VoltCard spotlight className="overflow-hidden">
          <div className="border-b border-border px-5 py-3.5 font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-2">
            活跃租约
          </div>
          {(data?.active_leases ?? []).length === 0 ? (
            <EmptyState compact icon={<RefreshCcw />} title="当前无活跃租约" description="运行中的任务持有租约后会显示在这里。" />
          ) : (
            <div className="divide-y divide-border/50">
              {data!.active_leases.map((l, i) => {
                const lease = l as Record<string, unknown>;
                const holder = String(lease.holder ?? lease.task ?? lease.name ?? `租约 ${i + 1}`);
                const resource = String(lease.resource ?? lease.type ?? "");
                const ttl = lease.ttl_seconds != null ? `${lease.ttl_seconds}s` : lease.expires_at ? String(lease.expires_at) : "—";
                return (
                  <div key={i} className="flex items-center justify-between px-5 py-3">
                    <span className="font-mono text-[12.5px] font-semibold text-text">{holder}</span>
                    <span className="font-mono text-[11px] text-text-3">{resource} · {ttl}</span>
                  </div>
                );
              })}
            </div>
          )}
        </VoltCard>
      </FadeIn>
    </div>
  );
}
