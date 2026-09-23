import { useState } from "react";
import { Check, GitBranch, RotateCcw } from "lucide-react";
import { useCreateVersion } from "@/lib/hooks";
import { cn } from "@/lib/utils";

export interface VersionItem {
  id: string;
  version_no: number;
  status: string;
  created_by?: string;
  created_at?: string;
  rule_dsl?: Record<string, unknown>;
}

function vTone(s: string): string {
  const k = s.toLowerCase();
  if (["live_small", "paper_passed", "ready_for_live"].includes(k)) return "var(--bull)";
  if (["draft", "pending", "validated", "backtested", "paper_running", "paused"].includes(k)) return "var(--warn)";
  if (["rejected", "failed", "error"].includes(k)) return "var(--bear)";
  return "var(--text-3)";
}

/**
 * 版本时间线 + 真回滚。
 * 回滚采用 git-revert 语义:以目标版本的 rule_dsl 新建一个版本(版本号前进、内容回到旧版),
 * 可追溯且不丢历史。后端无"当前版本指针",latest 即 versions[0],故新版本天然成为当前版本。
 */
export function VersionTimeline({
  strategyId,
  versions,
  latestVersionId,
}: {
  strategyId: string;
  versions: VersionItem[];
  latestVersionId?: string;
}) {
  const createVersion = useCreateVersion(strategyId);
  const [msg, setMsg] = useState("");
  const sorted = [...versions].sort((a, b) => b.version_no - a.version_no);

  const rollback = (v: VersionItem) => {
    if (!v.rule_dsl) return;
    setMsg("");
    createVersion.mutate(
      { rule_dsl: v.rule_dsl, created_by: `rollback-to-v${v.version_no}` },
      {
        onSuccess: () => setMsg(`已回滚:基于 v${v.version_no} 的内容创建了新版本`),
        onError: () => setMsg("回滚失败,请重试"),
      }
    );
  };

  if (sorted.length === 0) {
    return <div className="py-8 text-center text-[12px] text-text-3">暂无版本</div>;
  }

  return (
    <div>
      {msg && (
        <div className="mb-3 rounded-lg bg-accent-soft px-3 py-2 text-[12px] font-medium text-accent-text">{msg}</div>
      )}
      <div>
        {sorted.map((v, i) => {
          const isCurrent = v.id === latestVersionId || (i === 0 && !latestVersionId);
          const tone = vTone(v.status);
          return (
            <div key={v.id} className="flex gap-3">
              {/* 时间线轴 */}
              <div className="flex flex-col items-center">
                <span
                  className={cn(
                    "flex size-7 shrink-0 items-center justify-center rounded-full border",
                    isCurrent ? "border-accent-text/50 bg-accent-soft text-accent-text" : "border-border bg-surface text-text-3"
                  )}
                >
                  {isCurrent ? <Check className="size-3.5" /> : <GitBranch className="size-3.5" />}
                </span>
                {i < sorted.length - 1 && <span className="w-px flex-1 bg-border" />}
              </div>
              {/* 内容 */}
              <div className="min-w-0 flex-1 pb-5">
                <div className="flex flex-wrap items-center gap-2">
                  <span className="font-display text-[14px] font-bold text-text">v{v.version_no}</span>
                  <span
                    className="rounded-md px-2 py-0.5 text-[10.5px] font-semibold"
                    style={{ color: tone, background: `color-mix(in srgb, ${tone} 12%, transparent)` }}
                  >
                    {v.status}
                  </span>
                  {isCurrent && (
                    <span className="rounded-md bg-accent-soft px-2 py-0.5 text-[10.5px] font-semibold text-accent-text">当前</span>
                  )}
                  {!isCurrent && v.rule_dsl && (
                    <button
                      onClick={() => rollback(v)}
                      disabled={createVersion.isPending}
                      className="ml-auto flex items-center gap-1 rounded-lg border border-border bg-surface px-2.5 py-1 text-[11px] font-semibold text-text-2 transition-colors hover:border-accent-text/40 hover:text-text disabled:opacity-50"
                      title={`以 v${v.version_no} 的内容新建一个版本(git revert 式回滚)`}
                    >
                      <RotateCcw className="size-3" />
                      回滚到此版本
                    </button>
                  )}
                </div>
                <div className="mt-1 font-mono text-[10.5px] text-text-3">
                  {v.created_at ? new Date(v.created_at).toLocaleString("zh-CN", { hour12: false }) : "—"}
                  {v.created_by ? ` · ${v.created_by}` : ""}
                </div>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
