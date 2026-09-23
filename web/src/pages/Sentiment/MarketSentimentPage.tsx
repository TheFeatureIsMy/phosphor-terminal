import { Activity, ArrowRight, Database } from "lucide-react";
import { Link } from "react-router-dom";
import { PageHeader } from "@/components/shell/PageHeader";
import { VoltCard } from "@/components/shell/VoltCard";
import { EmptyState } from "@/components/shell/EmptyState";
import { FadeIn } from "@/components/effects/FadeIn";
import { useSentimentMarket } from "@/lib/hooks";
import { cn } from "@/lib/utils";

const STATE_LABELS: Record<string, { label: string; tone: string; hint: string }> = {
  healthy: { label: "正常", tone: "var(--bull)", hint: "情绪数据实时聚合中" },
  data_source_unavailable: { label: "数据源不可用", tone: "var(--bear)", hint: "情绪数据源未配置或连接失败" },
  degraded: { label: "降级", tone: "var(--warn)", hint: "部分情绪源不可用" },
};

const REASON_LABELS: Record<string, string> = {
  sentiment_records_empty: "暂无情绪记录,聚合器尚未产出数据",
  data_source_unavailable: "情绪数据源不可用",
};

export default function MarketSentimentPage() {
  const { data } = useSentimentMarket();
  const raw = (data ?? {}) as Record<string, unknown>;

  const stateKey = String(raw.state ?? "").toLowerCase();
  const stateInfo = STATE_LABELS[stateKey] ?? { label: "未知", tone: "var(--text-3)", hint: "" };
  const reasonCodes = Array.isArray(raw.reason_codes) ? (raw.reason_codes as string[]) : [];
  const overview = raw.market_overview && typeof raw.market_overview === "object"
    ? (raw.market_overview as Record<string, unknown>)
    : null;
  const overviewEntries = overview ? Object.entries(overview).slice(0, 12) : [];
  const hasData = overviewEntries.length > 0;

  return (
    <div className="mx-auto w-full max-w-[1340px] space-y-4 px-7 py-6">
      <FadeIn index={0}>
        <PageHeader
          eyebrow="MARKET SENTIMENT"
          title="市场情绪"
          subtitle="聚合新闻、社交与链上信号的市场情绪视图"
          trailing={
            <span
              className="flex items-center gap-1.5 rounded-lg px-3 py-1.5 text-[12px] font-semibold"
              style={{
                color: stateInfo.tone,
                background: `color-mix(in srgb, ${stateInfo.tone} 12%, transparent)`,
              }}
            >
              <span className="size-1.5 rounded-full" style={{ background: stateInfo.tone }} />
              {stateInfo.label}
            </span>
          }
        />
      </FadeIn>

      {/* 状态提示(数据源异常时) */}
      {(stateKey === "data_source_unavailable" || stateKey === "degraded") && (
        <FadeIn index={1}>
          <div className="flex items-center gap-3 rounded-[12px] border border-warn/20 bg-warn/10 px-4 py-3">
            <Database className="size-4 shrink-0 text-warn" />
            <div className="flex-1">
              <div className="text-[12.5px] font-semibold text-text">{stateInfo.hint}</div>
              {reasonCodes.length > 0 && (
                <div className="mt-0.5 text-[11.5px] text-text-2">
                  {reasonCodes.map((c) => REASON_LABELS[c] ?? c).join(";")}
                </div>
              )}
            </div>
            <Link
              to="/data-sources"
              className="flex shrink-0 items-center gap-1 rounded-lg border border-warn/25 bg-warn/10 px-2.5 py-1.5 text-[11.5px] font-semibold text-warn transition-colors hover:bg-warn/20"
            >
              数据源
              <ArrowRight className="size-3" />
            </Link>
          </div>
        </FadeIn>
      )}

      {/* 情绪总览 */}
      <FadeIn index={2}>
        <VoltCard spotlight className="p-[22px]">
          <div className="flex items-center gap-2 font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-2">
            <Activity className="size-4 text-accent-text" />
            市场总览
          </div>
          {hasData ? (
            <div className="mt-4 grid grid-cols-2 gap-x-10 gap-y-3">
              {overviewEntries.map(([k, v]) => (
                <div key={k} className="flex items-center justify-between border-b border-border/40 pb-2">
                  <span className="font-mono text-[11px] uppercase tracking-wide text-text-3">{k}</span>
                  <span className="tnum font-mono text-[13px] font-semibold text-text">
                    {typeof v === "number" ? v.toLocaleString() : String(v)}
                  </span>
                </div>
              ))}
            </div>
          ) : (
            <EmptyState
              icon={<Activity />}
              title="暂无情绪数据"
              description="情绪聚合器产出数据后,市场温度、多空情绪与社交热度会显示在这里。"
            />
          )}
        </VoltCard>
      </FadeIn>
    </div>
  );
}
