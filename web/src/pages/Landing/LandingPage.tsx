import { useEffect, useState } from "react";
import { ArrowUpRight } from "lucide-react";
import FadeContent from "@/components/reactbits/FadeContent/FadeContent";

/**
 * 启动过渡页(简约版):
 * 纯色深底 + LogoMark(复用侧栏标识) + 品牌名 + 细线进度条。
 * 无 WebGL/无故障/无金属液态/无解码打字,1.8s 后自动进入。
 */
export function LandingPage({ onDone }: { onDone: () => void }) {
  const [progress, setProgress] = useState(0);
  const [leaving, setLeaving] = useState(false);

  useEffect(() => {
    const start = performance.now();
    const dur = 1800;
    let raf = 0;
    const tick = (now: number) => {
      const p = Math.min((now - start) / dur, 1);
      setProgress(p);
      if (p < 1) raf = requestAnimationFrame(tick);
      else {
        setLeaving(true);
        window.setTimeout(onDone, 350);
      }
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [onDone]);

  return (
    <div
      className="flex h-full flex-col items-center justify-center bg-[#0a0a0c] transition-opacity duration-400 ease-out"
      style={{ opacity: leaving ? 0 : 1 }}
      onClick={() => {
        setLeaving(true);
        window.setTimeout(onDone, 250);
      }}
      title="点击进入"
    >
      <FadeContent duration={800} delay={100}>
        <div className="flex flex-col items-center gap-5">
          {/* Logo mark:与侧栏一致的实心电光黄块+箭头 */}
          <span className="inline-flex size-16 items-center justify-center rounded-[14px] bg-accent shadow-[0_0_30px_-4px_rgba(216,255,61,0.3)]">
            <ArrowUpRight className="text-on-accent" size={36} strokeWidth={3} />
          </span>

          <h1 className="font-display text-[28px] font-black tracking-[0.06em] text-[#f5f6f8]">
            ALPHALOOP
          </h1>

          {/* 极细进度条 */}
          <div className="mt-1 h-[2px] w-[180px] overflow-hidden rounded-full bg-[#1e1e25]">
            <div
              className="h-full rounded-full bg-accent transition-[width] duration-150 ease-out"
              style={{ width: `${progress * 100}%` }}
            />
          </div>
        </div>
      </FadeContent>

      <div className="absolute bottom-6 font-mono text-[10px] tracking-[0.3em] text-[#60656f]">
        VOLT TERMINAL · v3.0
      </div>
    </div>
  );
}