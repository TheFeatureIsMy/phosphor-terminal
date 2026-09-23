import { useEffect, useRef, useState } from "react";

/**
 * 统一数字跳动组件(rAF 线性插值,帧率无关):
 * prefix/suffix 支持 "+2.35%"、"15/100" 等交易终端格式。
 * value 变化时从当前显示值平滑过渡到新值;不依赖视口门控,
 * 异步数据在任何时机到达都能正确更新。
 */
export function AnimatedNumber({
  value,
  decimals = 2,
  prefix = "",
  suffix = "",
  separator = true,
  duration = 0.9,
  className,
}: {
  value: number;
  decimals?: number;
  prefix?: string;
  suffix?: string;
  separator?: boolean;
  duration?: number;
  className?: string;
}) {
  // 初始即显示目标值——首渲染不做动画,避免数据未就绪时显示错误的 0
  const [display, setDisplay] = useState(value);
  const displayRef = useRef(value);
  const rafRef = useRef(0);

  useEffect(() => {
    const from = displayRef.current;
    if (from === value || !Number.isFinite(value)) return;

    const start = performance.now();
    const dur = Math.max(duration * 1000, 50);
    const tick = (now: number) => {
      const p = Math.min((now - start) / dur, 1);
      // ease-out cubic
      const eased = 1 - Math.pow(1 - p, 3);
      const current = from + (value - from) * eased;
      displayRef.current = current;
      setDisplay(current);
      if (p < 1) rafRef.current = requestAnimationFrame(tick);
    };
    rafRef.current = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(rafRef.current);
  }, [value, duration]);

  const formatted = Intl.NumberFormat("en-US", {
    useGrouping: separator,
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals,
  }).format(display);

  return (
    <span className={className} style={{ fontVariantNumeric: "tabular-nums" }}>
      {prefix}
      {formatted}
      {suffix}
    </span>
  );
}
