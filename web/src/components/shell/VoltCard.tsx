import { cn } from "@/lib/utils";
import { useRef, useState, type HTMLAttributes } from "react";

/**
 * 统一卡片(对应 Swift voltCardSurface / dashboard ProtocolCard):
 * card 底 + 1pt border + 卡片阴影;hover 边框加亮 + 阴影升格 + 浮起 2px。
 * voltBorder = 电光描边变体;spotlight = hover 追光(ReactBits SpotlightCard 融合)。
 */
export function VoltCard({
  className,
  voltBorder = false,
  spotlight = false,
  children,
  ...rest
}: HTMLAttributes<HTMLDivElement> & {
  voltBorder?: boolean;
  spotlight?: boolean;
}) {
  const ref = useRef<HTMLDivElement>(null);
  const [pos, setPos] = useState({ x: 0, y: 0 });
  const [spotOpacity, setSpotOpacity] = useState(0);

  return (
    <div
      ref={ref}
      onMouseMove={(e) => {
        if (!spotlight || !ref.current) return;
        const rect = ref.current.getBoundingClientRect();
        setPos({ x: e.clientX - rect.left, y: e.clientY - rect.top });
      }}
      onMouseEnter={() => spotlight && setSpotOpacity(1)}
      onMouseLeave={() => spotlight && setSpotOpacity(0)}
      className={cn(
        "relative overflow-hidden rounded-[14px] border bg-card shadow-card transition-all duration-200",
        "hover:-translate-y-0.5 hover:shadow-elevated",
        voltBorder
          ? "border-accent/40 hover:border-accent/55 shadow-[0_0_32px_-8px_var(--glow-accent)]"
          : "border-border hover:border-border-hover",
        className
      )}
      {...rest}
    >
      {spotlight && (
        <div
          className="pointer-events-none absolute inset-0 transition-opacity duration-300"
          style={{
            opacity: spotOpacity,
            background: `radial-gradient(480px circle at ${pos.x}px ${pos.y}px, color-mix(in srgb, var(--accent) 10%, transparent), transparent 65%)`,
          }}
        />
      )}
      {children}
    </div>
  );
}

/** 卡片小标题(accent 图标 + mono 大写标签)— 对应 Swift ProtocolCardTitle */
export function VoltCardTitle({
  icon,
  children,
  className,
}: {
  icon?: React.ReactNode;
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <div className={cn("flex items-center gap-2.5", className)}>
      {icon && <span className="text-accent-text [&>svg]:size-4">{icon}</span>}
      <span className="font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-2">
        {children}
      </span>
    </div>
  );
}
