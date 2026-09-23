import { Bell } from "lucide-react";

/** 通知下拉面板(空态优先,接入通知源后填充) */
export function NotificationPopover({ onClose }: { onClose: () => void }) {
  return (
    <div className="fixed inset-0 z-40" onClick={onClose}>
      <div
        className="absolute right-6 top-16 w-[320px] rounded-[14px] border border-border bg-card shadow-modal"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="border-b border-border px-4 py-3 font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-2">
          通知
        </div>
        <div className="flex flex-col items-center gap-2.5 py-10">
          <Bell className="size-6 text-text-3" />
          <div className="text-[13px] text-text-2">暂无新通知</div>
          <div className="px-8 text-center text-[11.5px] text-text-3">
            风控拦截、执行异常与系统事件会推送到这里。
          </div>
        </div>
      </div>
    </div>
  );
}
