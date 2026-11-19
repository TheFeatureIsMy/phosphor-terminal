import type { MouseEvent, ReactNode } from "react";
import { Cpu, History, PlayCircle, Rocket, ShieldCheck } from "lucide-react";
import { useStrategyWorkspace } from "@/lib/hooks";
import { statusTone } from "@/lib/statusTone";

export interface StrategyCardBrief {
  id: string;
  name: string;
  strategy_type: string;
  status: string;
}

export type WorkspaceTab = "canvas" | "validation" | "backtest" | "dryrun" | "versions" | "publish";

const GRAND_LABEL: Record<string, string> = {
  not_live: "未就绪",
  needs_config: "待配置",
  needs_validation: "待验证",
  paper_passed: "模拟通过",
  ready_for_live: "可实盘",
};

function MiniBtn({ icon, label, onClick }: { icon: ReactNode; label: string; onClick: (e: MouseEvent) => void }) {
  return (
    <button
      onClick={onClick}
      className="flex items-center gap-1 rounded-lg border border-border bg-surface px-2 py-1.5 text-[11px] font-semibold text-text-2 transition-colors hover:border-accent-text/40 hover:text-text"
    >
      {icon}
      {label}
    </button>
  );
}

function StrategyCard({ strategy, onOpen }: { strategy: StrategyCardBrief; onOpen: (id: string, tab: WorkspaceTab) => void }) {
  const { data: ws } = useStrategyWorkspace(strategy.id);
  const w = ws as Record<string, unknown> | undefined;
  const versions = (w?.versions as Record<string, unknown>[] | undefined) ?? [];
  const latest = versions[0];
  const readiness = w?.readiness as Record<string, unknown> | undefined;
  const passed = Number(readiness?.passed_count ?? 0);
  const total = Number(readiness?.total ?? 11);
  const grand = String(readiness?.grand_status ?? "");
  const backtests = (w?.recent_backtests as Record<string, unknown>[] | undefined) ?? [];
  const bt = backtests[0];
  const versionNo = latest ? String(latest.version_no ?? "—") : "—";
  const pct = total > 0 ? Math.round((passed / total) * 100) : 0;

  const open = (tab: WorkspaceTab) => (e: MouseEvent) => {
    e.stopPropagation();
    onOpen(strategy.id, tab);
  };

  return (
    <div
      onClick={() => onOpen(strategy.id, "canvas")}
      className="cursor-pointer rounded-[14px] border border-border bg-card p-5 shadow-card transition-colors hover:border-accent-text/40"
    >
      {/* 头部:名称 + 状态 */}
      <div className="flex items-start justify-between gap-2">
        <div className="flex min-w-0 items-center gap-2.5">
          <span className="flex size-9 shrink-0 items-center justify-center rounded-[10px] bg-accent-soft">
            <Cpu className="size-4 text-accent-text" />
          </span>
          <div className="min-w-0">
            <div className="truncate text-[14px] font-bold text-text">{strategy.name}</div>
            <div className="font-mono text-[10px] text-text-3">{strategy.strategy_type} · v{versionNo}</div>
          </div>
        </div>
        <span
          className="shrink-0 rounded-md px-2 py-0.5 text-[10.5px] font-semibold"
          style={{ color: statusTone(strategy.status), background: `color-mix(in srgb, ${statusTone(strategy.status)} 12%, transparent)` }}
        >
          {strategy.status}
        </span>
      </div>

      {/* 就绪度 */}
      <div className="mt-4">
        <div className="flex items-center justify-between font-mono text-[10px] text-text-3">
          <span>就绪度</span>
          <span>
            {passed}/{total}
            {grand ? ` · ${GRAND_LABEL[grand] ?? grand}` : ""}
          </span>
        </div>
        <div className="mt-1.5 h-1.5 overflow-hidden rounded-full bg-surface">
          <div
            className="h-full rounded-full transition-[width] duration-500"
            style={{ width: `${pct}%`, background: "linear-gradient(to right, var(--accent-text), var(--bull))" }}
          />
        </div>
      </div>

      {/* 最近回测 */}
      <div className="mt-3 font-mono text-[11px] text-text-2">
        {bt ? (
          <>
            最近回测{" "}
            <span className={Number(bt.total_return ?? 0) >= 0 ? "text-bull" : "text-bear"}>
              {Number(bt.total_return ?? 0) >= 0 ? "+" : ""}
              {(Number(bt.total_return ?? 0) * 100).toFixed(1)}%
            </span>{" "}
            · SR {Number(bt.sharpe_ratio ?? 0).toFixed(2)}
          </>
        ) : (
          <span className="text-text-3">暂无回测</span>
        )}
      </div>

      {/* 快捷操作 */}
      <div className="mt-4 flex flex-wrap items-center gap-1.5 border-t border-border/60 pt-3">
        <MiniBtn icon={<Cpu className="size-3.5" />} label="画布" onClick={open("canvas")} />
        <MiniBtn icon={<ShieldCheck className="size-3.5" />} label="校验" onClick={open("validation")} />
        <MiniBtn icon={<History className="size-3.5" />} label="回测" onClick={open("backtest")} />
        <MiniBtn icon={<PlayCircle className="size-3.5" />} label="DR" onClick={open("dryrun")} />
        <button
          onClick={open("publish")}
          className="ml-auto flex items-center gap-1 rounded-lg bg-accent-soft px-2.5 py-1.5 text-[11px] font-semibold text-accent-text transition-colors hover:bg-accent-soft/80"
        >
          <Rocket className="size-3" />
          发布
        </button>
      </div>
    </div>
  );
}

export function StrategyCardGrid({ strategies, onOpen }: { strategies: StrategyCardBrief[]; onOpen: (id: string, tab: WorkspaceTab) => void }) {
  return (
    <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-3">
      {strategies.map((s) => (
        <StrategyCard key={s.id} strategy={s} onOpen={onOpen} />
      ))}
    </div>
  );
}
