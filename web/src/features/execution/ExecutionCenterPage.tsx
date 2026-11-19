import { BarChart3, Clock, Heart, PlayCircle, Timer } from "lucide-react";
import { EmptyState } from "@/components/shell/EmptyState";
import { PageHeader } from "@/components/shell/PageHeader";
import { Skeleton } from "@/components/shell/Skeleton";
import { VoltCard } from "@/components/shell/VoltCard";
import { MetricTileGrid } from "@/components/shell/MetricTile";
import { FadeIn } from "@/components/effects/FadeIn";
import { useExecutionCenter } from "@/lib/hooks";
import { cn } from "@/lib/utils";

const REASON_LABELS: Record<string, string> = {
  freqtrade_status_error: "Freqtrade 引擎状态异常,请检查服务运行情况",
  freqtrade_unavailable: "Freqtrade 引擎未连接,请检查服务状态",
  data_source_unavailable: "行情数据源不可用,请检查数据源配置",
  exchange_unreachable: "交易所连接失败,请检查网络与 API 配置",
};
function reasonText(codes: string[]): string {
  return codes.map((c) => REASON_LABELS[c] ?? c).join(";");

}

function heartbeatTone(h: string): { color: string; label: string } {
  const k = h.toLowerCase();
  if (k === "alive" || k === "ok" || k === "healthy") return { color: "var(--bull)", label: "ALIVE" };
  if (k === "stale" || k === "unknown") return { color: "var(--warn)", label: h.toUpperCase() };
  return { color: "var(--bear)", label: h.toUpperCase() };
}

export default function ExecutionCenterPage() {
  const { data, isLoading } = useExecutionCenter();
  const healthy = data?.state === "running" || data?.state === "healthy";
  const hb = heartbeatTone(data?.freqtrade_heartbeat ?? "unknown");

  return (
    <div className="mx-auto w-full max-w-[1340px] space-y-4 px-7 py-6">
      <FadeIn index={0}>
        <PageHeader
          eyebrow="EXECUTION"
          title="执行中心"
          subtitle={`${data?.total_running ?? 0} 运行 · ${data?.total_open_positions ?? 0} 持仓 · ${data?.total_pending_orders ?? 0} 挂单`}
          trailing={
            <span className="flex items-center gap-1.5 rounded-lg border border-border bg-surface px-2.5 py-1.5 font-mono text-[10px] font-semibold uppercase tracking-[0.12em] text-text-2">
              <span
                className={cn("size-1.5 rounded-full", healthy ? "bg-accent" : "bg-warn")}
                style={{ boxShadow: healthy ? "0 0 4px var(--accent)" : undefined }}
              />
              {data?.state?.toUpperCase() ?? "—"}
            </span>
          }
        />
      </FadeIn>

      {/* 状态警告横幅 */}
      {!healthy && data && (
        <FadeIn index={1}>
          <div className="flex items-center gap-3 rounded-lg border border-warn/20 bg-warn/10 p-3">
            <span className="text-warn">⚠</span>
            <div>
              <div className="text-[12.5px] font-semibold text-text">执行引擎异常</div>
              {data.reason_codes.length > 0 && (
                <div className="text-[11.5px] text-text-2">{reasonText(data.reason_codes)}</div>
              )}
            </div>
          </div>
        </FadeIn>
      )}

      {/* 汇总指标 */}
      <FadeIn index={2}>
        {isLoading ? (
          <div className="grid grid-cols-5 gap-3">
            {Array.from({ length: 5 }, (_, i) => (
              <div key={i} className="rounded-lg border border-border bg-surface p-4 space-y-2">
                <Skeleton className="h-2.5 w-14" />
                <Skeleton className="h-6 w-10" />
              </div>
            ))}
          </div>
        ) : (
        <MetricTileGrid
          columns={5}
          tiles={[
            { label: "运行会话", value: `${data?.total_running ?? 0}`, color: "var(--bull)", icon: <PlayCircle /> },
            { label: "持仓", value: `${data?.total_open_positions ?? 0}`, color: "var(--warn)", icon: <BarChart3 /> },
            { label: "挂单", value: `${data?.total_pending_orders ?? 0}`, color: "var(--warn)", icon: <Clock /> },
            { label: "Freqtrade", value: hb.label, color: hb.color, icon: <Heart /> },
            { label: "延迟", value: `${data?.execution_latency_ms ?? 0}ms`, color: "var(--accent-text)", icon: <Timer /> },
          ]}
        />
        )}
      </FadeIn>

      {/* 会话列表 */}
      <FadeIn index={3}>
        <VoltCard spotlight className="overflow-hidden">
          <div className="border-b border-border px-5 py-3.5 font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-2">
            运行会话
          </div>
          {(data?.sessions ?? []).length === 0 ? (
            <EmptyState compact icon={<PlayCircle />} title="暂无运行会话" description="启动一次回测、模拟或实盘后会出现在这里。" />
          ) : (
            <table className="w-full text-[13px]">
              <thead>
                <tr className="border-b border-border text-left font-mono text-[10px] uppercase tracking-[0.08em] text-text-3">
                  <th className="px-5 py-3 font-medium">策略</th>
                  <th className="px-3 py-3 font-medium">模式</th>
                  <th className="px-3 py-3 font-medium">标的</th>
                  <th className="px-3 py-3 font-medium">状态</th>
                  <th className="px-3 py-3 font-medium">持仓</th>
                  <th className="px-3 py-3 font-medium">挂单</th>
                  <th className="px-5 py-3 font-medium">心跳</th>
                </tr>
              </thead>
              <tbody>
                {data!.sessions.map((s) => (
                  <tr key={s.run_id} className="border-b border-border/50 transition-colors last:border-0 hover:bg-surface-hover">
                    <td className="px-5 py-3 font-semibold text-text">{s.strategy_name || s.run_id.slice(0, 8)}</td>
                    <td className="px-3 py-3">
                      <span className="rounded-md bg-accent-soft px-2 py-0.5 font-mono text-[11px] font-semibold text-accent-text">
                        {s.mode}
                      </span>
                    </td>
                    <td className="px-3 py-3 font-mono text-text-2">{s.symbol}</td>
                    <td className="px-3 py-3">
                      <span className={cn(
                        "rounded-md px-2 py-0.5 text-[11.5px] font-semibold",
                        s.status === "running" ? "bg-bull/12 text-bull" : "bg-surface text-text-3"
                      )}>
                        {s.status}
                      </span>
                    </td>
                    <td className="tnum px-3 py-3 font-mono text-text">{s.open_positions}</td>
                    <td className="tnum px-3 py-3 font-mono text-text">{s.pending_orders}</td>
                    <td className="px-5 py-3 font-mono text-[11px] text-text-3">
                      {s.last_heartbeat ? new Date(s.last_heartbeat).toLocaleTimeString("zh-CN", { hour12: false }) : "—"}
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
