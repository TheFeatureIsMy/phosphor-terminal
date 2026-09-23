import { Zap } from "lucide-react";
import { EmptyState } from "@/components/shell/EmptyState";
import { PageHeader } from "@/components/shell/PageHeader";
import { VoltCard } from "@/components/shell/VoltCard";
import { FadeIn } from "@/components/effects/FadeIn";
import { useCircuitBreakers } from "@/lib/hooks";
import { cn } from "@/lib/utils";

const TYPE_LABELS: Record<string, string> = {
  emergency_stop: "紧急停止",
  kill_switch: "Kill Switch",
  daily_loss_lock: "日损锁定",
  weekly_loss_lock: "周损锁定",
  manual_force_close: "手动强平",
  system_safe_mode: "系统安全模式",
};

export default function CircuitBreakersPage() {
  const { data } = useCircuitBreakers();
  const records = data?.records ?? [];

  return (
    <div className="mx-auto w-full max-w-[1340px] space-y-4 px-7 py-6">
      <FadeIn index={0}>
        <PageHeader
          eyebrow="CIRCUIT BREAKERS"
          title="熔断记录"
          subtitle={`共 ${data?.total_count ?? records.length} 条熔断事件`}
        />
      </FadeIn>

      <FadeIn index={1}>
        <VoltCard spotlight className="overflow-hidden">
          {records.length === 0 ? (
            <EmptyState compact icon={<Zap />} title="无熔断事件" description="风控体系运行平稳,未触发任何熔断。" />
          ) : (
            <table className="w-full text-[13px]">
              <thead>
                <tr className="border-b border-border text-left font-mono text-[10px] uppercase tracking-[0.08em] text-text-3">
                  <th className="px-5 py-3 font-medium">类型</th>
                  <th className="px-3 py-3 font-medium">策略</th>
                  <th className="px-3 py-3 font-medium">原因码</th>
                  <th className="px-3 py-3 font-medium">状态</th>
                  <th className="px-5 py-3 font-medium">时间</th>
                </tr>
              </thead>
              <tbody>
                {records.map((r) => (
                  <tr key={r.id} className="border-b border-border/50 transition-colors last:border-0 hover:bg-surface-hover">
                    <td className="px-5 py-3">
                      <span className="rounded-md bg-bear/12 px-2 py-0.5 text-[11.5px] font-semibold text-bear">
                        {TYPE_LABELS[r.type] ?? r.type}
                      </span>
                    </td>
                    <td className="px-3 py-3 font-mono text-text-2">{r.strategy_id || "—"}</td>
                    <td className="px-3 py-3 font-mono text-[11px] text-text-3">
                      {r.reason_codes.join(", ") || "—"}
                    </td>
                    <td className="px-3 py-3">
                      <span className={cn(
                        "rounded-md px-2 py-0.5 text-[11px] font-semibold",
                        r.resolved ? "bg-bull/12 text-bull" : "bg-warn/12 text-warn"
                      )}>
                        {r.resolved ? "已解除" : "生效中"}
                      </span>
                    </td>
                    <td className="px-5 py-3 font-mono text-[11px] text-text-3">
                      {r.created_at ? new Date(r.created_at).toLocaleString("zh-CN", { hour12: false }) : "—"}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </VoltCard>
      </FadeIn>
    </div>
  );
}
