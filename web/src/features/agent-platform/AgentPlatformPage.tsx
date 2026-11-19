import { useState } from "react";
import { Bot, Pencil, Play, Plus, Trash2, X } from "lucide-react";
import { EmptyState } from "@/components/shell/EmptyState";
import { PageHeader } from "@/components/shell/PageHeader";
import { VoltButton } from "@/components/shell/VoltButton";
import { VoltCard } from "@/components/shell/VoltCard";
import { VoltSelect } from "@/components/shell/VoltSelect";
import { FadeIn } from "@/components/effects/FadeIn";
import {
  useAgentRuntimes,
  useAgents,
  useAgentTasks,
  useCreateAgent,
  useDeleteAgent,
  useRunAgent,
  useUpdateAgent,
} from "@/lib/hooks";
import type { AgentProfile } from "@/lib/types";
import { cn } from "@/lib/utils";

/* ---------- 常量与标签 ---------- */

const RUNTIME_LABELS: Record<string, string> = {
  native: "平台原生",
  qoder: "Qoder 沙箱",
  "claude-code": "Claude Code 沙箱",
};
const PERMISSION_LABELS: Record<string, string> = {
  readonly: "只读",
  approval: "审批后执行",
  auto: "完全自动",
};
const TRIGGER_LABELS: Record<string, string> = { manual: "手动", schedule: "定时", event: "事件" };
const OUTPUT_LABELS: Record<string, string> = { inbox: "收件箱", signals: "信号中心", growth: "成长复盘" };

function runtimeTone(rt: string): string {
  if (rt === "qoder") return "bg-accent/12 text-accent-text";
  if (rt === "claude-code") return "bg-bull/12 text-bull";
  return "bg-surface text-text-3";
}
function permissionTone(p: string): string {
  if (p === "auto") return "bg-bear/12 text-bear";
  if (p === "approval") return "bg-warn/12 text-warn";
  return "bg-bull/12 text-bull";
}

/* ---------- 页面 ---------- */

export default function AgentPlatformPage() {
  const { data: agents } = useAgents();
  const { data: runtimes } = useAgentRuntimes();
  const { data: tasks } = useAgentTasks();
  const runAgent = useRunAgent();
  const del = useDeleteAgent();
  const [showForm, setShowForm] = useState(false);
  const [editTarget, setEditTarget] = useState<AgentProfile | null>(null);

  const activeAgents = (agents ?? []).filter((a) => a.status !== "archived");

  return (
    <div className="mx-auto w-full max-w-[1340px] space-y-4 px-7 py-6">
      <FadeIn index={0}>
        <PageHeader
          eyebrow="AGENT PLATFORM"
          title="Agent 平台"
          subtitle="以沙箱实例方式创建 agent 个体 — 每个 agent 绑定一个运行时与权限边界"
          trailing={<VoltButton onClick={() => setShowForm(true)}><Plus className="size-4" />新增 Agent</VoltButton>}
        />
      </FadeIn>

      {/* 运行时可用性 */}
      <FadeIn index={1}>
        <VoltCard className="flex items-center gap-5 px-5 py-3.5">
          <span className="font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-2">
            运行时
          </span>
          {Object.entries(runtimes?.runtimes ?? {}).map(([key, rt]) => (
            <span key={key} className="flex items-center gap-2 font-mono text-[12px]">
              <span className={cn("size-1.5 rounded-full", rt.available ? "bg-bull" : "bg-bear")} />
              <span className="text-text">{RUNTIME_LABELS[key] ?? key}</span>
              {!rt.available && rt.reason && (
                <span className="text-[10.5px] text-text-3">{rt.reason}</span>
              )}
            </span>
          ))}
        </VoltCard>
      </FadeIn>

      {/* Agent 卡片 */}
      <FadeIn index={2}>
        {activeAgents.length === 0 ? (
          <VoltCard>
            <EmptyState
              icon={<Bot />}
              title="暂无 Agent"
              description="创建第一个 Agent — 选择 Qoder / Claude Code 沙箱运行时，或平台原生 TradingAgents 链路。"
              action={<VoltButton onClick={() => setShowForm(true)}><Plus className="size-4" />新增 Agent</VoltButton>}
            />
          </VoltCard>
        ) : (
          <div className="grid grid-cols-3 gap-3.5">
            {activeAgents.map((a) => (
              <VoltCard key={a.id} spotlight className="p-5">
                <div className="flex items-center gap-3">
                  <span className="flex size-10 items-center justify-center rounded-lg bg-accent-soft font-display text-[15px] font-bold text-accent-text">
                    {a.name.slice(0, 1).toUpperCase()}
                  </span>
                  <div className="min-w-0">
                    <div className="truncate font-semibold text-text">{a.name}</div>
                    <div className="flex items-center gap-1.5">
                      <span className={cn("rounded px-1.5 py-0.5 font-mono text-[10px] font-semibold", runtimeTone(a.runtime_type))}>
                        {RUNTIME_LABELS[a.runtime_type] ?? a.runtime_type}
                      </span>
                      <span className={cn("rounded px-1.5 py-0.5 font-mono text-[10px] font-semibold", permissionTone(a.permission_mode))}>
                        {PERMISSION_LABELS[a.permission_mode] ?? a.permission_mode}
                      </span>
                    </div>
                  </div>
                </div>
                {a.description && (
                  <p className="mt-3 line-clamp-2 text-[12.5px] text-text-2">{a.description}</p>
                )}
                <div className="mt-3 space-y-1 font-mono text-[10.5px] text-text-3">
                  <div>模型:{a.model ?? "运行时默认"} · 轮次上限:{a.max_turns}</div>
                  <div>触发:{TRIGGER_LABELS[a.trigger_type] ?? a.trigger_type} · 输出:{OUTPUT_LABELS[a.output_target] ?? a.output_target}</div>
                </div>
                <div className="mt-4 flex gap-2 border-t border-border/50 pt-3">
                  <VoltButton
                    size="sm"
                    disabled={runAgent.isPending}
                    onClick={() => runAgent.mutate({ id: a.id })}
                  >
                    <Play className="size-3.5" />运行
                  </VoltButton>
                  <VoltButton size="sm" variant="secondary" onClick={() => setEditTarget(a)}>
                    <Pencil className="size-3.5" />编辑
                  </VoltButton>
                  <VoltButton
                    size="sm"
                    variant="ghost"
                    className="ml-auto text-text-3 hover:text-bear"
                    onClick={() => del.mutate(a.id)}
                  >
                    <Trash2 className="size-3.5" />
                  </VoltButton>
                </div>
              </VoltCard>
            ))}
          </div>
        )}
      </FadeIn>

      {/* 任务运行记录 */}
      <FadeIn index={3}>
        <VoltCard className="overflow-hidden">
          <div className="border-b border-border px-5 py-3.5 font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-2">
            运行记录
          </div>
          {(tasks ?? []).length === 0 ? (
            <div className="px-5 py-8 text-center text-[12.5px] text-text-2">暂无运行记录</div>
          ) : (
            <div className="divide-y divide-border/50">
              {(tasks ?? []).slice(0, 15).map((t) => (
                <div key={t.task_id} className="flex items-center gap-3 px-5 py-2.5 text-[12.5px]">
                  <span className={cn(
                    "size-1.5 shrink-0 rounded-full",
                    t.status === "succeeded" ? "bg-bull" : t.status === "failed" ? "bg-bear" : "bg-warn animate-pulse"
                  )} />
                  <span className="font-mono text-text">{t.symbol ?? "—"}</span>
                  <span className={cn("rounded px-1.5 py-0.5 font-mono text-[10px]", runtimeTone(t.runtime_type))}>
                    {RUNTIME_LABELS[t.runtime_type] ?? t.runtime_type}
                  </span>
                  <span className="text-text-2">{t.status}</span>
                  {t.error_message && (
                    <span className="truncate text-[11px] text-bear">{t.error_message}</span>
                  )}
                  <span className="ml-auto font-mono text-[10.5px] text-text-3">
                    {t.created_at ? new Date(t.created_at).toLocaleString("zh-CN", { hour12: false }) : ""}
                  </span>
                </div>
              ))}
            </div>
          )}
        </VoltCard>
      </FadeIn>

      {(showForm || editTarget) && (
        <AgentFormDialog
          initial={editTarget}
          onClose={() => { setShowForm(false); setEditTarget(null); }}
        />
      )}
    </div>
  );
}

/* ---------- 新增 / 编辑弹窗 ---------- */

function AgentFormDialog({ initial, onClose }: { initial: AgentProfile | null; onClose: () => void }) {
  const create = useCreateAgent();
  const update = useUpdateAgent();
  const [name, setName] = useState(initial?.name ?? "");
  const [kind, setKind] = useState(initial?.kind ?? "research");
  const [description, setDescription] = useState(initial?.description ?? "");
  const [runtimeType, setRuntimeType] = useState(initial?.runtime_type ?? "qoder");
  const [model, setModel] = useState(initial?.model ?? "");
  const [cwd, setCwd] = useState(initial?.cwd ?? "");
  const [permissionMode, setPermissionMode] = useState(initial?.permission_mode ?? "readonly");
  const [maxTurns, setMaxTurns] = useState(initial?.max_turns ?? 20);
  const [triggerType, setTriggerType] = useState(initial?.trigger_type ?? "manual");
  const [outputTarget, setOutputTarget] = useState(initial?.output_target ?? "inbox");
  const [systemPrompt, setSystemPrompt] = useState(initial?.system_prompt ?? "");

  const pending = create.isPending || update.isPending;
  const submit = () => {
    const body = {
      name, kind, description: description || null,
      runtime_type: runtimeType, model: model || null, cwd: cwd || null,
      permission_mode: permissionMode, allowed_tools: [],
      max_turns: maxTurns, trigger_type: triggerType,
      output_target: outputTarget, system_prompt: systemPrompt || null,
    };
    const onDone = () => onClose();
    if (initial) update.mutate({ id: initial.id, ...body }, { onSuccess: onDone });
    else create.mutate(body, { onSuccess: onDone });
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/55 p-6" onClick={onClose}>
      <div
        className="max-h-[85vh] w-full max-w-[560px] overflow-y-auto rounded-[16px] border border-border bg-card p-6 shadow-modal"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center justify-between">
          <h3 className="text-[16px] font-bold text-text">{initial ? "编辑 Agent" : "新增 Agent"}</h3>
          <button onClick={onClose} className="text-text-3 hover:text-text"><X className="size-4" /></button>
        </div>

        <div className="mt-5 space-y-4">
          <Field label="名称" required>
            <input value={name} onChange={(e) => setName(e.target.value)} className={inputCls} placeholder="如:投研助手" />
          </Field>
          <Field label="职责描述">
            <input value={description} onChange={(e) => setDescription(e.target.value)} className={inputCls} placeholder="这个 agent 做什么" />
          </Field>

          <div className="grid grid-cols-2 gap-3">
            <Field label="运行时" required>
              <VoltSelect
                label="运行时"
                value={runtimeType}
                onChange={setRuntimeType}
                options={[
                  { value: "qoder", label: "Qoder 沙箱" },
                  { value: "claude-code", label: "Claude Code 沙箱" },
                  { value: "native", label: "平台原生 (TradingAgents)" },
                ]}
              />
            </Field>
            <Field label="类型">
              <VoltSelect
                label="类型"
                value={kind}
                onChange={setKind}
                options={[
                  { value: "research", label: "研究型" },
                  { value: "signal", label: "信号型" },
                  { value: "ops", label: "运维型" },
                ]}
              />
            </Field>
          </div>

          {runtimeType !== "native" && (
            <>
              <div className="grid grid-cols-2 gap-3">
                <Field label="模型" hint="留空用运行时默认">
                  <input value={model} onChange={(e) => setModel(e.target.value)} className={inputCls} placeholder="default" />
                </Field>
                <Field label="轮次上限">
                  <input type="number" value={maxTurns} onChange={(e) => setMaxTurns(Number(e.target.value))} className={inputCls} min={1} max={200} />
                </Field>
              </div>
              <Field label="工作目录(沙箱边界)" hint="agent 只能在该目录内读写">
                <input value={cwd} onChange={(e) => setCwd(e.target.value)} className={inputCls} placeholder="/path/to/workspace" />
              </Field>
              <Field label="权限模式" required>
                <div className="grid grid-cols-3 gap-2">
                  {(["readonly", "approval", "auto"] as const).map((m) => (
                    <button
                      key={m}
                      onClick={() => setPermissionMode(m)}
                      className={cn(
                        "rounded-lg border px-2 py-2 text-[12px] font-medium transition-colors",
                        permissionMode === m
                          ? "border-accent bg-accent-soft text-accent-text"
                          : "border-border text-text-2 hover:border-border-hover"
                      )}
                    >
                      {PERMISSION_LABELS[m]}
                    </button>
                  ))}
                </div>
                {permissionMode === "auto" && (
                  <div className="mt-1.5 text-[11px] text-bear">⚠ 完全自动模式不经过任何审批,仅建议用于隔离环境</div>
                )}
              </Field>
              <Field label="系统提示词(角色注入)">
                <textarea
                  value={systemPrompt}
                  onChange={(e) => setSystemPrompt(e.target.value)}
                  className={cn(inputCls, "min-h-20 resize-y")}
                  placeholder="如:你是加密市场研究助手,只做只读分析,输出结构化结论"
                />
              </Field>
            </>
          )}

          <div className="grid grid-cols-2 gap-3">
            <Field label="触发方式">
              <VoltSelect
                label="触发方式"
                value={triggerType}
                onChange={setTriggerType}
                options={[
                  { value: "manual", label: "手动" },
                  { value: "schedule", label: "定时(待调度器接入)" },
                  { value: "event", label: "事件(待信号接入)" },
                ]}
              />
            </Field>
            <Field label="输出目标">
              <VoltSelect
                label="输出目标"
                value={outputTarget}
                onChange={setOutputTarget}
                options={[
                  { value: "inbox", label: "收件箱" },
                  { value: "signals", label: "信号中心" },
                  { value: "growth", label: "成长复盘" },
                ]}
              />
            </Field>
          </div>
        </div>

        <div className="mt-6 flex gap-2">
          <VoltButton variant="secondary" onClick={onClose} className="flex-1">取消</VoltButton>
          <VoltButton onClick={submit} disabled={!name || pending} className="flex-1">
            {pending ? "保存中…" : initial ? "保存修改" : "创建 Agent"}
          </VoltButton>
        </div>
      </div>
    </div>
  );
}

const inputCls =
  "w-full rounded-lg border border-border bg-surface px-3 py-2 text-[13px] text-text outline-none transition-colors focus:border-accent placeholder:text-text-3";

function Field({ label, hint, required, children }: {
  label: string; hint?: string; required?: boolean; children: React.ReactNode;
}) {
  return (
    <div>
      <div className="mb-1.5 flex items-baseline gap-2">
        <span className="text-[12px] font-medium text-text-2">
          {label}{required && <span className="ml-0.5 text-bear">*</span>}
        </span>
        {hint && <span className="text-[10.5px] text-text-3">{hint}</span>}
      </div>
      {children}
    </div>
  );
}
