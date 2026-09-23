import type { ReactNode } from "react";
import { cn } from "@/lib/utils";

/**
 * 全站统一空态:icon(accent 淡底)+ 标题 + 描述 + 可选动作。
 * 替代各页面散落的单行文字空态。
 */
export function EmptyState({
  icon,
  title,
  description,
  action,
  compact = false,
}: {
  icon: ReactNode;
  title: string;
  description?: string;
  action?: ReactNode;
  compact?: boolean;
}) {
  return (
    <div className={cn("flex flex-col items-center text-center", compact ? "gap-2 py-8" : "gap-3 py-14")}>
      <span className="flex size-10 items-center justify-center rounded-[10px] bg-accent-soft text-accent-text [&>svg]:size-5">
        {icon}
      </span>
      <div className="text-[14.5px] font-semibold text-text">{title}</div>
      {description && (
        <div className="max-w-[360px] text-[12.5px] leading-relaxed text-text-2">{description}</div>
      )}
      {action && <div className="mt-1">{action}</div>}
    </div>
  );
}
