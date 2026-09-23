import { useEffect, useRef, useState } from "react";
import { createPortal } from "react-dom";
import { AnimatePresence, motion } from "motion/react";
import { Check, ChevronDown } from "lucide-react";
import { cn } from "@/lib/utils";

export interface VoltSelectOption {
  value: string;
  label: string;
}

/**
 * VOLT 自定义下拉(替代原生 select):
 * mono 标签 + 电光 chevron + 终端风弹层(accent 选中/对勾/交错入场)。
 * 支持点击外部/Esc 关闭,键盘上下选择。
 */
export function VoltSelect({
  label,
  value,
  options,
  placeholder = "未选择",
  onChange,
}: {
  label: string;
  value: string;
  options: VoltSelectOption[];
  placeholder?: string;
  onChange: (v: string) => void;
}) {
  const [open, setOpen] = useState(false);
  const [hoverIdx, setHoverIdx] = useState(-1);
  const [pos, setPos] = useState({ left: 0, top: 0, width: 0 });
  const rootRef = useRef<HTMLDivElement>(null);

  const selected = options.find((o) => o.value === value);

  // 弹层 portal 到 body,不被卡片 overflow 截断
  const openDropdown = () => {
    const rect = rootRef.current?.getBoundingClientRect();
    if (rect) setPos({ left: rect.left, top: rect.bottom + 6, width: rect.width });
    setOpen((v) => !v);
  };

  useEffect(() => {
    if (!open) return;
    const onDown = (e: MouseEvent) => {
      if (rootRef.current && !rootRef.current.contains(e.target as Node)) {
        setOpen(false);
      }
    };
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") setOpen(false);
      if (e.key === "ArrowDown" || e.key === "ArrowUp") {
        e.preventDefault();
        setHoverIdx((i) => {
          const next = e.key === "ArrowDown" ? i + 1 : i - 1;
          return Math.max(0, Math.min(options.length - 1, next < 0 ? 0 : next));
        });
      }
      if (e.key === "Enter" && hoverIdx >= 0 && options[hoverIdx]) {
        onChange(options[hoverIdx].value);
        setOpen(false);
      }
    };
    document.addEventListener("mousedown", onDown);
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("mousedown", onDown);
      document.removeEventListener("keydown", onKey);
    };
  }, [open, hoverIdx, options, onChange]);

  return (
    <div ref={rootRef} className="relative">
      {/* 触发按钮 */}
      <button
        type="button"
        onClick={openDropdown}
        className={cn(
          "block w-full rounded-[10px] border bg-surface px-4 py-3 text-left transition-colors",
          open ? "border-accent-text/50" : "border-border hover:border-border-hover"
        )}
      >
        <div className="font-mono text-[10px] uppercase tracking-[0.08em] text-text-3">
          {label}
        </div>
        <div className="mt-1 flex items-center justify-between">
          <span className={cn("text-[14px] font-semibold", selected ? "text-text" : "text-text-3")}>
            {selected?.label ?? placeholder}
          </span>
          <ChevronDown
            className={cn(
              "size-4 transition-transform duration-200",
              open ? "rotate-180 text-accent-text" : "text-text-3"
            )}
          />
        </div>
      </button>

      {/* 弹层(portal 到 body,fixed 定位,不被卡片截断) */}
      {createPortal(
        <AnimatePresence>
        {open && (
          <motion.div
            initial={{ opacity: 0, y: -6, scale: 0.98 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: -4, scale: 0.98 }}
            transition={{ duration: 0.15, ease: "easeOut" }}
            className="fixed z-[90] overflow-hidden rounded-[12px] border border-border bg-surface-elevated shadow-modal"
            style={{ left: pos.left, top: pos.top, width: pos.width }}
          >
            {/* 清除选择 */}
            <button
              onClick={() => {
                onChange("");
                setOpen(false);
              }}
              className="flex w-full items-center gap-2.5 border-b border-border/60 px-3.5 py-2.5 text-left text-[13px] text-text-3 transition-colors hover:bg-surface-hover hover:text-text"
            >
              <span className="size-3.5" />
              {placeholder}
            </button>

            {options.map((o, i) => {
              const active = o.value === value;
              return (
                <motion.button
                  key={o.value}
                  initial={{ opacity: 0, x: -6 }}
                  animate={{ opacity: 1, x: 0 }}
                  transition={{ delay: 0.02 + i * 0.025, duration: 0.16 }}
                  onMouseEnter={() => setHoverIdx(i)}
                  onClick={() => {
                    onChange(o.value);
                    setOpen(false);
                  }}
                  className={cn(
                    "flex w-full items-center gap-2.5 px-3.5 py-2.5 text-left text-[13px] font-medium transition-colors",
                    active
                      ? "bg-accent-soft text-accent-text"
                      : hoverIdx === i
                        ? "bg-surface-hover text-text"
                        : "text-text-2"
                  )}
                >
                  {active ? (
                    <Check className="size-3.5 shrink-0" />
                  ) : (
                    <span className="size-3.5 shrink-0" />
                  )}
                  <span className="flex-1 truncate">{o.label}</span>
                  {active && (
                    <span className="size-1.5 rounded-full bg-accent-text" />
                  )}
                </motion.button>
              );
            })}
            {options.length === 0 && (
              <div className="px-3.5 py-6 text-center text-[12px] text-text-3">
                暂无可选项
              </div>
            )}
          </motion.div>
        )}
      </AnimatePresence>,
        document.body
      )}
    </div>
  );
}
