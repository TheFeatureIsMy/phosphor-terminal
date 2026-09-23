import { useState } from "react";
import { Link } from "react-router-dom";
import { ArrowRight, RefreshCcw, ShieldAlert, X } from "lucide-react";
import { VoltSelect } from "@/components/shell/VoltSelect";
import { VoltButton } from "@/components/shell/VoltButton";
import StarBorder from "@/components/reactbits/StarBorder/StarBorder";
import { PageHeader } from "@/components/shell/PageHeader";
import { VoltCard } from "@/components/shell/VoltCard";
import { FadeIn } from "@/components/effects/FadeIn";
import { useDisableAuto, useLiveReadiness, useStartLiveSmall, useStartPaper } from "@/lib/hooks";
import type { ReadinessCheck } from "@/lib/types";
import { cn } from "@/lib/utils";

const GROUP_LABELS: Record<string, string> = {
  mode: "模式",
  strategy: "策略",
  capital: "资金",
  risk: "风控",
  system: "系统",
  execution: "执行",
};

/** 阻断项 code → 人性化指引(问题 + 怎么解决 + 去哪解决) */
const BLOCKING_GUIDE: Record<string, { title: string; guide: string; to?: string; actionLabel?: string }> = {
  strategy_unset: {
    title: "未选择实盘策略",
    guide: "在上方「运行选择 · 策略」中选择要运行的策略",
  },
  capital_unconfigured: {
    title: "未配置资金池",
    guide: "在上方「运行选择 · 资金池」中选择用于实盘的资金池",
  },
  validation_failed: {
    title: "策略规则验证未通过",
    guide: "策略的 DSL 规则存在错误,需要前往策略工作台检查并修复",
    to: "/strategy",
    actionLabel: "去工作台",
  },
  no_backtest: {
    title: "缺少回测记录",
    guide: "先完成一次回测,验证策略在历史行情中的表现",
    to: "/backtest",
    actionLabel: "去回测",
  },
  dryrun_insufficient: {
    title: "模拟运行时长不足",
    guide: "策略需连续模拟运行满 72 小时,确认稳定后才能申请实盘",
  },
  freqtrade_unavailable: {
    title: "交易引擎未连接",
    guide: "Freqtrade 服务未运行或不可达,请检查服务状态",
    to: "/services",
    actionLabel: "服务管理",
  },
  data_source_unavailable: {
    title: "数据源不可用",
    guide: "行情数据源连接失败,请检查数据源配置与后端状态",
    to: "/data-sources",
    actionLabel: "数据源",
  },
};

function parseBlocking(raw: Record<string, unknown>): { title: string; guide: string; to?: string; actionLabel?: string } {
  const code = String(raw.code ?? raw.key ?? "");
  const known = BLOCKING_GUIDE[code];
  if (known) return known;
  // 未知 code:至少用 message 作为标题,不再展示原始 JSON
  const msg = typeof raw.message === "string" ? raw.message : "";
  return { title: msg || code || "未知阻断项", guide: "" };
}

function checkTone(status: string): { dot: string; text: string } {
  const k = status.toLowerCase();
  if (k === "healthy" || k === "pass" || k === "ok") return { dot: "bg-bull", text: "text-bull" };
  if (k === "warning") return { dot: "bg-warn", text: "text-warn" };
  return { dot: "bg-bear", text: "text-bear" };
}

function CheckRow({ check }: { check: ReadinessCheck }) {
  const tone = checkTone(check.status);
  return (
    <div className="flex items-center gap-2.5 py-1.5">
      <span className={cn("size-1.5 rounded-full", tone.dot)} />
      <span className="w-32 text-[12.5px] text-text-2">{check.label}</span>
      <span className={cn("flex-1 truncate font-mono text-[12px] font-medium", tone.text)}>
        {check.value || check.status}
      </span>
    </div>
  );
}

export default function LiveReadinessPage() {
  const { data, refetch, isFetching, isLoading } = useLiveReadiness();
  const startPaper = useStartPaper();
  const startLiveSmall = useStartLiveSmall();
  const disableAuto = useDisableAuto();
  const checks = data?.checks ?? [];
  const groups = [...new Set(checks.map((c) => c.group))];
  const ready = data?.state === "READY";

  const [mode, setMode] = useState("");
  const [strategy, setStrategy] = useState("");
  const [pool, setPool] = useState("");
  const [exchange, setExchange] = useState("");
  const [confirmAction, setConfirmAction] = useState<string | null>(null);
  const [resultMsg, setResultMsg] = useState("");

  const selectedStrategyVersionId = strategy || data?.selected_strategy_id || "";
  const selectedPoolId = pool || data?.selected_capital_pool_id || "";
  const selectedExchange = exchange || data?.selected_exchange || "binance";

  const handleStartPaper = () => {
    if (!selectedStrategyVersionId) return;
    setResultMsg("");
    startPaper.mutate(
      {
        strategy_version_id: selectedStrategyVersionId,
        symbols: ["BTC/USDT"],
        stake_amount: 100,
        initial_wallet: 10000,
        max_open_trades: 5,
        exchange: selectedExchange,
      },
      {
        onSuccess: (res) => setResultMsg(res.message || "模拟交易已启动"),
        onError: (e) => setResultMsg(e instanceof Error ? e.message : "启动失败"),
      }
    );
  };

  const handleStartLiveSmall = () => {
    if (!selectedStrategyVersionId || !selectedPoolId) return;
    setResultMsg("");
    startLiveSmall.mutate(
      {
        strategy_version_id: selectedStrategyVersionId,
        capital_pool_id: selectedPoolId,
        exchange_name: selectedExchange,
        human_confirmed: true,
        confirmed_by: "web-user",
      },
      {
        onSuccess: (res) => {
          if (res.state === "approved_enqueued") setResultMsg("小仓实盘已批准,正在启动");
          else if (res.state === "waiting_confirmation") setResultMsg("等待人工确认");
          else if (res.state === "not_enabled") setResultMsg("小仓实盘执行未启用(LIVE_SMALL_ENABLED=false)");
          else setResultMsg(`被阻止: ${res.reason_codes.join(", ")}`);
        },
        onError: (e) => setResultMsg(e instanceof Error ? e.message : "启动失败"),
      }
    );
  };

  const handleDisableAuto = () => {
    setResultMsg("");
    disableAuto.mutate(
      { reason: "manual_disable" },
      {
        onSuccess: (res) => setResultMsg(`已停用自动交易,停止 ${res.stopped_dryruns} 个运行`),
        onError: (e) => setResultMsg(e instanceof Error ? e.message : "停用失败"),
      }
    );
  };

  // 上下文卡:取 system + execution 组的 checks 组成状态网格
  const contextChecks = checks.filter((c) => c.group === "system" || c.group === "execution");

  return (
    <div className="mx-auto w-full max-w-[1340px] space-y-4 px-7 py-6">
      <FadeIn index={0}>
        <PageHeader
          eyebrow="OVERVIEW"
          title="实盘准入"
          subtitle="一屏可判断 · 11 项门禁 + 5 级总状态"
          trailing={
            <div className="flex items-center gap-2">
              <span className={cn(
                "rounded-lg px-2.5 py-1 text-[11.5px] font-semibold",
                ready ? "bg-bull/12 text-bull" : "bg-bear/12 text-bear"
              )}>
                {ready ? "可实盘" : "不可实盘"}
              </span>
              <button
                onClick={() => refetch()}
                className="flex items-center gap-1.5 rounded-lg bg-accent-soft px-3 py-1.5 text-[12px] font-semibold text-accent-text transition-colors hover:bg-accent-soft/80"
              >
                <RefreshCcw className={cn("size-3.5", isFetching && "animate-spin")} />
                重新检查
              </button>
            </div>
          }
        />
      </FadeIn>

      {/* 运行选择 */}
      <FadeIn index={1}>
        <VoltCard className="p-[22px]">
          <div className="font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-2">
            运行选择
          </div>
          <div className="mt-4 grid grid-cols-4 gap-3">
            <VoltSelect
              label="运行模式"
              value={mode || data?.selected_mode || ""}
              onChange={setMode}
              options={[
                { value: "paper", label: "模拟" },
                { value: "live_small", label: "小仓实盘" },
                { value: "live_full", label: "全仓实盘" },
              ]}
            />
            <VoltSelect
              label="策略"
              value={strategy || data?.selected_strategy_id || ""}
              onChange={setStrategy}
              options={(data?.available_strategies ?? []).map((s, i) => ({
                value: String((s as Record<string, unknown>).id ?? i),
                label: String((s as Record<string, unknown>).name ?? `策略 ${i + 1}`),
              }))}
            />
            <VoltSelect
              label="资金池"
              value={pool || data?.selected_capital_pool_id || ""}
              onChange={setPool}
              options={(data?.available_capital_pools ?? []).map((s, i) => ({
                value: String((s as Record<string, unknown>).id ?? i),
                label: String((s as Record<string, unknown>).name ?? `资金池 ${i + 1}`),
              }))}
            />
            <VoltSelect
              label="交易所"
              value={exchange || data?.selected_exchange || ""}
              onChange={setExchange}
              options={(data?.available_exchanges ?? []).map((s, i) => ({
                value: String((s as Record<string, unknown>).id ?? (s as Record<string, unknown>).name ?? i),
                label: String((s as Record<string, unknown>).name ?? `交易所 ${i + 1}`),
              }))}
            />
          </div>
        </VoltCard>
      </FadeIn>

      {/* 11 项门禁 */}
      <FadeIn index={2}>
        <VoltCard spotlight className="p-[22px]">
          <div className="font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-2">
            {checks.length} 项门禁
          </div>
          <div className="mt-4 grid grid-cols-2 gap-x-10">
            {groups.map((g) => (
              <div key={g}>
                <div className="mt-2 font-mono text-[10px] uppercase tracking-[0.1em] text-text-3">
                  {GROUP_LABELS[g] ?? g}
                </div>
                <div className="divide-y divide-border/40">
                  {checks.filter((c) => c.group === g).map((c) => (
                    <CheckRow key={c.key} check={c} />
                  ))}
                </div>
              </div>
            ))}
            {checks.length === 0 && isLoading && (
              <div className="col-span-2 space-y-2.5 py-2">
                {[0, 1, 2, 3, 4, 5].map((i) => (
                  <div key={i} className="h-6 animate-pulse rounded-lg bg-surface" style={{ opacity: 1 - i * 0.12 }} />
                ))}
              </div>
            )}
            {checks.length === 0 && !isLoading && (
              <div className="col-span-2 py-8 text-center text-[13px] text-text-2">
                暂无门禁数据
              </div>
            )}
          </div>
        </VoltCard>
      </FadeIn>

      {/* 上下文 */}
      {contextChecks.length > 0 && (
        <FadeIn index={3}>
          <VoltCard className="p-[22px]">
            <div className="font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-2">
              上下文
            </div>
            <div className="mt-4 grid grid-cols-3 gap-x-8 gap-y-2">
              {contextChecks.map((c) => (
                <CheckRow key={c.key} check={c} />
              ))}
            </div>
          </VoltCard>
        </FadeIn>
      )}

      {/* 启动授权 */}
      <FadeIn index={4}>
        <VoltCard className="p-[22px]">
          <div className="font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-2">
            启动授权
          </div>
          {(data?.blocking_reasons ?? []).length > 0 && (
            <div className="mt-4 rounded-[12px] border border-bear/20 bg-bear/10">
              <div className="border-b border-bear/15 px-4 py-2.5 text-[12px] font-semibold text-bear">
                完成以下 {data!.blocking_reasons.length} 项后,才能解锁实盘启动
              </div>
              <div className="divide-y divide-bear/10">
                {data!.blocking_reasons.map((raw, i) => {
                  const b = parseBlocking(raw as Record<string, unknown>);
                  return (
                    <div key={i} className="flex items-center gap-3 px-4 py-3">
                      <span className="mt-0.5 size-1.5 shrink-0 rounded-full bg-bear" />
                      <div className="min-w-0 flex-1">
                        <div className="text-[13px] font-semibold text-text">{b.title}</div>
                        {b.guide && <div className="mt-0.5 text-[12px] text-text-2">{b.guide}</div>}
                      </div>
                      {b.to && (
                        <Link
                          to={b.to}
                          className="flex shrink-0 items-center gap-1 rounded-lg border border-bear/25 bg-bear/10 px-2.5 py-1.5 text-[11.5px] font-semibold text-bear transition-colors hover:bg-bear/20"
                        >
                          {b.actionLabel}
                          <ArrowRight className="size-3" />
                        </Link>
                      )}
                    </div>
                  );
                })}
              </div>
            </div>
          )}
          <div className="mt-4 grid grid-cols-3 gap-3">
            {data?.can_start_paper ? (
              <StarBorder as="div" color="var(--accent)" speed="4s" thickness={1} className="rounded-lg">
                <button
                  onClick={handleStartPaper}
                  disabled={startPaper.isPending}
                  className="flex w-full items-center justify-center gap-2 rounded-lg bg-accent-soft py-3 text-[13px] font-semibold text-accent-text transition-colors hover:bg-accent-soft/80 disabled:opacity-50"
                >
                  ⚡ {startPaper.isPending ? "启动中…" : "启动模拟"}
                </button>
              </StarBorder>
            ) : (
              <button disabled className="flex cursor-not-allowed items-center justify-center gap-2 rounded-lg border border-border bg-surface py-3 text-[13px] font-semibold text-text-3">
                ⚡ 启动模拟
              </button>
            )}
            {data?.can_start_live_small ? (
              <StarBorder as="div" color="var(--accent)" speed="4s" thickness={1} className="rounded-lg">
                <button
                  onClick={() => setConfirmAction("live_small")}
                  disabled={startLiveSmall.isPending}
                  className="flex w-full items-center justify-center gap-2 rounded-lg bg-accent-soft py-3 text-[13px] font-semibold text-accent-text transition-colors hover:bg-accent-soft/80 disabled:opacity-50"
                >
                  ⚡ {startLiveSmall.isPending ? "启动中…" : "启动小仓实盘"}
                </button>
              </StarBorder>
            ) : (
              <button disabled className="flex cursor-not-allowed items-center justify-center gap-2 rounded-lg border border-border bg-surface py-3 text-[13px] font-semibold text-text-3">
                ⚡ 启动小仓实盘
              </button>
            )}
            <button disabled className="flex cursor-not-allowed items-center justify-center gap-2 rounded-lg border border-border bg-surface py-3 text-[13px] font-semibold text-text-3">
              ⚡ 启动全仓实盘
            </button>
          </div>
          {resultMsg && (
            <div className="mt-3 rounded-lg bg-accent-soft px-3 py-2 text-[12px] font-medium text-accent-text">
              {resultMsg}
            </div>
          )}
          <div className="mt-3 text-right">
            <button
              onClick={() => setConfirmAction("disable_auto")}
              disabled={disableAuto.isPending}
              className="text-[12px] font-medium text-bear hover:underline disabled:opacity-50"
            >
              {disableAuto.isPending ? "停用中…" : "停用自动交易"}
            </button>
          </div>
        </VoltCard>
      </FadeIn>

      {/* 确认弹窗 */}
      {confirmAction === "live_small" && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/55 p-6" onClick={() => setConfirmAction(null)}>
          <div className="w-full max-w-[420px] rounded-[16px] border border-border bg-card p-6 shadow-modal" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-center gap-3">
              <span className="flex size-10 items-center justify-center rounded-[10px] bg-warn/12 text-warn">
                <ShieldAlert className="size-5" />
              </span>
              <div>
                <div className="text-[16px] font-bold text-text">确认启动小仓实盘</div>
                <div className="mt-0.5 text-[12px] text-text-2">将使用真实资金进行交易</div>
              </div>
            </div>
            <div className="mt-4 rounded-lg bg-surface p-3.5 text-[12.5px] leading-relaxed text-text-2">
              策略版本: <span className="font-mono font-semibold text-text">{selectedStrategyVersionId.slice(0, 8)}…</span>
              <br />资金池: <span className="font-mono font-semibold text-text">{selectedPoolId.slice(0, 8)}…</span>
              <br />交易所: <span className="font-mono font-semibold text-text">{selectedExchange}</span>
            </div>
            <div className="mt-3 rounded-lg border border-warn/20 bg-warn/10 px-3 py-2 text-[12px] text-warn">
              小仓实盘会使用真实资金。启动前请确认已完成回测验证和模拟运行。
            </div>
            <div className="mt-5 flex gap-2.5">
              <VoltButton variant="secondary" onClick={() => setConfirmAction(null)} className="flex-1">取消</VoltButton>
              <VoltButton
                onClick={() => { setConfirmAction(null); handleStartLiveSmall(); }}
                disabled={startLiveSmall.isPending}
                className="flex-1"
              >
                {startLiveSmall.isPending ? "启动中…" : "确认启动"}
              </VoltButton>
            </div>
          </div>
        </div>
      )}

      {confirmAction === "disable_auto" && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/55 p-6" onClick={() => setConfirmAction(null)}>
          <div className="w-full max-w-[380px] rounded-[16px] border border-border bg-card p-6 shadow-modal" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-center gap-3">
              <span className="flex size-10 items-center justify-center rounded-[10px] bg-bear/12 text-bear">
                <X className="size-5" />
              </span>
              <div>
                <div className="text-[16px] font-bold text-text">停用自动交易</div>
                <div className="mt-0.5 text-[12px] text-text-2">将停止所有运行中的模拟并阻止新开仓</div>
              </div>
            </div>
            <div className="mt-5 flex gap-2.5">
              <VoltButton variant="secondary" onClick={() => setConfirmAction(null)} className="flex-1">取消</VoltButton>
              <VoltButton
                variant="danger"
                onClick={() => { setConfirmAction(null); handleDisableAuto(); }}
                disabled={disableAuto.isPending}
                className="flex-1"
              >
                {disableAuto.isPending ? "停用中…" : "确认停用"}
              </VoltButton>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
