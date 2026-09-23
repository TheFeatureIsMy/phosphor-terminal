import { useMemo, useState } from "react";
import { AlertTriangle, Archive, ArrowRight, Eye, Radio, X } from "lucide-react";
import { PageHeader } from "@/components/shell/PageHeader";
import { VoltButton } from "@/components/shell/VoltButton";
import { VoltCard } from "@/components/shell/VoltCard";
import { FadeIn } from "@/components/effects/FadeIn";
import {
  useObservePaper,
  usePublishToStrategy,
  useSignalArchive,
  useSignalDetail,
  useSignalNextActions,
  useSignals,
  useSignalTransition,
} from "@/lib/hooks";
import type { SignalSummary } from "@/lib/types";
import { cn } from "@/lib/utils";

/* 币种色(对齐 Swift signalSymbolColor) */
const SYMBOL_COLORS: Record<string, string> = {
  BTC: "#F7931A",
  ETH: "#627EEA",
  SOL: "#14F195",
  AVAX: "#E84142",
  LINK: "#2A5ADA",
  PEPE: "#4CAF50",
  DOGE: "#C2A633",
  ARB: "#28A0F0",
};
function symbolColor(symbol: string) {
  const base = symbol.split("/")[0]?.toUpperCase() ?? symbol;
  return SYMBOL_COLORS[base] ?? "var(--accent)";
}
function symbolInitials(symbol: string) {
  const base = symbol.split("/")[0] ?? symbol;
  return base.slice(0, 2).toUpperCase();
}

const SOURCES = ["全部", "AI研究", "TradingAgents", "手动", "Canvas"];
const SYMBOLS = ["全部", "BTC", "ETH", "SOL", "PEPE"];
const DIRECTIONS = ["全部", "Long", "Short", "Hold"];
const STATUSES = ["全部", "active", "pending", "rejected"];
const SORTS = ["评分 高→低", "置信度 高→低", "有效期 近→远"];

function directionChip(d: string) {
  const k = d.toLowerCase();
  if (k === "long") return "bg-bull/12 text-bull";
  if (k === "short") return "bg-bear/12 text-bear";
  return "bg-surface text-text-2";
}

function riskChip(r: string) {
  const k = r.toLowerCase();
  if (k === "low") return "bg-bull/12 text-bull";
  if (k === "medium") return "bg-warn/12 text-warn";
  return "bg-bear/12 text-bear";
}

function statusChip(s: string) {
  const k = s.toLowerCase();
  if (k === "active") return "bg-bull/12 text-bull";
  if (k === "pending") return "bg-warn/12 text-warn";
  if (k === "expired") return "bg-surface text-text-3";
  return "bg-bear/12 text-bear";
}

function FilterRow({
  label,
  options,
  value,
  onChange,
}: {
  label: string;
  options: string[];
  value: string;
  onChange: (v: string) => void;
}) {
  return (
    <div className="flex items-center gap-2.5">
      <span className="w-8 text-[13px] text-text-2">{label}</span>
      <div className="flex flex-wrap gap-1.5">
        {options.map((opt) => (
          <button
            key={opt}
            onClick={() => onChange(opt)}
            className={cn(
              "rounded-lg px-3 py-1.5 text-[12.5px] font-medium transition-colors",
              value === opt
                ? "bg-accent-soft text-accent-text"
                : "bg-surface text-text-2 hover:bg-surface-hover hover:text-text"
            )}
          >
            {opt}
          </button>
        ))}
      </div>
    </div>
  );
}

export default function SignalCenterPage() {
  const { data: signals } = useSignals();
  const [source, setSource] = useState("全部");
  const [symbol, setSymbol] = useState("全部");
  const [direction, setDirection] = useState("全部");
  const [status, setStatus] = useState("全部");
  const [sort, setSort] = useState(SORTS[0]);
  const [selectedId, setSelectedId] = useState<string | null>(null);

  const all = signals ?? [];
  const stats = useMemo(() => {
    const count = (pred: (s: SignalSummary) => boolean) => all.filter(pred).length;
    return {
      total: all.length,
      active: count((s) => s.status === "active"),
      pending: count((s) => s.status === "pending"),
      expired: count((s) => s.status === "expired"),
      rejected: count((s) => s.status === "rejected"),
    };
  }, [all]);

  const conflicts = useMemo(() => {
    const bySymbol = new Map<string, Set<string>>();
    all.filter((s) => s.status === "active").forEach((s) => {
      const set = bySymbol.get(s.symbol) ?? new Set<string>();
      set.add(s.direction.toLowerCase());
      bySymbol.set(s.symbol, set);
    });
    return [...bySymbol.entries()].filter(([, dirs]) => dirs.has("long") && dirs.has("short")).length;
  }, [all]);

  const filtered = useMemo(() => {
    let list = [...all];
    if (source !== "全部") list = list.filter((s) => s.source_type.includes(source));
    if (symbol !== "全部") list = list.filter((s) => s.symbol.includes(symbol));
    if (direction !== "全部") list = list.filter((s) => s.direction.toLowerCase() === direction.toLowerCase());
    if (status !== "全部") list = list.filter((s) => s.status === status);
    if (sort === SORTS[0]) list.sort((a, b) => (b.score ?? 0) - (a.score ?? 0));
    else if (sort === SORTS[1]) list.sort((a, b) => b.confidence - a.confidence);
    else list.sort((a, b) => new Date(a.expires_at).getTime() - new Date(b.expires_at).getTime());
    return list;
  }, [all, source, symbol, direction, status, sort]);

  const statCards: { label: string; value: number; color?: string }[] = [
    { label: "在场 Signal", value: stats.total, color: "var(--accent-text)" },
    { label: "active", value: stats.active, color: "var(--bull)" },
    { label: "pending", value: stats.pending, color: "var(--warn)" },
    { label: "expired", value: stats.expired },
    { label: "rejected", value: stats.rejected, color: "var(--bear)" },
    { label: "冲突待裁决", value: conflicts, color: conflicts > 0 ? "var(--bear)" : "var(--accent-text)" },
  ];

  return (
    <div className="mx-auto w-full max-w-[1340px] space-y-4 px-7 py-6">
      <FadeIn index={0}>
        <PageHeader
          eyebrow="SIGNAL CENTER · 信号中枢"
          title="所有交易观点,汇聚一处裁决"
          subtitle="AI、模型、研究、情绪、因子与操控雷达的结果统一生成 Signal,在此判断可信度、生命周期与冲突,再决定发布到策略。"
        />
      </FadeIn>

      {/* 统计卡行 */}
      <FadeIn index={1}>
        <div className="grid grid-cols-6 gap-3">
          {statCards.map((c) => (
            <VoltCard key={c.label} className="px-4 py-3">
              <div className="text-[12px] text-text-2">{c.label}</div>
              <div
                className="tnum mt-1 font-display text-[26px] font-bold leading-none"
                style={{ color: c.color ?? "var(--text)" }}
              >
                {c.value}
              </div>
            </VoltCard>
          ))}
        </div>
      </FadeIn>

      {/* 过滤卡 */}
      <FadeIn index={2}>
        <VoltCard className="space-y-3 p-5">
          <FilterRow label="来源" options={SOURCES} value={source} onChange={setSource} />
          <FilterRow label="标的" options={SYMBOLS} value={symbol} onChange={setSymbol} />
          <FilterRow label="方向" options={DIRECTIONS} value={direction} onChange={setDirection} />
          <FilterRow label="状态" options={STATUSES} value={status} onChange={setStatus} />
          <FilterRow label="排序" options={SORTS} value={sort} onChange={setSort} />
        </VoltCard>
      </FadeIn>

      {/* 冲突裁决条 */}
      <FadeIn index={3}>
        <div className="flex items-center gap-2.5 text-[13px]">
          <AlertTriangle className="size-4 text-warn" />
          <span className="font-semibold text-text">冲突检测 · 需人工裁决</span>
          <span className="text-text-3">{conflicts} 组待裁决</span>
        </div>
        <div className="text-[13px] text-text-2">当前无多空冲突</div>
      </FadeIn>

      {/* 信号表 */}
      <FadeIn index={4}>
        <VoltCard className="overflow-hidden">
          {filtered.length === 0 ? (
            <div className="flex flex-col items-center gap-3 py-16">
              <Radio className="size-8 text-accent-text" />
              <div className="text-[15px] font-semibold text-text">暂无信号</div>
              <div className="text-[13px] text-text-2">
                AI 研究、模型与雷达产出的观点会在这里汇聚。
              </div>
            </div>
          ) : (
            <table className="w-full text-[13px]">
              <thead>
                <tr className="border-b border-border text-left font-mono text-[10px] uppercase tracking-[0.08em] text-text-3">
                  <th className="px-5 py-3 font-medium">标的</th>
                  <th className="px-3 py-3 font-medium">方向</th>
                  <th className="px-3 py-3 font-medium">评分</th>
                  <th className="px-3 py-3 font-medium">置信度</th>
                  <th className="px-3 py-3 font-medium">风险</th>
                  <th className="px-3 py-3 font-medium">状态</th>
                  <th className="px-3 py-3 font-medium">来源</th>
                  <th className="px-5 py-3 font-medium">有效期</th>
                </tr>
              </thead>
              <tbody>
                {filtered.map((s) => (
                  <tr
                    key={s.id}
                    onClick={() => setSelectedId(s.id)}
                    className="cursor-pointer border-b border-border/50 transition-colors last:border-0 hover:bg-surface-hover"
                  >
                    <td className="px-5 py-3">
                      <div className="flex items-center gap-2.5">
                        <span
                          className="flex size-[30px] items-center justify-center rounded-[9px] font-display text-[12px] font-bold text-on-accent"
                          style={{ background: symbolColor(s.symbol) }}
                        >
                          {symbolInitials(s.symbol)}
                        </span>
                        <span className="font-semibold text-text">{s.symbol}</span>
                      </div>
                    </td>
                    <td className="px-3 py-3">
                      <span className={cn("rounded-md px-2 py-0.5 text-[11.5px] font-semibold", directionChip(s.direction))}>
                        {s.direction}
                      </span>
                    </td>
                    <td className="tnum px-3 py-3 font-mono font-semibold text-text">
                      {s.score?.toFixed(1) ?? "—"}
                    </td>
                    <td className="tnum px-3 py-3 font-mono text-text-2">
                      {Math.round(s.confidence * 100)}%
                    </td>
                    <td className="px-3 py-3">
                      <span className={cn("rounded-md px-2 py-0.5 text-[11.5px] font-semibold", riskChip(s.risk_level))}>
                        {s.risk_level}
                      </span>
                    </td>
                    <td className="px-3 py-3">
                      <span className={cn("rounded-md px-2 py-0.5 text-[11.5px] font-semibold", statusChip(s.status))}>
                        {s.status}
                      </span>
                    </td>
                    <td className="px-3 py-3 text-text-2">{s.source_type}</td>
                    <td className="px-5 py-3 font-mono text-[12px] text-text-3">
                      {new Date(s.expires_at).toLocaleDateString("zh-CN")}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </VoltCard>
      </FadeIn>

      {/* 信号详情抽屉 */}
      {selectedId && (
        <SignalDetailDrawer signalId={selectedId} onClose={() => setSelectedId(null)} />
      )}
    </div>
  );
}

/* ---------- 信号详情抽屉 ---------- */

function SignalDetailDrawer({ signalId, onClose }: { signalId: string; onClose: () => void }) {
  const { data: detail } = useSignalDetail(signalId);
  const { data: actions } = useSignalNextActions(signalId);
  const transition = useSignalTransition();
  const archive = useSignalArchive();
  const publish = usePublishToStrategy();
  const observe = useObservePaper();
  const [msg, setMsg] = useState("");

  const d = detail as Record<string, unknown> | undefined;
  const status = String(d?.status ?? "");

  const doAction = (type: string) => {
    setMsg("");
    const onSuccess = () => setMsg("操作成功");
    const onError = (e: unknown) => setMsg(e instanceof Error ? e.message : "操作失败");
    switch (type) {
      case "transition_active":
        transition.mutate({ id: signalId, target_status: "active" }, { onSuccess, onError });
        break;
      case "reject":
        transition.mutate({ id: signalId, target_status: "rejected", reason: "manual_reject" }, { onSuccess, onError });
        break;
      case "publish_to_strategy":
        publish.mutate(signalId, { onSuccess, onError });
        break;
      case "observe_in_dryrun":
        observe.mutate(signalId, { onSuccess, onError });
        break;
      case "archive":
        archive.mutate(signalId, { onSuccess, onError });
        break;
      default:
        setMsg(`暂不支持: ${type}`);
    }
  };

  const pending = transition.isPending || archive.isPending || publish.isPending || observe.isPending;

  return (
    <div className="fixed inset-0 z-50 flex justify-end bg-black/40" onClick={onClose}>
      <div
        className="flex h-full w-[420px] flex-col border-l border-border bg-card shadow-modal"
        onClick={(e) => e.stopPropagation()}
      >
        {/* 头部 */}
        <div className="flex items-center justify-between border-b border-border px-5 py-4">
          <div className="text-[15px] font-bold text-text">信号详情</div>
          <button onClick={onClose} className="rounded-lg p-1.5 text-text-3 hover:bg-surface-hover hover:text-text">
            <X className="size-4" />
          </button>
        </div>

        {/* 内容 */}
        <div className="flex-1 space-y-4 overflow-y-auto p-5">
          {!d ? (
            <div className="space-y-3">
              {[0, 1, 2].map((i) => (
                <div key={i} className="h-10 animate-pulse rounded-lg bg-surface" style={{ opacity: 1 - i * 0.2 }} />
              ))}
            </div>
          ) : (
            <>
              {/* 基本信息 */}
              <div className="space-y-2.5">
                <div className="flex items-center gap-2.5">
                  <span className="font-display text-[18px] font-bold text-text">{String(d.symbol ?? "—")}</span>
                  <span className={cn("rounded-md px-2 py-0.5 text-[11.5px] font-semibold", directionChip(String(d.direction ?? "")))}>
                    {String(d.direction ?? "—")}
                  </span>
                  <span className={cn("rounded-md px-2 py-0.5 text-[11.5px] font-semibold", statusChip(status))}>
                    {status}
                  </span>
                </div>
                <div className="grid grid-cols-2 gap-x-6 gap-y-2">
                  {[
                    ["评分", d.score != null ? Number(d.score).toFixed(1) : "—"],
                    ["置信度", d.confidence != null ? `${Math.round(Number(d.confidence) * 100)}%` : "—"],
                    ["风险等级", String(d.risk_level ?? "—")],
                    ["来源", String(d.source_type ?? "—")],
                    ["创建时间", d.created_at ? new Date(String(d.created_at)).toLocaleString("zh-CN", { hour12: false }) : "—"],
                    ["有效期", d.expires_at ? new Date(String(d.expires_at)).toLocaleString("zh-CN", { hour12: false }) : "—"],
                  ].map(([k, v]) => (
                    <div key={String(k)}>
                      <div className="font-mono text-[10px] uppercase tracking-[0.08em] text-text-3">{k}</div>
                      <div className="tnum mt-0.5 font-mono text-[13px] font-semibold text-text">{v}</div>
                    </div>
                  ))}
                </div>
              </div>

              {/* 理由 */}
              {d.reasoning != null && (
                <div>
                  <div className="font-mono text-[10px] font-semibold uppercase tracking-[0.08em] text-text-3">理由</div>
                  <div className="mt-1.5 rounded-lg bg-surface p-3 text-[12.5px] leading-relaxed text-text-2">
                    {String(d.reasoning)}
                  </div>
                </div>
              )}

              {/* 操作反馈 */}
              {msg && (
                <div className="rounded-lg bg-accent-soft px-3 py-2 text-[12px] font-medium text-accent-text">
                  {msg}
                </div>
              )}
            </>
          )}
        </div>

        {/* 底部操作 */}
        {actions && actions.next_actions.length > 0 && (
          <div className="border-t border-border p-4">
            <div className="font-mono text-[10px] font-semibold uppercase tracking-[0.08em] text-text-3">
              可用操作
            </div>
            <div className="mt-2.5 flex flex-wrap gap-2">
              {actions.next_actions.map((a) => (
                <VoltButton
                  key={a.type}
                  size="sm"
                  variant={a.type === "reject" ? "danger" : a.type === "archive" ? "secondary" : "primary"}
                  disabled={!a.enabled || pending}
                  onClick={() => doAction(a.type)}
                  icon={a.type === "archive" ? <Archive /> : a.type === "observe_in_dryrun" ? <Eye /> : <ArrowRight />}
                >
                  {a.label}
                </VoltButton>
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
