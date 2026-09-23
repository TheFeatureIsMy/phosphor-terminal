import { NavLink } from "react-router-dom";
import { ArrowUpRight } from "lucide-react";
import { LayoutGroup, motion } from "motion/react";
import { NAV_GROUPS } from "@/lib/nav";
import { cn } from "@/lib/utils";

/** VOLT logo mark:实心电光黄块 + 近黑箭头 */
function LogoMark({ size = 28 }: { size?: number }) {
  return (
    <span
      className="inline-flex items-center justify-center rounded-[8px] bg-accent"
      style={{ width: size, height: size }}
    >
      <ArrowUpRight className="text-on-accent" style={{ width: size * 0.62, height: size * 0.62 }} strokeWidth={3} />
    </span>
  );
}

export function Sidebar() {

  return (
    <aside className="flex w-[220px] shrink-0 flex-col border-r border-border bg-bg">
      {/* Logo */}
      <div className="flex h-14 items-center gap-2.5 px-4">
        <LogoMark />
        <span className="font-display text-[13px] font-black tracking-[0.05em] text-text">
          ALPHALOOP
        </span>
      </div>

      {/* 分组导航(layoutId 选中荧光块在菜单间滑动) */}
      <LayoutGroup id="sidebar">
      <nav className="flex-1 space-y-5 overflow-y-auto px-3 py-3">
        {NAV_GROUPS.map((group) => (
          <div key={group.label} className="space-y-1">
            <div className="px-2 pb-1 text-[11px] font-medium text-text-3">
              {group.label}
            </div>
            {group.routes.map((route) => (
              <NavLink
                key={route.id}
                to={route.path}
                end={route.path === "/"}
                className={({ isActive }) =>
                  cn(
                    "group relative flex items-center gap-2 rounded-[10px] px-2 py-[7px] text-[14px] transition-colors",
                    isActive
                      ? "font-medium text-on-nav-sel"
                      : "text-text-2 hover:bg-surface-hover hover:text-text"
                  )
                }
              >
                {({ isActive }) => (
                  <>
                    {/* 滑动选中荧光块(共享 layoutId) */}
                    {isActive && (
                      <motion.span
                        layoutId="nav-selection"
                        className="absolute inset-0 rounded-[10px] bg-nav-sel"
                        transition={{ type: "spring", stiffness: 420, damping: 34 }}
                      />
                    )}
                    {/* 选中指示竖条 */}
                    <span
                      className={cn(
                        "absolute left-0 top-1/2 z-10 h-4 w-[3px] -translate-y-1/2 rounded-sm",
                        isActive ? "bg-nav-sel-ind" : "bg-transparent"
                      )}
                    />
                    <span className="relative z-10 flex flex-1 items-center gap-2">
                      <route.icon
                        className={cn(
                          "size-[15px] shrink-0",
                          isActive ? "text-on-nav-sel" : "text-text-2 group-hover:text-text"
                        )}
                      />
                      <span className="flex-1 truncate">{route.label}</span>
                    </span>
                    {route.shortcut && (
                      <span
                        className={cn(
                          "relative z-10 font-mono text-[10px]",
                          isActive ? "text-on-nav-sel/55" : "text-text-3/50"
                        )}
                      >
                        ⌘{route.shortcut}
                      </span>
                    )}
                  </>
                )}
              </NavLink>
            ))}
          </div>
        ))}
      </nav>
      </LayoutGroup>

      {/* 底部 */}
      <div className="border-t border-border p-3">
        <div className="flex items-center gap-2 px-2 text-[11px] text-text-3">
          <LogoMark size={18} />
          <span className="font-mono">v3.0 · VOLT</span>
        </div>
      </div>
    </aside>
  );
}
