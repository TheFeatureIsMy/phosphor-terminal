import { useEffect, useState } from "react";
import { Bell, Check, Database, Moon, Palette, Play, Plus, Settings2, SlidersHorizontal, SunMedium, Trash2, X } from "lucide-react";
import { EmptyState } from "@/components/shell/EmptyState";
import { PageHeader } from "@/components/shell/PageHeader";
import { VoltButton } from "@/components/shell/VoltButton";
import { VoltCard } from "@/components/shell/VoltCard";
import { FadeIn } from "@/components/effects/FadeIn";
import {
  useAlertRules,
  useCreateAlertRule,
  useDeleteAlertRule,
  useEvaluateAlertRules,
  useSystemSettings,
  useUpdateSystemSetting,
} from "@/lib/hooks";
import { useTheme } from "@/theme/ThemeProvider";
import { cn } from "@/lib/utils";

const GROUPS = [
  { id: "appearance", label: "外观", icon: Palette },
  { id: "alerts", label: "告警规则", icon: Bell },
  { id: "system", label: "系统参数", icon: SlidersHorizontal },
  { id: "advanced", label: "高级", icon: Settings2 },
] as const;

type GroupId = (typeof GROUPS)[number]["id"];

/* ---------------- 外观 ---------------- */

function AppearanceSection() {
  const { theme, setTheme } = useTheme();
  const options = [
    { id: "dark" as const, label: "VOLT Terminal", desc: "近黑底盘 · 霓虹数据色 · 电光发光(夜盘终端)", icon: Moon },
    { id: "light" as const, label: "VOLT Daylight", desc: "纯白底盘 · 油墨数据色 · 柔和纸面阴影(日间研究)", icon: SunMedium },
  ];
  return (
    <VoltCard className="p-[22px]">
      <div className="font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-2">
        主题
      </div>
      <div className="mt-4 grid grid-cols-2 gap-3">
        {options.map((o) => {
          const active = theme === o.id;
          return (
            <button
              key={o.id}
              onClick={() => setTheme(o.id)}
              className={cn(
                "flex items-start gap-3 rounded-[12px] border p-4 text-left transition-colors",
                active
                  ? "border-accent-text/50 bg-accent-soft"
                  : "border-border bg-surface hover:border-border-hover"
              )}
            >
              <span className={cn(
                "flex size-9 shrink-0 items-center justify-center rounded-[9px]",
                active ? "bg-accent text-on-accent" : "bg-surface-hover text-text-2"
              )}>
                <o.icon className="size-4" />
              </span>
              <span className="min-w-0 flex-1">
                <span className="flex items-center gap-2 text-[14px] font-semibold text-text">
                  {o.label}
                  {active && <Check className="size-3.5 text-accent-text" />}
                </span>
                <span className="mt-1 block text-[11.5px] leading-relaxed text-text-3">{o.desc}</span>
              </span>
            </button>
          );
        })}
      </div>
    </VoltCard>
  );
}

/* ---------------- 系统参数(可编辑键值) ---------------- */

function SystemSection() {
  const { data: settings } = useSystemSettings();
  const update = useUpdateSystemSetting();
  const [editKey, setEditKey] = useState<string | null>(null);
  const [editValue, setEditValue] = useState("");

  return (
    <VoltCard spotlight className="overflow-hidden">
      {(settings ?? []).length === 0 ? (
        <EmptyState compact icon={<SlidersHorizontal />} title="暂无系统设置项" description="后端 /api/admin/system-settings 当前没有已注册的参数。" />
      ) : (
        <table className="w-full text-[13px]">
          <thead>
            <tr className="border-b border-border text-left font-mono text-[10px] uppercase tracking-[0.08em] text-text-3">
              <th className="px-5 py-3 font-medium">键</th>
              <th className="px-3 py-3 font-medium">分类</th>
              <th className="px-3 py-3 font-medium">值</th>
              <th className="px-3 py-3 font-medium">更新</th>
              <th className="px-5 py-3 font-medium" />
            </tr>
          </thead>
          <tbody>
            {settings!.map((s) => {
              const key = String((s as Record<string, unknown>).key);
              const editing = editKey === key;
              return (
                <tr key={key} className="border-b border-border/50 transition-colors last:border-0 hover:bg-surface-hover">
                  <td className="px-5 py-3 font-mono font-semibold text-text">{key}</td>
                  <td className="px-3 py-3">
                    <span className="rounded-md bg-surface px-2 py-0.5 font-mono text-[11px] text-text-2">
                      {String((s as Record<string, unknown>).category ?? "general")}
                    </span>
                  </td>
                  <td className="max-w-[260px] px-3 py-3">
                    {editing ? (
                      <textarea
                        value={editValue}
                        onChange={(e) => setEditValue(e.target.value)}
                        rows={2}
                        className="w-full rounded-lg border border-accent-text/50 bg-surface px-2.5 py-1.5 font-mono text-[12px] text-text outline-none"
                      />
                    ) : (
                      <span className="block truncate font-mono text-[12px] text-text-2">
                        {typeof (s as Record<string, unknown>).value === "string"
                          ? String((s as Record<string, unknown>).value)
                          : JSON.stringify((s as Record<string, unknown>).value)}
                      </span>
                    )}
                  </td>
                  <td className="px-3 py-3 font-mono text-[11px] text-text-3">
                    {(s as Record<string, unknown>).updated_at
                      ? new Date(String((s as Record<string, unknown>).updated_at)).toLocaleDateString("zh-CN")
                      : "—"}
                  </td>
                  <td className="px-5 py-3 text-right">
                    {editing ? (
                      <span className="flex justify-end gap-1.5">
                        <button
                          onClick={() => {
                            try {
                              const value = JSON.parse(editValue);
                              update.mutate(
                                { key, value, category: String((s as Record<string, unknown>).category ?? "general") },
                                { onSuccess: () => setEditKey(null) }
                              );
                            } catch {
                              /* JSON 非法时静默保持编辑态 */
                            }
                          }}
                          className="rounded-lg bg-accent px-2.5 py-1 text-[11.5px] font-semibold text-on-accent"
                        >
                          保存
                        </button>
                        <button
                          onClick={() => setEditKey(null)}
                          className="rounded-lg border border-border px-2.5 py-1 text-[11.5px] text-text-2"
                        >
                          取消
                        </button>
                      </span>
                    ) : (
                      <button
                        onClick={() => {
                          setEditKey(key);
                          setEditValue(JSON.stringify((s as Record<string, unknown>).value, null, 2));
                        }}
                        className="rounded-lg border border-border px-2.5 py-1 text-[11.5px] font-medium text-text-2 hover:border-border-hover hover:text-text"
                      >
                        编辑
                      </button>
                    )}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      )}
    </VoltCard>
  );
}

/* ---------------- 高级 ---------------- */

function AdvancedSection() {
  const { data: settings } = useSystemSettings();
  const retentionSettings = (settings ?? []).filter(
    (s) => String((s as Record<string, unknown>).category) === "retention"
  );

  return (
    <div className="space-y-4">
      {/* 数据保留 */}
      <VoltCard className="p-[22px]">
        <div className="flex items-center gap-2 font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-2">
          <Database className="size-4 text-accent-text" />
          数据保留策略
        </div>
        {retentionSettings.length > 0 ? (
          <div className="mt-4 space-y-2.5">
            {retentionSettings.map((s) => (
              <div key={String((s as Record<string, unknown>).key)} className="flex items-center justify-between rounded-lg bg-surface px-3.5 py-2.5">
                <span className="font-mono text-[12.5px] text-text">{String((s as Record<string, unknown>).key)}</span>
                <span className="font-mono text-[12px] text-text-2">
                  {typeof (s as Record<string, unknown>).value === "string"
                    ? String((s as Record<string, unknown>).value)
                    : JSON.stringify((s as Record<string, unknown>).value)}
                </span>
              </div>
            ))}
          </div>
        ) : (
          <div className="mt-3 text-[12.5px] text-text-2">暂无 retention 类设置项</div>
        )}
      </VoltCard>

      {/* 危险区 */}
      <VoltCard className="border-bear/20 p-[22px]">
        <div className="flex items-center gap-2 font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-bear">
          <Trash2 className="size-4" />
          危险区
        </div>
        <div className="mt-3 text-[12.5px] leading-relaxed text-text-2">
          以下操作不可恢复,请谨慎执行。
        </div>
        <div className="mt-4 space-y-2.5">
          <button
            disabled
            className="flex w-full items-center justify-between rounded-lg border border-bear/20 bg-bear/5 px-3.5 py-2.5 text-left opacity-50"
          >
            <span className="text-[12.5px] font-medium text-bear">清除全部历史数据</span>
            <span className="text-[11px] text-text-3">需后端支持</span>
          </button>
          <button
            disabled
            className="flex w-full items-center justify-between rounded-lg border border-bear/20 bg-bear/5 px-3.5 py-2.5 text-left opacity-50"
          >
            <span className="text-[12.5px] font-medium text-bear">导出全部数据</span>
            <span className="text-[11px] text-text-3">需后端支持</span>
          </button>
        </div>
      </VoltCard>
    </div>
  );
}

/* ---------------- 页面 ---------------- */

export default function SystemSettingsPage() {
  const [group, setGroup] = useState<GroupId>("appearance");

  return (
    <div className="mx-auto w-full max-w-[1340px] space-y-4 px-7 py-6">
      <FadeIn index={0}>
        <PageHeader eyebrow="SETTINGS" title="系统设置" subtitle="外观、系统参数与高级选项" />
      </FadeIn>

      <FadeIn index={1}>
        <div className="flex gap-5">
          {/* 分组 */}
          <div className="w-44 shrink-0 space-y-1">
            {GROUPS.map((g) => (
              <button
                key={g.id}
                onClick={() => setGroup(g.id)}
                className={cn(
                  "flex w-full items-center gap-2.5 rounded-lg px-3 py-2.5 text-[13.5px] font-medium transition-colors",
                  group === g.id
                    ? "bg-nav-sel text-on-nav-sel"
                    : "text-text-2 hover:bg-surface-hover hover:text-text"
                )}
              >
                <g.icon className="size-4" />
                {g.label}
              </button>
            ))}
          </div>

          {/* 内容 */}
          <div className="min-w-0 flex-1">
            {group === "appearance" && <AppearanceSection />}
            {group === "alerts" && <AlertRulesSection />}
            {group === "system" && <SystemSection />}
            {group === "advanced" && <AdvancedSection />}
          </div>
        </div>
      </FadeIn>
    </div>
  );
}
/* ---------------- 告警规则 ---------------- */

const CONDITION_TYPES = [
  { value: "price_above", label: "价格高于" },
  { value: "price_below", label: "价格低于" },
  { value: "drawdown_exceeds", label: "回撤超过" },
  { value: "risk_event", label: "风险事件" },
];

const SEVERITIES = [
  { value: "low", label: "低" },
  { value: "medium", label: "中" },
  { value: "high", label: "高" },
  { value: "critical", label: "紧急" },
];

function severityTone(s: string): string {
  if (s === "critical") return "var(--bear)";
  if (s === "high") return "var(--bear)";
  if (s === "medium") return "var(--warn)";
  return "var(--text-3)";
}

function AlertRulesSection() {
  const { data } = useAlertRules();
  const createRule = useCreateAlertRule();
  const deleteRule = useDeleteAlertRule();
  const evaluate = useEvaluateAlertRules();
  const [showNew, setShowNew] = useState(false);
  const [msg, setMsg] = useState("");

  // New rule form
  const [name, setName] = useState("");
  const [condType, setCondType] = useState("price_above");
  const [symbol, setSymbol] = useState("BTC/USDT");
  const [threshold, setThreshold] = useState("");
  const [severity, setSeverity] = useState("medium");

  const rules = (data?.rules ?? []) as Record<string, unknown>[];

  const handleCreate = () => {
    setMsg("");
    createRule.mutate(
      {
        name,
        enabled: true,
        condition_type: condType,
        symbol,
        threshold: parseFloat(threshold) || 0,
        severity,
        message: "",
      },
      {
        onSuccess: () => {
          setShowNew(false);
          setName("");
          setThreshold("");
          setMsg("规则已创建");
        },
        onError: (e) => setMsg(e instanceof Error ? e.message : "创建失败"),
      }
    );
  };

  return (
    <div className="space-y-4">
      {/* 操作栏 */}
      <div className="flex items-center gap-2.5">
        <VoltButton size="sm" icon={<Plus />} onClick={() => setShowNew(true)}>
          新建规则
        </VoltButton>
        <VoltButton
          size="sm"
          variant="secondary"
          icon={<Play />}
          disabled={evaluate.isPending}
          onClick={() => {
            setMsg("");
            evaluate.mutate(undefined, {
              onSuccess: (res) => {
                const r = res as Record<string, unknown>;
                setMsg(`评估完成: ${r.evaluated ?? 0} 条规则, ${r.triggered ?? 0} 条触发`);
              },
              onError: (e) => setMsg(e instanceof Error ? e.message : "评估失败"),
            });
          }}
        >
          {evaluate.isPending ? "评估中…" : "立即评估"}
        </VoltButton>
      </div>

      {msg && (
        <div className="rounded-lg bg-accent-soft px-3 py-2 text-[12px] font-medium text-accent-text">
          {msg}
        </div>
      )}

      {/* 新建规则表单 */}
      {showNew && (
        <VoltCard className="p-[22px]">
          <div className="flex items-center justify-between">
            <div className="font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-2">
              新建告警规则
            </div>
            <button onClick={() => setShowNew(false)} className="rounded-lg p-1.5 text-text-3 hover:bg-surface-hover hover:text-text">
              <X className="size-4" />
            </button>
          </div>
          <div className="mt-4 grid grid-cols-2 gap-3">
            <div>
              <div className="mb-1.5 font-mono text-[10px] uppercase tracking-[0.08em] text-text-3">规则名称</div>
              <input
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="如: BTC 突破 70000"
                className="w-full rounded-lg border border-border bg-surface px-3 py-2.5 text-[13px] text-text outline-none focus:border-accent-text/60"
              />
            </div>
            <div>
              <div className="mb-1.5 font-mono text-[10px] uppercase tracking-[0.08em] text-text-3">严重度</div>
              <select
                value={severity}
                onChange={(e) => setSeverity(e.target.value)}
                className="w-full rounded-lg border border-border bg-surface px-3 py-2.5 text-[13px] text-text outline-none focus:border-accent-text/60"
              >
                {SEVERITIES.map((s) => (
                  <option key={s.value} value={s.value}>{s.label}</option>
                ))}
              </select>
            </div>
            <div>
              <div className="mb-1.5 font-mono text-[10px] uppercase tracking-[0.08em] text-text-3">条件类型</div>
              <select
                value={condType}
                onChange={(e) => setCondType(e.target.value)}
                className="w-full rounded-lg border border-border bg-surface px-3 py-2.5 text-[13px] text-text outline-none focus:border-accent-text/60"
              >
                {CONDITION_TYPES.map((c) => (
                  <option key={c.value} value={c.value}>{c.label}</option>
                ))}
              </select>
            </div>
            <div>
              <div className="mb-1.5 font-mono text-[10px] uppercase tracking-[0.08em] text-text-3">标的</div>
              <input
                value={symbol}
                onChange={(e) => setSymbol(e.target.value)}
                className="w-full rounded-lg border border-border bg-surface px-3 py-2.5 font-mono text-[13px] text-text outline-none focus:border-accent-text/60"
              />
            </div>
            {(condType === "price_above" || condType === "price_below" || condType === "drawdown_exceeds") && (
              <div>
                <div className="mb-1.5 font-mono text-[10px] uppercase tracking-[0.08em] text-text-3">阈值</div>
                <input
                  value={threshold}
                  onChange={(e) => setThreshold(e.target.value)}
                  inputMode="decimal"
                  placeholder={condType === "drawdown_exceeds" ? "如: 15" : "如: 70000"}
                  className="tnum w-full rounded-lg border border-border bg-surface px-3 py-2.5 font-mono text-[13px] text-text outline-none focus:border-accent-text/60"
                />
              </div>
            )}
          </div>
          <div className="mt-4">
            <VoltButton onClick={handleCreate} disabled={!name || createRule.isPending} size="md">
              {createRule.isPending ? "创建中…" : "创建规则"}
            </VoltButton>
          </div>
        </VoltCard>
      )}

      {/* 规则列表 */}
      <VoltCard className="overflow-hidden">
        <div className="flex items-center justify-between border-b border-border px-5 py-3.5">
          <span className="font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-2">
            告警规则 · {rules.length}
          </span>
        </div>
        {rules.length === 0 ? (
          <EmptyState compact icon={<Bell />} title="暂无告警规则" description="创建规则后,系统会按条件自动检测并发送告警通知。" />
        ) : (
          <div className="divide-y divide-border/50">
            {rules.map((r) => {
              const enabled = r.enabled !== false;
              return (
                <div key={String(r.id)} className="flex items-center gap-3 px-5 py-3">
                  <span className={cn("size-1.5 rounded-full", enabled ? "bg-bull" : "bg-text-3")} />
                  <span className="font-semibold text-text">{String(r.name ?? "未命名")}</span>
                  <span className="rounded-md bg-surface px-2 py-0.5 font-mono text-[10px] text-text-3">
                    {CONDITION_TYPES.find((c) => c.value === r.condition_type)?.label ?? String(r.condition_type)}
                  </span>
                  {r.symbol != null && String(r.symbol) !== "" && (
                    <span className="font-mono text-[11px] text-text-3">{String(r.symbol)}</span>
                  )}
                  {r.threshold != null && Number(r.threshold) !== 0 && (
                    <span className="tnum font-mono text-[11px] text-text-2">{String(r.threshold)}</span>
                  )}
                  <span
                    className="rounded-md px-2 py-0.5 text-[11px] font-semibold"
                    style={{
                      color: severityTone(String(r.severity ?? "medium")),
                      background: `color-mix(in srgb, ${severityTone(String(r.severity ?? "medium"))} 12%, transparent)`,
                    }}
                  >
                    {SEVERITIES.find((s) => s.value === r.severity)?.label ?? String(r.severity)}
                  </span>
                  <div className="ml-auto flex items-center gap-2">
                    <button
                      onClick={() => deleteRule.mutate(String(r.id))}
                      disabled={deleteRule.isPending}
                      className="rounded-lg p-1.5 text-text-3 transition-colors hover:bg-bear/10 hover:text-bear"
                      title="删除"
                    >
                      <Trash2 className="size-3.5" />
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </VoltCard>
    </div>
  );
}
