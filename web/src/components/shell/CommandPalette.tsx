import { useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { Command } from "cmdk";
import { ALL_ROUTES } from "@/lib/nav";

/** ⌘K 命令面板(cmdk)— 页面跳转 */
export function CommandPalette({
  open,
  onClose,
}: {
  open: boolean;
  onClose: () => void;
}) {
  const navigate = useNavigate();

  useEffect(() => {
    const down = (e: KeyboardEvent) => {
      if (e.key === "k" && (e.metaKey || e.ctrlKey)) {
        e.preventDefault();
        onClose();
      }
    };
    document.addEventListener("keydown", down);
    return () => document.removeEventListener("keydown", down);
  }, [onClose]);

  if (!open) return null;

  return (
    <div
      className="fixed inset-0 z-50 flex items-start justify-center bg-black/50 pt-[18vh]"
      onClick={onClose}
    >
      <div
        className="w-full max-w-[560px] overflow-hidden rounded-[16px] border border-border bg-card shadow-modal"
        onClick={(e) => e.stopPropagation()}
      >
        <Command label="全局命令面板">
          <div className="relative flex items-center gap-3 border-b border-border px-4">
            <span className="font-mono text-[15px] font-bold text-accent-text">❯</span>
            <Command.Input
              autoFocus
              placeholder="跳转页面 / 输入命令…"
              className="h-12 w-full bg-transparent font-mono text-[14px] tracking-wide text-text outline-none placeholder:text-text-3"
            />
            <kbd className="rounded-md border border-border bg-surface px-1.5 py-0.5 font-mono text-[10px] text-text-3">
              ⌘K
            </kbd>
            {/* focus 时的底部电光扫描线 */}
            <span className="pointer-events-none absolute inset-x-0 bottom-0 h-px bg-gradient-to-r from-transparent via-accent to-transparent opacity-70" />
          </div>
          <Command.List className="max-h-[320px] overflow-y-auto p-2">
            <Command.Empty className="py-8 text-center text-[13px] text-text-3">
              无匹配结果
            </Command.Empty>
            <Command.Group
              heading="页面"
              className="px-2 py-1.5 text-[11px] font-medium text-text-3"
            >
              {ALL_ROUTES.map((route) => (
                <Command.Item
                  key={route.id}
                  value={`${route.label} ${route.id}`}
                  onSelect={() => {
                    navigate(route.path);
                    onClose();
                  }}
                  className="flex cursor-pointer items-center gap-2.5 rounded-lg px-3 py-2.5 text-[14px] text-text-2 aria-selected:bg-nav-sel aria-selected:text-on-nav-sel"
                >
                  <route.icon className="size-4" />
                  {route.label}
                  {route.shortcut && (
                    <span className="ml-auto font-mono text-[10px] opacity-50">
                      ⌘{route.shortcut}
                    </span>
                  )}
                </Command.Item>
              ))}
            </Command.Group>
          </Command.List>
        </Command>
      </div>
    </div>
  );
}
