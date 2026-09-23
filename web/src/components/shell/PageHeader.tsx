import { useEffect, useRef, useState, type ReactNode } from "react";
import ShinyText from "@/components/reactbits/ShinyText/ShinyText";
import DecryptedText from "@/components/reactbits/DecryptedText/DecryptedText";
import { cn } from "@/lib/utils";

/** 每页面只播放一次解码动画(session 级) */
function useFirstVisit(key: string): boolean {
  const [first] = useState(() => {
    const k = `alphaloop-decrypt-${key}`;
    if (sessionStorage.getItem(k)) return false;
    sessionStorage.setItem(k, "1");
    return true;
  });
  return first;
}

/**
 * 全站统一页头(Swift QuantPageHeader + ReactBits 增强):
 * 电光竖条 + ShinyText 微光 eyebrow + DecryptedText 终端解码标题 + trailing + 发丝线。
 */
export function PageHeader({
  eyebrow,
  title,
  subtitle,
  trailing,
  className,
}: {
  eyebrow: string;
  title: string;
  subtitle?: string;
  trailing?: ReactNode;
  className?: string;
}) {
  const firstVisit = useFirstVisit(eyebrow);
  return (
    <div className={cn("space-y-3", className)}>
      <div className="flex items-baseline gap-4">
        <div className="flex items-center gap-2">
          {/* 电光竖条(页头签名) */}
          <span
            className="h-[30px] w-[3px] rounded-sm bg-accent"
            style={{ boxShadow: "0 0 5px color-mix(in srgb, var(--accent) 50%, transparent)" }}
          />
          <div className="space-y-1">
            <div className="font-mono text-[10px] font-semibold uppercase tracking-[0.16em]">
              <ShinyText
                text={"// " + eyebrow}
                speed={3}
                color="var(--accent-text)"
                shineColor="var(--accent-shine)"
                className="font-mono text-[10px] font-semibold uppercase tracking-[0.16em]"
              />
            </div>
            <h1 className="font-display text-[26px] font-bold leading-tight tracking-[-0.3px] text-text">
              {firstVisit ? (
                <DecryptedText
                  text={title}
                  animateOn="view"
                  speed={45}
                  maxIterations={14}
                  sequential
                  characters="01ABCDEX#/<>_-"
                />
              ) : (
                title
              )}
            </h1>
            {subtitle && <p className="text-[13px] text-text-2">{subtitle}</p>}
          </div>
        </div>
        <div className="flex-1" />
        {trailing}
      </div>
      <div className="h-px bg-border" />
    </div>
  );
}
