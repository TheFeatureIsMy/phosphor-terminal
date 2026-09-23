import { useEffect, useState } from "react";
import { Check, Shield, ShieldAlert, Zap } from "lucide-react";
import { EmptyState } from "@/components/shell/EmptyState";
import { PageHeader } from "@/components/shell/PageHeader";
import { VoltCard } from "@/components/shell/VoltCard";
import { FadeIn } from "@/components/effects/FadeIn";
import { AnimatedNumber } from "@/components/effects/AnimatedNumber";
import { useDashboard, useRiskOverview, useRiskRules, useUpdateRiskRules } from "@/lib/hooks";
import { cn } from "@/lib/utils";

const fmt2 = (v: number) =>
  v.toLocaleString("zh-CN", { minimumFractionDigits: 2, maximumFractionDigits: 2 });

function guardTone(status: string): string {
  const k = status.toLowerCase();
  if (k === "healthy" || k === "ok" || k === "normal") return "var(--bull)";
  if (k === "warning") return "var(--warn)";
  return "var(--bear)";
}

/* ---------------- 风控参数编辑 ---------------- */

interface RiskFormState {
  daily_loss_limit: string;
  weekly_loss_limit: string;
  consecutive_losses_limit: string;
  max_drawdown: string;
  correlation_threshold: string;
  kill_switch_active: boolean;
}

const RISK_FIELDS: { key: keyof Omit<RiskFormState, "kill_switch_active">; label: string; unit: string; hint: string }[] = [
  { key: "daily_loss_limit", label: "日亏损限制", unit: "", hint: "单日累计亏损达到该值即锁定开仓" },
  { key: "weekly_loss_limit", label: "周亏损限制", unit: "", hint: "单周累计亏损达到该值即锁定开仓" },
  { key: "consecutive_losses_limit", label: "连续亏损限制", unit: "次", hint: "连续亏损次数达到该值触发保护" },
  { key: "max_drawdown", label: "最大回撤限制", unit: "", hint: "权益回撤超过该值触发熔断" },
  { key: "correlation_threshold", label: "相关性阈值", unit: "", hint: "持仓相关性超过该值禁止同向加仓" },
];

function RiskParamsSection() {
  const { data: rules } = useRiskRules();
  const update = useUpdateRiskRules();
  const [form, setForm] = useState<RiskFormState | null>(null);
  const [saved, setSaved] = useState(false);

  useEffect(() => {
    if (rules && !form) {
      setForm({
        daily_loss_limit: String(rules.daily_loss_limit),
        weekly_loss_limit: String(rules.weekly_loss_limit),
        consecutive_losses_limit: String(rules.consecutive_losses_limit),
        max_drawdown: String(rules.max_drawdown),
        correlation_threshold: String(rules.correlation_threshold),
        kill_switch_active: rules.kill_switch.active,
      });
    }
  }, [rules, form]);

  if (!rules || !form) {
    return (
      <VoltCard className="space-y-3 p-[22px]">
        {[0, 1, 2].map((i) => (
          <div key={i} className="h-10 animate-pulse rounded-lg bg-surface" style={{ opacity: 1 - i * 0.15 }} />
        ))}
      </VoltCard>
    );
  }

  const dirty =
    form.daily_loss_limit !== String(rules.daily_loss_limit) ||
    form.weekly_loss_limit !== String(rules.weekly_loss_limit) ||
    form.consecutive_losses_limit !== String(rules.consecutive_losses_limit) ||
    form.max_drawdown !== String(rules.max_drawdown) ||
    form.correlation_threshold !== String(rules.correlation_threshold) ||
    form.kill_switch_active !== rules.kill_switch.active;

  const save = () => {
    setSaved(false);
    update.mutate(
      {
        daily_loss_limit: parseFloat(form.daily_loss_limit) || 0,
        weekly_loss_limit: parseFloat(form.weekly_loss_limit) || 0,
        consecutive_losses_limit: parseInt(form.consecutive_losses_limit, 10) || 0,
        max_drawdown: parseFloat(form.max_drawdown) || 0,
        correlation_threshold: parseFloat(form.correlation_threshold) || 0,
        kill_switch_active: form.kill_switch_active,
      },
      { onSuccess: () => { setSaved(true); window.setTimeout(() => setSaved(false), 2000); } }
    );
  };

  return (
    <VoltCard className="p-[22px]">
      <div className="flex items-center justify-between">
        <div className="font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-2">
          风控门禁阈值(实时生效)
        </div>
        <button
          onClick={save}
          disabled={!dirty || update.isPending}
          className={cn(
            "rounded-lg px-4 py-2 text-[12.5px] font-semibold transition-colors",
            saved
              ? "bg-bull/15 text-bull"
              : dirty
                ? "bg-accent text-on-accent hover:bg-accent-light"
                : "cursor-not-allowed bg-surface text-text-3"
          )}
        >
          {update.isPending ? "保存中…" : saved ? "✓ 已保存" : "保存修改"}
        </button>
      </div>
      {update.isError && (
        <div className="mt-3 rounded-lg bg-bear/10 px-3 py-2 text-[12px] text-bear">
          保存失败,请检查后端连接后重试
        </div>
      )}
      <div className="mt-5 space-y-4">
        {RISK_FIELDS.map((f) => (
          <div key={f.key} className="flex items-center gap-4">
            <div className="w-36">
              <div className="text-[13px] font-medium text-text">{f.label}</div>
              <div className="mt-0.5 text-[11px] text-text-3">{f.hint}</div>
            </div>
            <div className="ml-auto flex items-center gap-2">
              <input
                value={form[f.key]}
                onChange={(e) => setForm({ ...form, [f.key]: e.target.value })}
                className="tnum w-28 rounded-lg border border-border bg-surface px-3 py-2 text-right font-mono text-[13px] font-semibold text-text outline-none focus:border-accent-text/60"
              />
              {f.unit && <span className="text-[12px] text-text-3">{f.unit}</span>}
            </div>
          </div>
        ))}
        <div className="flex items-center gap-4 border-t border-border/40 pt-4">
          <div className="w-36">
            <div className="text-[13px] font-medium text-text">Kill Switch</div>
            <div className="mt-0.5 text-[11px] text-text-3">触发后停止所有新开仓</div>
          </div>
          <div className="ml-auto">
            <button
              onClick={() => setForm({ ...form, kill_switch_active: !form.kill_switch_active })}
              className={cn(
                "flex h-6 w-11 items-center rounded-full p-0.5 transition-colors",
                form.kill_switch_active ? "justify-end bg-accent" : "justify-start bg-surface"
              )}
            >
              <span className="size-5 rounded-full bg-white shadow transition-none" />
            </button>
          </div>
        </div>
      </div>
    </VoltCard>
  );
}

export default function RiskCenterPage() {
  const { data } = useRiskOverview();
  const { data: dash } = useDashboard();
  const normal = data?.state?.toLowerCase() === "normal";

  // 风险敞口 = 守卫中使用率最高者
  const exposure = Math.max(
    0,
    ...(data?.guards ?? []).map((g) =>
      g.limit_value > 0 ? g.current_value / g.limit_value : 0
    )
  ) * 100;
  const exposureTone =
    exposure >= 85 ? "var(--bear)" : exposure >= 50 ? "var(--warn)" : "var(--bull)";

  return (
    <div className="mx-auto w-full max-w-[1340px] space-y-4 px-7 py-6">
      <FadeIn index={0}>
        <PageHeader
          eyebrow="RISK CENTER · 风控中心"
          title="所有交易意图的最后一道门"
          subtitle="水位监控、守卫网格、拦截事件与门禁规则,构成 RiskEngine 强制门禁体系。"
          trailing={
            <span className={cn(
              "flex items-center gap-1.5 rounded-lg px-3 py-1.5 text-[12px] font-semibold",
              normal ? "bg-bull/12 text-bull" : "bg-bear/12 text-bear"
            )}>
              <span className={cn("size-1.5 rounded-full", normal ? "bg-bull" : "bg-bear")} />
              {normal ? "正常" : data?.state ?? "—"}
            </span>
          }
        />
      </FadeIn>

      {/* 风险水位 + 风险指标 */}
      <FadeIn index={1}>
        <div className="grid grid-cols-2 gap-3.5">
          {/* 全局风险水位 */}
          <VoltCard className="p-[22px]">
            <span className="flex items-center gap-1.5 rounded-lg bg-surface px-2.5 py-1 font-mono text-[10px] text-text-2">
              <span className="size-1.5 rounded-full" style={{ background: exposureTone }} />
              全局风险水位 · GLOBAL RISK
            </span>
            <div className="mt-4 flex items-baseline gap-1.5">
              <AnimatedNumber
                value={exposure}
                decimals={0}
                separator={false}
                className="font-display text-[48px] font-black leading-none text-text"
              />
              <span className="font-display text-[20px] font-semibold text-text-3">%</span>
            </div>
            {/* 水位条 + 刻度 */}
            <div className="mt-4">
              <div className="h-2.5 overflow-hidden rounded-full bg-surface">
                <div
                  className="h-full rounded-full transition-[width] duration-700"
                  style={{ width: `${Math.min(exposure, 100)}%`, background: exposureTone }}
                />
              </div>
              <div className="mt-1.5 flex font-mono text-[10px] text-text-3">
                <span style={{ width: "25%" }}>0 安全</span>
                <span style={{ width: "25%" }}>50 关注</span>
                <span className="text-warn" style={{ width: "35%" }}>警戒</span>
                <span className="text-right">85 触发</span>
              </div>
            </div>
          </VoltCard>

          {/* 风险指标 */}
          <VoltCard className="p-[22px]">
            <div className="flex items-center gap-2 font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-2">
              <Shield className="size-4 text-accent-text" />
              风险指标
            </div>
            <div className="mt-4 grid grid-cols-2 gap-x-6 gap-y-4">
              {[
                { k: "组合回撤", v: `-${fmt2(Math.abs(dash?.account.max_drawdown_pct ?? 0))}%`, c: "var(--bear)" },
                { k: "保证金率", v: "—", c: "var(--text)" },
                { k: "距熔断", v: `${fmt2(dash?.risk.daily_loss_remaining_pct ?? 100)}%`, c: "var(--warn)" },
                { k: "今日拦截", v: `${data?.active_locks.length ?? 0}`, c: "var(--text)" },
                { k: "守卫告警", v: `${(data?.guards ?? []).filter((g) => g.status !== "healthy" && g.status !== "normal").length}`, c: "var(--warn)" },
                { k: "系统状态", v: normal ? "正常" : "异常", c: normal ? "var(--bull)" : "var(--bear)" },
              ].map((it) => (
                <div key={it.k}>
                  <div className="font-mono text-[10px] uppercase tracking-[0.08em] text-text-3">{it.k}</div>
                  <div className="tnum mt-0.5 font-display text-[20px] font-bold" style={{ color: it.c }}>
                    {it.v}
                  </div>
                </div>
              ))}
            </div>
          </VoltCard>
        </div>
      </FadeIn>

      {/* 风控守卫网格 */}
      <FadeIn index={2}>
        <VoltCard spotlight className="p-[22px]">
          <div className="flex items-center gap-2 font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-2">
            <Shield className="size-4 text-accent-text" />
            风控守卫 · {data?.guards.length ?? 0} 维度
          </div>
          <div className="mt-4 grid grid-cols-3 gap-3">
            {(data?.guards ?? []).map((g) => {
              const used = g.limit_value > 0 ? Math.min(g.current_value / g.limit_value, 1) : 0;
              const tone = guardTone(g.status);
              return (
                <div key={g.key} className="rounded-lg border border-border bg-surface p-4">
                  <div className="flex items-center justify-between">
                    <span className="text-[13px] font-medium text-text">{g.label}</span>
                    <span
                      className="rounded-md px-2 py-0.5 text-[11px] font-semibold"
                      style={{ color: tone, background: `color-mix(in srgb, ${tone} 12%, transparent)` }}
                    >
                      {g.status}
                    </span>
                  </div>
                  <div className="tnum mt-2 font-mono text-[13px] text-text-2">
                    {g.current_value} / {g.limit_value}
                  </div>
                  <div className="mt-2 h-1.5 overflow-hidden rounded-full bg-bg">
                    <div
                      className="h-full rounded-full transition-[width] duration-500"
                      style={{ width: `${used * 100}%`, background: tone }}
                    />
                  </div>
                </div>
              );
            })}
            {(data?.guards ?? []).length === 0 && (
              <div className="col-span-3"><EmptyState compact icon={<Shield />} title="暂无守卫数据" description="风控引擎加载守卫配置后,各维度水位会显示在这里。" /></div>
            )}
          </div>
        </VoltCard>
      </FadeIn>

      {/* 拦截事件流 + 门禁规则 */}
      <FadeIn index={3}>
        <div className="grid grid-cols-2 gap-3.5">
          <VoltCard className="p-[22px]">
            <div className="flex items-center gap-2 font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-2">
              <Zap className="size-4 text-accent-text" />
              风控拦截事件流 · {data?.active_locks.length ?? 0}
            </div>
            {(data?.active_locks ?? []).length === 0 ? (
              <EmptyState compact icon={<Shield />} title="当前无拦截事件" description="风控引擎正常运行,暂无拦截。" />
            ) : (
              <div className="mt-3 space-y-2">
                {data!.active_locks.map((l, i) => {
                  const name = (l as Record<string, unknown>).strategy ?? (l as Record<string, unknown>).rule ?? (l as Record<string, unknown>).type ?? `拦截 #${i + 1}`;
                  const reason = (l as Record<string, unknown>).reason ?? (l as Record<string, unknown>).message ?? "触发风控限制";
                  return (
                    <div key={i} className="rounded-lg border border-bear/20 bg-bear/10 px-3 py-2">
                      <div className="text-[12px] font-semibold text-bear">{String(name)}</div>
                      <div className="mt-0.5 text-[11px] text-bear/70">{String(reason)}</div>
                    </div>
                  );
                })}
              </div>
            )}
          </VoltCard>

          <VoltCard className="p-[22px]">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2 font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-2">
                <ShieldAlert className="size-4 text-accent-text" />
                门禁规则
              </div>
              <span className="rounded-md bg-surface px-2 py-0.5 text-[10.5px] font-semibold text-text-3">只读</span>
            </div>
            <div className="mt-3 divide-y divide-border/40">
              {(data?.guards ?? []).map((g) => (
                <div key={g.key} className="flex items-center justify-between py-2.5">
                  <span className="text-[12.5px] text-text-2">{g.label}</span>
                  <span className="tnum font-mono text-[12px] font-semibold text-text">
                    限 {g.limit_value}
                  </span>
                </div>
              ))}
              {(data?.guards ?? []).length === 0 && (
                <div className="py-8 text-[13px] text-text-2">暂无规则</div>
              )}
            </div>
          </VoltCard>
        </div>
      </FadeIn>

      {/* 风控参数配置 */}
      <FadeIn index={4}>
        <RiskParamsSection />
      </FadeIn>
    </div>
  );
}
