import { useEffect, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import {
  AlertTriangle,
  ArrowLeft,
  CheckCircle2,
  Cpu,
  GitBranch,
  History,
  PlayCircle,
  Plus,
  Rocket,
  Shield,
  ShieldCheck,
  XCircle,
} from "lucide-react";
import { EmptyState } from "@/components/shell/EmptyState";
import { Skeleton } from "@/components/shell/Skeleton";
import { VoltButton } from "@/components/shell/VoltButton";
import { VoltCard } from "@/components/shell/VoltCard";
import { api } from "@/lib/api";
import { useCreateVersion, useStrategyWorkspace, useValidateDSL } from "@/lib/hooks";
import { cn } from "@/lib/utils";
import { statusTone } from "@/lib/statusTone";

import { CanvasEditor } from "@/canvas/CanvasEditor";
import { PageHeader } from "@/components/shell/PageHeader";
import { StrategyCardGrid, type WorkspaceTab } from "./StrategyCardGrid";
import { VersionTimeline, type VersionItem } from "./VersionTimeline";
import { PublishFlow } from "./PublishFlow";

interface StrategyBrief {
  id: string;
  name: string;
  strategy_type: string;
  status: string;
}

/** 新建策略附带的初始 DSL 模板(RSI 超卖反弹):让画布创建即有可编辑骨架,校验/回测可用 */
const STARTER_DSL = {
  schema_version: "2.5",
  timeframe: "1h",
  symbols: ["BTC/USDT"],
  entry: {
    logic: "AND",
    rules: [
      { type: "indicator_threshold", indicator: "rsi", params: { period: 14 }, operator: "<", value: 30 },
    ],
  },
  exit: {
    logic: "OR",
    rules: [
      { type: "indicator_threshold", indicator: "rsi", params: { period: 14 }, operator: ">", value: 70 },
    ],
  },
  filters: [],
  position_sizing: { type: "fixed_pct", position_pct: 0.02 },
  risk: { stoploss: -0.05, max_open_trades: 3 },
  metadata: { name: "RSI 超卖反弹模板", description: "RSI < 30 超卖买入,RSI > 70 超买卖出,可在画布继续编辑" },
};

type TabId = WorkspaceTab;

const TABS: { id: TabId; label: string; icon: typeof Cpu }[] = [
  { id: "canvas", label: "画布", icon: Cpu },
  { id: "validation", label: "校验", icon: ShieldCheck },
  { id: "backtest", label: "回测", icon: History },
  { id: "dryrun", label: "Dry-run", icon: PlayCircle },
  { id: "versions", label: "版本", icon: GitBranch },
  { id: "publish", label: "发布", icon: Rocket },
];

export default function StrategyWorkspacePage() {
  const { data: strategies } = useQuery({
    queryKey: ["strategies", "list"],
    queryFn: () => api.get<StrategyBrief[]>("/api/v2/strategies"),
  });
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [tab, setTab] = useState<TabId>("canvas");
  const [view, setView] = useState<"grid" | "detail">("grid");
  // grid 视图不预选策略;进入详情才确定 activeId
  const activeId = view === "detail" ? (selectedId ?? strategies?.[0]?.id ?? null) : null;

  const { data: workspace, isLoading } = useStrategyWorkspace(activeId);
  const validate = useValidateDSL();
  const createVersion = useCreateVersion(activeId);
  const [saveMsg, setSaveMsg] = useState("");

  const qc = useQueryClient();
  const [showNew, setShowNew] = useState(false);
  const [newName, setNewName] = useState("");
  const createStrategy = useMutation({
    mutationFn: async (name: string) => {
      const created = await api.post<{ id: string }>("/api/v2/strategies", { name, strategy_type: "rule_dsl", source_type: "manual" });
      // 创建后自动带上初始 DSL 模板版本,画布不再是空的
      await api.post(`/api/v2/strategies/${created.id}/versions`, { rule_dsl: STARTER_DSL, created_by: "web" });
      return created;
    },
    onSuccess: (created) => {
      qc.invalidateQueries({ queryKey: ["strategies"] });
      setShowNew(false);
      setNewName("");
      const id = (created as { id?: string } | undefined)?.id;
      if (id) setSelectedId(id);
    },
  });

  const active = strategies?.find((s) => s.id === activeId);
  const ws = workspace as Record<string, unknown> | undefined;
  const versions = (ws?.versions ?? []) as Record<string, unknown>[];
  const latest = versions[0];
  const latestVersionId = String(ws?.latest_version_id ?? latest?.id ?? "");



  // Auto-validate on version load
  useEffect(() => {
    if (latest?.rule_dsl && tab === "validation" && !validate.data && !validate.isPending) {
      validate.mutate(latest.rule_dsl as Record<string, unknown>);
    }
  }, [latest, tab, validate]);

  const recentBacktests = (ws?.recent_backtests ?? []) as Record<string, unknown>[];
  const recentDryruns = (ws?.recent_dryruns ?? []) as Record<string, unknown>[];
  const readiness = ws?.readiness as Record<string, unknown> | undefined;

  const openStrategy = (id: string, targetTab: TabId) => {
    setSelectedId(id);
    setTab(targetTab);
    setView("detail");
  };

  return (
    <div className="flex h-full flex-col">
      {view === "grid" ? (
        /* 卡片网格视图(整页) */
        <div className="min-h-0 flex-1 overflow-y-auto px-7 py-6">
          <PageHeader
            eyebrow="STRATEGY WORKBENCH"
            title="策略工作台"
            subtitle="每个策略一张卡 · 点卡片进入画布 / 校验 / 回测 / 版本 / 发布"
            trailing={
              <VoltButton size="md" icon={<Plus />} onClick={() => setShowNew(true)}>新建策略</VoltButton>
            }
          />
          {(strategies ?? []).length === 0 ? (
            <div className="mt-4">
              <EmptyState icon={<Cpu />} title="暂无策略" description="点击右上「新建策略」开始,会自动带一个可编辑的 RSI 模板。" />
            </div>
          ) : (
            <div className="mt-4">
              <StrategyCardGrid strategies={strategies ?? []} onOpen={openStrategy} />
            </div>
          )}
        </div>
      ) : (
      <>
      {/* 顶部 HUD */}
      <div className="flex items-center gap-3 border-b border-border px-7 py-3">
        <button onClick={() => setView("grid")} className="flex items-center gap-1 rounded-lg px-2 py-1 text-[12.5px] font-semibold text-text-2 transition-colors hover:bg-surface-hover hover:text-text">
          <ArrowLeft className="size-3.5" />返回
        </button>
        <div className="flex-1" />
        {active && (
          <>
            <span className="font-display text-[15px] font-bold text-text">{active.name}</span>
            <span className="rounded-md bg-accent-soft px-2 py-0.5 font-mono text-[11px] font-semibold text-accent-text">
              v{String(latest?.version_no ?? "—")}
            </span>
            <span
              className="rounded-md px-2 py-0.5 text-[11px] font-semibold"
              style={{
                color: statusTone(active.status),
                background: `color-mix(in srgb, ${statusTone(active.status)} 12%, transparent)`,
              }}
            >
              {active.status}
            </span>
          </>
        )}
      </div>

      {/* Tab 栏 */}
      <div className="flex items-center gap-1.5 border-b border-border px-7 py-2">
        {TABS.map((t) => (
          <button
            key={t.id}
            onClick={() => setTab(t.id)}
            className={cn(
              "flex items-center gap-1.5 rounded-lg px-3 py-1.5 text-[12.5px] font-semibold transition-colors",
              tab === t.id
                ? "bg-accent-soft text-accent-text"
                : "text-text-2 hover:bg-surface-hover hover:text-text"
            )}
          >
            <t.icon className="size-3.5" />
            {t.label}
          </button>
        ))}
      </div>

      <div className="flex min-h-0 flex-1">

        {/* 内容区 */}
        <div className="min-w-0 flex-1 overflow-y-auto">
          {isLoading ? (
            <div className="space-y-3 p-6">
              {[0, 1, 2].map((i) => (
                <Skeleton key={i} className="h-20" style={{ opacity: 1 - i * 0.2 } as React.CSSProperties} />
              ))}
            </div>
          ) : !activeId ? (
            <EmptyState icon={<Cpu />} title="选择策略" description="从左侧选择一个策略查看工作区。" />
          ) : (
            <>
              {/* 画布 Tab：可编辑 + AI 生成 */}
              {tab === "canvas" && (
                <div className="h-full">
                  {saveMsg && (
                    <div className="absolute left-1/2 top-16 z-20 -translate-x-1/2 rounded-lg bg-accent-soft px-3 py-1.5 text-[12px] font-medium text-accent-text shadow-modal">
                      {saveMsg}
                    </div>
                  )}
                  <CanvasEditor
                    initialDsl={(latest?.rule_dsl as Record<string, unknown>) ?? null}
                    onSave={(dsl) => {
                      setSaveMsg("");
                      createVersion.mutate(
                        { rule_dsl: dsl, created_by: "web-canvas" },
                        {
                          onSuccess: () => setSaveMsg("已保存为新版本"),
                          onError: (e) => setSaveMsg(e instanceof Error ? e.message : "保存失败"),
                        }
                      );
                    }}
                  />
                </div>
              )}

              {/* 校验 Tab */}
              {tab === "validation" && (
                <div className="space-y-4 p-6">
                  <ValidationPanel
                    validate={validate}
                    latest={latest}
                    latestVersionId={latestVersionId}
                  />
                </div>
              )}

              {/* 回测 Tab */}
              {tab === "backtest" && (
                <div className="space-y-4 p-6">
                  <BacktestPanel
                    backtests={recentBacktests}
                    latestVersionId={latestVersionId}
                  />
                </div>
              )}

              {/* Dry-run Tab */}
              {tab === "dryrun" && (
                <div className="space-y-4 p-6">
                  <DryrunPanel
                    dryruns={recentDryruns}
                    latestVersionId={latestVersionId}
                    readiness={readiness}
                  />
                </div>
              )}

              {/* 版本 Tab */}
              {tab === "versions" && (
                <div className="p-6">
                  <VoltCard className="p-[22px]">
                    <div className="mb-4 font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-2">
                      版本时间线 · {versions.length}
                    </div>
                    <VersionTimeline strategyId={activeId ?? ""} versions={versions as unknown as VersionItem[]} latestVersionId={latestVersionId} />
                  </VoltCard>
                </div>
              )}

              {/* 发布 Tab */}
              {tab === "publish" && (
                <div className="p-6">
                  <VoltCard className="p-[22px]">
                    <div className="mb-4 font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-2">
                      发布上线(目标 dry-run)
                    </div>
                    <PublishFlow
                      version={latest ? { id: latestVersionId, version_no: Number(latest.version_no ?? 0), status: String(latest.status ?? "draft") } : null}
                      onGoto={(t) => setTab(t)}
                    />
                  </VoltCard>
                </div>
              )}
            </>
          )}
        </div>
      </div>
      </>
      )}

      {/* 新建策略弹窗(grid / detail 共用) */}
      {showNew && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/55 p-6" onClick={() => setShowNew(false)}>
          <div className="w-full max-w-[360px] rounded-[16px] border border-border bg-card p-6 shadow-modal" onClick={(e) => e.stopPropagation()}>
            <div className="text-[16px] font-bold text-text">新建策略</div>
            <div className="mt-4">
              <input
                value={newName}
                onChange={(e) => setNewName(e.target.value)}
                placeholder="策略名称"
                autoFocus
                className="w-full rounded-lg border border-border bg-surface px-3 py-2.5 text-[13px] text-text outline-none focus:border-accent-text/60"
              />
            </div>
            {createStrategy.isError && (
              <div className="mt-2 rounded-lg bg-bear/10 px-3 py-2 text-[12px] text-bear">创建失败,请重试</div>
            )}
            <VoltButton
              size="lg"
              className="mt-4 w-full"
              disabled={!newName.trim() || createStrategy.isPending}
              onClick={() => createStrategy.mutate(newName.trim())}
            >
              {createStrategy.isPending ? "创建中…" : "创建"}
            </VoltButton>
          </div>
        </div>
      )}
    </div>
  );
}

/* ================= 校验面板 ================= */

function ValidationPanel({
  validate,
  latest,
  latestVersionId,
}: {
  validate: ReturnType<typeof useValidateDSL>;
  latest: Record<string, unknown> | undefined;
  latestVersionId: string;
}) {
  const result = validate.data;

  if (!latest) {
    return <EmptyState icon={<ShieldCheck />} title="无版本" description="该策略暂无版本可校验。" />;
  }

  return (
    <div className="space-y-4">
      {/* 校验操作 */}
      <VoltCard className="p-[22px]">
        <div className="flex items-center justify-between">
          <div className="font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-2">
            DSL 校验
          </div>
          <VoltButton
            size="sm"
            onClick={() => validate.mutate(latest.rule_dsl as Record<string, unknown>)}
            disabled={validate.isPending}
          >
            {validate.isPending ? "校验中…" : "重新校验"}
          </VoltButton>
        </div>
        {result && (
          <div className="mt-4 space-y-3">
            {/* 总状态 */}
            <div className={cn(
              "flex items-center gap-2.5 rounded-lg px-3.5 py-2.5 text-[13px] font-semibold",
              result.valid ? "bg-bull/10 text-bull" : "bg-bear/10 text-bear"
            )}>
              {result.valid ? <CheckCircle2 className="size-4" /> : <XCircle className="size-4" />}
              {result.valid ? "校验通过" : `校验失败 (${result.error_count} 个错误)`}
              {result.warning_count > 0 && (
                <span className="ml-2 text-warn">
                  <AlertTriangle className="mr-1 inline size-3.5" />
                  {result.warning_count} 个警告
                </span>
              )}
            </div>

            {/* 错误列表 */}
            {result.errors.length > 0 && (
              <div className="space-y-1.5">
                <div className="font-mono text-[10px] font-semibold uppercase tracking-[0.08em] text-bear">错误</div>
                {result.errors.map((e, i) => (
                  <div key={i} className="rounded-lg border border-bear/20 bg-bear/5 px-3 py-2">
                    <div className="flex items-center gap-2">
                      <span className="rounded bg-bear/15 px-1.5 py-0.5 font-mono text-[10px] font-bold text-bear">{e.code}</span>
                      <span className="font-mono text-[11px] text-text-3">{e.path}</span>
                    </div>
                    <div className="mt-1 text-[12px] text-text">{e.message}</div>
                  </div>
                ))}
              </div>
            )}

            {/* 警告列表 */}
            {result.warnings.length > 0 && (
              <div className="space-y-1.5">
                <div className="font-mono text-[10px] font-semibold uppercase tracking-[0.08em] text-warn">警告</div>
                {result.warnings.map((w, i) => (
                  <div key={i} className="rounded-lg border border-warn/20 bg-warn/5 px-3 py-2">
                    <div className="flex items-center gap-2">
                      <span className="rounded bg-warn/15 px-1.5 py-0.5 font-mono text-[10px] font-bold text-warn">{w.code}</span>
                      <span className="font-mono text-[11px] text-text-3">{w.path}</span>
                    </div>
                    <div className="mt-1 text-[12px] text-text">{w.message}</div>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}
        {!result && !validate.isPending && (
          <div className="mt-3 text-[12.5px] text-text-2">
            点击「重新校验」对当前版本 DSL 进行完整规则校验。
          </div>
        )}
      </VoltCard>

      {/* 版本信息 */}
      <VoltCard className="p-[22px]">
        <div className="font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-2">
          版本信息
        </div>
        <div className="mt-3 grid grid-cols-2 gap-x-6 gap-y-2">
          {[
            ["版本号", String(latest.version_no ?? "—")],
            ["状态", String(latest.status ?? "—")],
            ["DSL Hash", String(latest.dsl_hash ?? "—").slice(0, 16) + "…"],
            ["版本 ID", latestVersionId.slice(0, 8) + "…"],
          ].map(([k, v]) => (
            <div key={k}>
              <div className="font-mono text-[10px] uppercase tracking-[0.08em] text-text-3">{k}</div>
              <div className="tnum mt-0.5 font-mono text-[13px] font-semibold text-text">{v}</div>
            </div>
          ))}
        </div>
      </VoltCard>
    </div>
  );
}

/* ================= 回测面板 ================= */

function BacktestPanel({
  backtests,
  latestVersionId,
}: {
  backtests: Record<string, unknown>[];
  latestVersionId: string;
}) {
  const [starting, setStarting] = useState(false);

  return (
    <div className="space-y-4">
      {/* 启动回测 */}
      <VoltCard className="p-[22px]">
        <div className="flex items-center justify-between">
          <div className="font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-2">
            回测
          </div>
          <VoltButton
            size="sm"
            icon={<History />}
            disabled={starting || !latestVersionId}
            onClick={() => setStarting(true)}
          >
            {starting ? "启动中…" : "启动回测"}
          </VoltButton>
        </div>
        <div className="mt-2 text-[12.5px] text-text-2">
          对当前版本运行历史回测,验证策略在过去行情中的表现。
        </div>
      </VoltCard>

      {/* 回测记录 */}
      <VoltCard className="overflow-hidden">
        <div className="border-b border-border px-5 py-3.5 font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-2">
          回测记录 · {backtests.length}
        </div>
        {backtests.length === 0 ? (
          <EmptyState compact icon={<History />} title="暂无回测记录" description="启动一次回测后,结果会显示在这里。" />
        ) : (
          <div className="divide-y divide-border/50">
            {backtests.map((bt) => (
              <div key={String(bt.id)} className="flex items-center gap-4 px-5 py-3">
                <span className="font-mono text-[12px] font-semibold text-text">#{String(bt.id)}</span>
                <span
                  className="rounded-md px-2 py-0.5 text-[11px] font-semibold"
                  style={{
                    color: statusTone(String(bt.status ?? "")),
                    background: `color-mix(in srgb, ${statusTone(String(bt.status ?? ""))} 12%, transparent)`,
                  }}
                >
                  {String(bt.status ?? "—")}
                </span>
                <div className="ml-auto flex items-center gap-4 font-mono text-[12px]">
                  {bt.total_return != null && (
                    <span className={Number(bt.total_return) >= 0 ? "text-bull" : "text-bear"}>
                      {Number(bt.total_return) >= 0 ? "+" : ""}{Number(bt.total_return).toFixed(2)}%
                    </span>
                  )}
                  {bt.sharpe_ratio != null && (
                    <span className="text-text-2">Sharpe {Number(bt.sharpe_ratio).toFixed(2)}</span>
                  )}
                  {bt.max_drawdown != null && (
                    <span className="text-bear">MDD {Number(bt.max_drawdown).toFixed(1)}%</span>
                  )}
                  {bt.win_rate != null && (
                    <span className="text-text-2">胜率 {Number(bt.win_rate).toFixed(0)}%</span>
                  )}
                </div>
                <span className="font-mono text-[11px] text-text-3">
                  {bt.started_at ? new Date(String(bt.started_at)).toLocaleDateString("zh-CN") : "—"}
                </span>
              </div>
            ))}
          </div>
        )}
      </VoltCard>
    </div>
  );
}

/* ================= Dry-run 面板 ================= */

function DryrunPanel({
  dryruns,
  latestVersionId,
  readiness,
}: {
  dryruns: Record<string, unknown>[];
  latestVersionId: string;
  readiness: Record<string, unknown> | undefined;
}) {
  const readinessChecks = (readiness?.checks ?? []) as Record<string, unknown>[];

  return (
    <div className="space-y-4">
      {/* 就绪状态 */}
      {readiness && (
        <VoltCard className="p-[22px]">
          <div className="flex items-center gap-2 font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-2">
            <Shield className="size-4 text-accent-text" />
            策略就绪检查
          </div>
          <div className="mt-3 space-y-1.5">
            {readinessChecks.map((c) => {
              const ok = ["pass", "ok", "healthy"].includes(String(c.status ?? "").toLowerCase());
              return (
                <div key={String(c.key)} className="flex items-center gap-2.5 py-1">
                  <span className={cn("size-1.5 rounded-full", ok ? "bg-bull" : "bg-bear")} />
                  <span className="flex-1 text-[12.5px] text-text-2">{String(c.label ?? c.key)}</span>
                  <span className={cn("font-mono text-[11px] font-semibold", ok ? "text-bull" : "text-bear")}>
                    {String(c.value ?? c.status ?? "—")}
                  </span>
                </div>
              );
            })}
          </div>
        </VoltCard>
      )}

      {/* Dry-run 记录 */}
      <VoltCard className="overflow-hidden">
        <div className="border-b border-border px-5 py-3.5 font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-2">
          Dry-run 记录 · {dryruns.length}
        </div>
        {dryruns.length === 0 ? (
          <EmptyState compact icon={<PlayCircle />} title="暂无 Dry-run 记录" description="启动模拟运行后,状态会显示在这里。" />
        ) : (
          <div className="divide-y divide-border/50">
            {dryruns.map((dr) => (
              <div key={String(dr.id)} className="flex items-center gap-4 px-5 py-3">
                <span className="font-mono text-[12px] font-semibold text-text">#{String(dr.id).slice(0, 8)}</span>
                <span className="rounded-md bg-accent-soft px-2 py-0.5 font-mono text-[11px] font-semibold text-accent-text">
                  {String(dr.mode ?? "—")}
                </span>
                <span
                  className="rounded-md px-2 py-0.5 text-[11px] font-semibold"
                  style={{
                    color: statusTone(String(dr.status ?? "")),
                    background: `color-mix(in srgb, ${statusTone(String(dr.status ?? ""))} 12%, transparent)`,
                  }}
                >
                  {String(dr.status ?? "—")}
                </span>
                <span className="ml-auto font-mono text-[11px] text-text-3">
                  {dr.started_at ? new Date(String(dr.started_at)).toLocaleString("zh-CN", { hour12: false }) : "—"}
                </span>
              </div>
            ))}
          </div>
        )}
      </VoltCard>
    </div>
  );
}