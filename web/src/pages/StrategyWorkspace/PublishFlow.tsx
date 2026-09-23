import { useState } from "react";
import { CheckCircle2, Circle, Loader2, Lock, Rocket } from "lucide-react";
import { VoltButton } from "@/components/shell/VoltButton";
import { useStartPaper } from "@/lib/hooks";
import { cn } from "@/lib/utils";

export interface PublishVersion {
  id: string;
  version_no: number;
  status: string;
}

const STAGES = ["draft", "validated", "backtested", "paper_running", "paper_passed"] as const;
const STAGE_LABEL: Record<string, string> = {
  draft: "草稿",
  validated: "已校验",
  backtested: "已回测",
  paper_running: "模拟运行",
  paper_passed: "模拟通过",
};

/**
 * 发布流程(状态机驱动,目标 dry-run)。
 * 阶梯展示版本生命周期,按当前状态给出下一步操作。
 * live_small_enabled=false,故真实实盘入口禁用并标注。
 */
export function PublishFlow({
  version,
  onGoto,
}: {
  version: PublishVersion | null;
  onGoto: (tab: "validation" | "backtest") => void;
}) {
  const startPaper = useStartPaper();
  const [msg, setMsg] = useState("");
  const status = version?.status ?? "draft";
  const stageIdx = STAGES.indexOf(status as (typeof STAGES)[number]);

  const publishToDryRun = () => {
    if (!version) return;
    setMsg("");
    startPaper.mutate(
      {
        strategy_version_id: version.id,
        symbols: ["BTC/USDT"],
        stake_amount: 100,
        initial_wallet: 10000,
        max_open_trades: 3,
        exchange: "binance",
      },
      {
        onSuccess: () => setMsg("已提交 dry-run 启动命令,执行引擎处理中"),
        onError: (e) => setMsg(e instanceof Error ? e.message : "发布失败"),
      }
    );
  };

  return (
    <div>
      {/* 状态阶梯 */}
      <div className="flex items-center">
        {STAGES.map((s, i) => {
          const reached = stageIdx >= 0 && i <= stageIdx;
          const isCurrent = i === stageIdx;
          return (
            <div key={s} className="flex flex-1 items-center">
              <div className="flex flex-col items-center gap-1">
                {reached ? (
                  <CheckCircle2 className={cn("size-4", isCurrent ? "text-accent-text" : "text-bull")} />
                ) : (
                  <Circle className="size-4 text-text-3" />
                )}
                <span className={cn("whitespace-nowrap font-mono text-[10px]", isCurrent ? "font-semibold text-accent-text" : "text-text-3")}>
                  {STAGE_LABEL[s]}
                </span>
              </div>
              {i < STAGES.length - 1 && <div className={cn("mx-1 mb-4 h-px flex-1", i < stageIdx ? "bg-bull" : "bg-border")} />}
            </div>
          );
        })}
      </div>

      {msg && <div className="mt-4 rounded-lg bg-accent-soft px-3 py-2 text-[12px] font-medium text-accent-text">{msg}</div>}

      {/* 下一步操作 */}
      <div className="mt-5 rounded-[12px] border border-border bg-surface p-4">
        {!version && <div className="text-[12.5px] text-text-2">该策略还没有版本,请先在画布保存 DSL。</div>}
        {version && status === "draft" && (
          <ActionRow hint="先通过 DSL 校验,确认策略规则合法。">
            <VoltButton size="sm" onClick={() => onGoto("validation")}>去校验</VoltButton>
          </ActionRow>
        )}
        {version && status === "validated" && (
          <ActionRow hint="校验通过,跑一次历史回测验证表现。">
            <VoltButton size="sm" onClick={() => onGoto("backtest")}>去回测</VoltButton>
          </ActionRow>
        )}
        {version && status === "backtested" && (
          <ActionRow hint="回测已通过,可发布到 dry-run 模拟运行。">
            <VoltButton size="sm" icon={<Rocket />} onClick={publishToDryRun} disabled={startPaper.isPending}>
              {startPaper.isPending ? "提交中…" : "发布到 dry-run"}
            </VoltButton>
          </ActionRow>
        )}
        {version && status === "paper_running" && (
          <ActionRow hint="正在 dry-run 模拟运行中。">
            <span className="flex items-center gap-1.5 text-[12px] font-semibold text-warn"><Loader2 className="size-3.5 animate-spin" />运行中</span>
          </ActionRow>
        )}
        {version && status === "paper_passed" && (
          <ActionRow hint="模拟已通过,满足小仓实盘前置条件。">
            <span className="flex items-center gap-1.5 text-[12px] font-semibold text-bull"><CheckCircle2 className="size-3.5" />模拟通过</span>
          </ActionRow>
        )}
        {version && !STAGES.includes(status as (typeof STAGES)[number]) && (
          <div className="text-[12.5px] text-text-2">当前状态:{status}</div>
        )}
      </div>

      {/* 真实实盘入口(live_small_enabled=false,禁用) */}
      <div className="mt-3 flex items-center gap-2 rounded-[12px] border border-dashed border-border px-4 py-3 text-[12px] text-text-3">
        <Lock className="size-3.5" />
        真实小仓实盘待开启(后端 live_small_enabled=false,dry-run 优先)
      </div>
    </div>
  );
}

function ActionRow({ hint, children }: { hint: string; children: React.ReactNode }) {
  return (
    <div className="flex items-center justify-between gap-3">
      <span className="text-[12.5px] text-text-2">{hint}</span>
      {children}
    </div>
  );
}
