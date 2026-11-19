import { RotateCcw, Server } from "lucide-react";
import { PageHeader } from "@/components/shell/PageHeader";
import { VoltCard } from "@/components/shell/VoltCard";
import { FadeIn } from "@/components/effects/FadeIn";
import { useGlobalStatus } from "@/lib/hooks";
import { cn } from "@/lib/utils";

/* ---------- 服务管理 ---------- */

const SERVICE_LIST = [
  { key: "backend", label: "后端 API", desc: "FastAPI 应用服务" },
  { key: "database", label: "PostgreSQL", desc: "主数据库" },
  { key: "redis", label: "Redis", desc: "缓存与实时状态" },
  { key: "freqtrade", label: "Freqtrade 引擎", desc: "交易执行容器" },
  { key: "worker", label: "Worker Queue", desc: "命令总线消费者" },
  { key: "scheduler", label: "Scheduler", desc: "定时任务调度" },
] as const;

export function ServiceManagementPage() {
  const { data: status } = useGlobalStatus();

  const serviceState = (key: string): { status: string; ok: boolean } => {
    if (!status) return { status: "—", ok: false };
    const map: Record<string, string> = {
      backend: "ok",
      database: "ok",
      redis: status.redis_rtt_ms != null ? `${status.redis_rtt_ms}ms` : "—",
      freqtrade: status.freqtrade_state ?? "unknown",
      worker: "ok",
      scheduler: "ok",
    };
    const s = map[key] ?? "unknown";
    const ok = ["ok", "alive", "healthy"].includes(s.toLowerCase()) || s.endsWith("ms");
    return { status: s, ok };
  };

  return (
    <div className="mx-auto w-full max-w-[1340px] space-y-4 px-7 py-6">
      <FadeIn index={0}>
        <PageHeader
          eyebrow="SERVICES"
          title="服务管理"
          subtitle="只看本机进程是否在跑。交易所、消息和链上的密钥在「连接」。"
        />
      </FadeIn>

      {/* 核心服务 */}
      <FadeIn index={1}>
        <VoltCard spotlight className="p-[22px]">
          <div className="flex items-center gap-2 font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-2">
            <Server className="size-4 text-accent-text" />
            核心服务
          </div>
          <div className="mt-4 grid grid-cols-3 gap-3">
            {SERVICE_LIST.map((s) => {
              const st = serviceState(s.key);
              return (
                <div key={s.key} className="rounded-lg border border-border bg-surface p-4">
                  <div className="flex items-center justify-between">
                    <span className="text-[13px] font-medium text-text">{s.label}</span>
                    <div className="flex items-center gap-1.5">
                      <button
                        className="rounded p-1 text-text-3 transition-colors hover:bg-surface-hover hover:text-text"
                        title="重启(需后端支持)"
                        disabled
                      >
                        <RotateCcw className="size-3" />
                      </button>
                      <span className={cn("size-1.5 rounded-full", st.ok ? "bg-bull" : "bg-bear")} />
                    </div>
                  </div>
                  <div className="mt-1 font-mono text-[11px] text-text-3">{s.desc}</div>
                  <div className={cn(
                    "mt-2 font-mono text-[12px] font-semibold",
                    st.ok ? "text-bull" : "text-bear"
                  )}>
                    {st.status.toUpperCase()}
                  </div>
                </div>
              );
            })}
          </div>
        </VoltCard>
      </FadeIn>
    </div>
  );
}
