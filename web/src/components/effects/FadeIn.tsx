import FadeContent from "@/components/reactbits/FadeContent/FadeContent";
import type { ReactNode } from "react";

/**
 * 分块入场(基于 ReactBits FadeContent):按 index 交错 40ms 上浮淡入。
 */
export function FadeIn({
  index = 0,
  children,
  className,
}: {
  index?: number;
  children: ReactNode;
  className?: string;
}) {
  return (
    <FadeContent
      duration={0.5}
      delay={0.03 + index * 0.04}
      ease="ease-out"
      className={className}
    >
      {children}
    </FadeContent>
  );
}
