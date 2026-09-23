import { useState } from "react";
import { OctagonAlert } from "lucide-react";
import { api } from "@/lib/api";

/** 紧急停止确认弹窗:遮罩 + 确认卡,确认后调 /api/v2/emergency/stop */
export function EmergencyStopDialog({ onClose }: { onClose: () => void }) {
  const [state, setState] = useState<"idle" | "sending" | "done" | "error">("idle");

  const confirm = async () => {
    setState("sending");
    try {
      await api.post("/api/v2/emergency/stop", {});
      setState("done");
      window.setTimeout(onClose, 1200);
    } catch {
      setState("error");
    }
  };

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/55 p-6"
      onClick={onClose}
    >
      <div
        className="w-full max-w-[420px] rounded-[16px] border border-bear/30 bg-card p-6 shadow-modal"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center gap-3">
          <span className="flex size-10 items-center justify-center rounded-[10px] bg-bear/12">
            <OctagonAlert className="size-5 text-bear" />
          </span>
          <div>
            <div className="text-[16px] font-bold text-text">确认紧急停止?</div>
            <div className="text-[12px] text-text-2">EMERGENCY STOP</div>
          </div>
        </div>

        <p className="mt-4 text-[13px] leading-relaxed text-text-2">
          将立即停止所有运行中的策略、撤销全部挂单,并锁定账户进入安全状态。
          此操作需要人工解除锁定后才能恢复交易。
        </p>

        {state === "done" && (
          <div className="mt-3 rounded-lg bg-bull/12 px-3 py-2 text-[12.5px] font-semibold text-bull">
            已执行紧急停止
          </div>
        )}
        {state === "error" && (
          <div className="mt-3 rounded-lg bg-bear/12 px-3 py-2 text-[12.5px] font-semibold text-bear">
            执行失败,请检查后端连接后重试
          </div>
        )}

        <div className="mt-5 flex justify-end gap-2.5">
          <button
            onClick={onClose}
            className="rounded-lg border border-border bg-surface px-4 py-2 text-[13px] font-medium text-text-2 hover:text-text"
          >
            取消
          </button>
          <button
            onClick={confirm}
            disabled={state === "sending" || state === "done"}
            className="rounded-lg bg-bear px-4 py-2 text-[13px] font-semibold text-on-bear transition-colors hover:bg-bear/90 disabled:opacity-50"
          >
            {state === "sending" ? "执行中…" : "确认停止"}
          </button>
        </div>
      </div>
    </div>
  );
}
