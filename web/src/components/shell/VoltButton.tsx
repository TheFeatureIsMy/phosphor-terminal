import type { ReactNode } from "react";
import { cn } from "@/lib/utils";

type Variant = "primary" | "secondary" | "ghost" | "danger";
type Size = "sm" | "md" | "lg";

const variantCls: Record<Variant, string> = {
  primary:
    "bg-accent text-on-accent font-semibold hover:bg-accent-light active:bg-accent",
  secondary:
    "border border-border bg-surface text-text font-medium hover:border-border-hover hover:bg-surface-hover",
  ghost:
    "text-text-2 font-medium hover:bg-surface-hover hover:text-text",
  danger:
    "bg-bear/12 text-bear font-semibold hover:bg-bear/18",
};

const sizeCls: Record<Size, string> = {
  sm: "px-2.5 py-1 text-[12px] rounded-lg gap-1",
  md: "px-3.5 py-2 text-[13px] rounded-lg gap-1.5",
  lg: "px-5 py-2.5 text-[14px] rounded-[10px] gap-2",
};

/**
 * 全站统一按钮。
 * primary=实底lime(CTA), secondary=描边(辅助), ghost=透明(次要), danger=红色(危险)。
 */
export function VoltButton({
  variant = "primary",
  size = "md",
  icon,
  disabled = false,
  onClick,
  className,
  children,
  type = "button",
}: {
  variant?: Variant;
  size?: Size;
  icon?: ReactNode;
  disabled?: boolean;
  onClick?: () => void;
  className?: string;
  type?: "button" | "submit" | "reset";
  children: ReactNode;
}) {
  return (
    <button
      type={type}
      disabled={disabled}
      onClick={onClick}
      className={cn(
        "inline-flex items-center justify-center transition-all duration-150 active:scale-[0.97] disabled:cursor-not-allowed disabled:opacity-50",
        variantCls[variant],
        sizeCls[size],
        className
      )}
    >
      {icon && <span className="[&>svg]:size-4">{icon}</span>}
      {children}
    </button>
  );
}