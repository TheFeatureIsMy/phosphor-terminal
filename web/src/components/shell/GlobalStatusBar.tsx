import { useState } from "react";
import { useLocation } from "react-router-dom";
import { Bell, Moon, OctagonAlert, Search, SunMedium } from "lucide-react";
import { EmergencyStopDialog } from "./EmergencyStopDialog";
import { NotificationPopover } from "./NotificationPopover";
import { useGlobalStatus } from "@/lib/hooks";
import { routeByPath } from "@/lib/nav";
import { useTheme } from "@/theme/ThemeProvider";
import { cn } from "@/lib/utils";

function StatusDot({ ok, warn }: { ok?: boolean; warn?: boolean }) {
  return (
    <span
      className={cn(
        "inline-block size-1.5 rounded-full",
        ok ? "bg-bull" : warn ? "bg-warn" : "bg-bear"
      )}
    />
  );
}

function StatusItem({
  label,
  value,
  tone,
}: {
  label: string;
  value: string;
  tone: "ok" | "warn" | "bad";
}) {
  return (
    <span className="flex items-center gap-1.5">
      <StatusDot ok={tone === "ok"} warn={tone === "warn"} />
      <span className="text-text-3">{label}</span>
      <span className="font-semibold text-text">{value}</span>
    </span>
  );
}

export function GlobalStatusBar({
  onOpenPalette,
}: {
  onOpenPalette: () => void;
}) {
  const { pathname } = useLocation();
  const route = routeByPath(pathname);
  const { data: status } = useGlobalStatus();
  const { isDark, toggle } = useTheme();
  const [showEmergency, setShowEmergency] = useState(false);
  const [showNotifications, setShowNotifications] = useState(false);

  const exchangeOk = status?.exchange_state?.toLowerCase() === "ok";
  const engineOk = status?.freqtrade_state?.toLowerCase() !== "unavailable";
  const riskNormal = status?.risk_state?.toLowerCase() === "normal";

  return (
    <header className="border-b border-border bg-bg">
      {/* Row 1:breadcrumb / mode / actions */}
      <div className="flex h-14 items-center gap-3 px-6">
        {route.id !== "dashboard" ? (
          <span className="font-body text-[12px] font-semibold uppercase tracking-[0.06em] text-accent-text">
            {route.label}
          </span>
        ) : (
          <span className="font-display text-[13px] font-black tracking-[0.5px] text-on-accent bg-accent px-2.5 py-1 [clip-path:polygon(0_0,100%_0,calc(100%-6px)_100%,0_100%)]">
            ALPHALOOP
          </span>
        )}

        {/* 模式 pill */}
        <span className="ml-1 flex items-center gap-1.5 rounded-lg bg-accent-soft px-2.5 py-1 font-mono text-[10.5px] font-semibold uppercase tracking-wider text-accent-text">
          <span className="inline-block size-3.5 rounded-[4px] bg-accent-text/20 text-center leading-[14px]">
            ▤
          </span>
          模拟 PAPER
        </span>

        <div className="flex-1" />

        <button
          className="rounded-lg p-2 text-text-2 transition-colors hover:bg-surface-hover hover:text-text"
          title="中 / EN"
        >
          <span className="text-[12px] font-medium">中</span>
        </button>
        <button
          onClick={toggle}
          className="rounded-lg p-2 text-text-2 transition-colors hover:bg-surface-hover hover:text-text"
          title={isDark ? "切换到明亮" : "切换到暗黑"}
        >
          {isDark ? <Moon className="size-4" /> : <SunMedium className="size-4" />}
        </button>
        <button
          onClick={onOpenPalette}
          className="rounded-lg p-2 text-text-2 transition-colors hover:bg-surface-hover hover:text-text"
          title="搜索 / 命令 (⌘K)"
        >
          <Search className="size-4" />
        </button>
        <button
          onClick={() => setShowNotifications((v) => !v)}
          className="rounded-lg p-2 text-text-2 transition-colors hover:bg-surface-hover hover:text-text"
          title="通知"
        >
          <Bell className="size-4" />
        </button>

        <button
          onClick={() => setShowEmergency(true)}
          className="ml-2 flex items-center gap-1.5 rounded-lg bg-bear/12 px-3 py-1.5 text-[12px] font-semibold text-bear transition-colors hover:bg-bear/20"
        >
          <OctagonAlert className="size-3.5" />
          紧急停止
        </button>
      </div>

      {/* Row 2:状态行 */}
      <div className="flex h-9 items-center gap-6 border-t border-border/60 px-6 font-mono text-[11px]">
        <span className="flex items-center gap-1.5 text-text-3">
          <StatusDot warn />
          PROVIDER —
        </span>
        <StatusItem label="交易所" value={exchangeOk ? "OK" : "ERR"} tone={exchangeOk ? "ok" : "bad"} />
        <StatusItem label="缓存" value={`${status?.redis_rtt_ms ?? 0}ms`} tone="ok" />
        <StatusItem
          label="交易引擎"
          value={engineOk ? "OK" : "UNAVAILABLE"}
          tone={engineOk ? "ok" : "bad"}
        />
        <StatusItem label="风险" value={status?.risk_state?.toUpperCase() ?? "—"} tone={riskNormal ? "ok" : "warn"} />
        <StatusItem label="持仓" value={`${status?.open_positions ?? 0}`} tone="ok" />
        <div className="flex-1" />
        <span className="text-text-3">
          最近更新{" "}
          {new Date().toLocaleTimeString("zh-CN", { hour12: false })}
        </span>
      </div>
      {showEmergency && <EmergencyStopDialog onClose={() => setShowEmergency(false)} />}
      {showNotifications && <NotificationPopover onClose={() => setShowNotifications(false)} />}
    </header>
  );
}
