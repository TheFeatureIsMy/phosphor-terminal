import { motion, useMotionValue, useSpring, type SpringOptions } from "motion/react";
import { useRef, type ReactNode } from "react";

/**
 * 3D 悬浮倾斜容器(spring 物理曲线与 ReactBits TiltedCard 一致:
 * damping 30 / stiffness 100 / mass 2)。
 * 仅用于展示型大卡;表格/表单卡不用,避免阅读与点按漂移。
 */
const spring: SpringOptions = { damping: 30, stiffness: 100, mass: 2 };

export function Tilt({
  children,
  amplitude = 7,
  scale = 1.015,
  className,
}: {
  children: ReactNode;
  amplitude?: number;
  scale?: number;
  className?: string;
}) {
  const ref = useRef<HTMLDivElement>(null);
  const rotateX = useSpring(0, spring);
  const rotateY = useSpring(0, spring);
  const scaleV = useSpring(1, spring);

  return (
    <motion.div
      ref={ref}
      className={className}
      style={{
        rotateX,
        rotateY,
        scale: scaleV,
        transformStyle: "preserve-3d",
        perspective: 800,
      }}
      onMouseMove={(e) => {
        const rect = ref.current?.getBoundingClientRect();
        if (!rect) return;
        const px = (e.clientX - rect.left) / rect.width - 0.5;
        const py = (e.clientY - rect.top) / rect.height - 0.5;
        rotateX.set(-py * amplitude * 2);
        rotateY.set(px * amplitude * 2);
      }}
      onMouseEnter={() => scaleV.set(scale)}
      onMouseLeave={() => {
        rotateX.set(0);
        rotateY.set(0);
        scaleV.set(1);
      }}
    >
      {children}
    </motion.div>
  );
}
