import type { CSSProperties } from "react";
import { cn } from "@/lib/utils";

/** 统一骨架屏(脉冲动画,替代加载中的空白) */
export function Skeleton({ className, style }: { className?: string; style?: CSSProperties }) {
  return (
    <div
      className={cn(
        "animate-pulse rounded-lg bg-surface",
        className
      )}
      style={style}
    />
  );
}

/** 卡片级骨架(标题行 + 内容行) */
export function CardSkeleton({ lines = 3, className }: { lines?: number; className?: string }) {
  return (
    <div className={cn("space-y-3", className)}>
      <Skeleton className="h-4 w-1/3" />
      {Array.from({ length: lines }, (_, i) => (
        <Skeleton
          key={i}
          className="h-8"
          style={{ opacity: 1 - i * 0.2 } as React.CSSProperties}
        />
      ))}
    </div>
  );
}

/** 表格级骨架(表头 + 行) */
export function TableSkeleton({ rows = 4, cols = 4 }: { rows?: number; cols?: number }) {
  return (
    <div className="space-y-2 p-5">
      <div className="flex gap-4">
        {Array.from({ length: cols }, (_, i) => (
          <Skeleton key={i} className="h-3 flex-1" />
        ))}
      </div>
      {Array.from({ length: rows }, (_, r) => (
        <div key={r} className="flex gap-4" style={{ opacity: 1 - r * 0.15 }}>
          {Array.from({ length: cols }, (_, c) => (
            <Skeleton key={c} className="h-6 flex-1" />
          ))}
        </div>
      ))}
    </div>
  );
}