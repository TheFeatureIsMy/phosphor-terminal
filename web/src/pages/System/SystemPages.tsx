import { useState } from "react";
import { Database, Pencil, Play, Plus, RotateCcw, Server, Square, TestTube, Trash2, X } from "lucide-react";
import { EmptyState } from "@/components/shell/EmptyState";
import { PageHeader } from "@/components/shell/PageHeader";
import { VoltButton } from "@/components/shell/VoltButton";
import { VoltCard } from "@/components/shell/VoltCard";
import { FadeIn } from "@/components/effects/FadeIn";
import {
  useAdminProviders,
  useCreateProvider,
  useDeleteProvider,
  useGlobalStatus,
  useTestProvider,
  useToggleProvider,
  useUpdateProvider,
} from "@/lib/hooks";
import {
  CATEGORY_LABELS,
  DATA_SOURCE_CATEGORIES,
  SERVICE_CATEGORIES,
  findProviderSchema,
  providersByCategory,
  type FieldDef,
} from "@/lib/provider-schemas";
import { cn } from "@/lib/utils";

/* ---------- 服务管理 ---------- */

const SERVICE_LIST = [
  { key: "backend", label: "后端 API", desc: "FastAPI 应用服务" },
  { key: "database", label: "PostgreSQL", desc: "主数据库" },
  { key: "redis", label: "Redis", desc: "缓存与实时状态" },
  { key: "freqtrade", label: "Freqtrade 引擎", desc: "交易执行容器" },
  { key: "worker", label: "Worker Queue", desc: "命令总线消费者" },
  { key: "scheduler", label: "Scheduler", desc: "定时任务调度" },
] as const;

export function ServiceManagementPage() {
  const { data: providers } = useAdminProviders();
  const { data: status } = useGlobalStatus();
  const toggle = useToggleProvider();
  const test = useTestProvider();
  const [showAdd, setShowAdd] = useState(false);
  const [editTarget, setEditTarget] = useState<Record<string, unknown> | null>(null);

  const serviceState = (key: string): { status: string; ok: boolean } => {
    if (!status) return { status: "—", ok: false };
    const map: Record<string, string> = {
      backend: "ok",
      database: "ok",
      redis: status.redis_rtt_ms != null ? `${status.redis_rtt_ms}ms` : "—",
      freqtrade: status.freqtrade_state ?? "unknown",
      worker: "ok",
      scheduler: "ok",
    };
    const s = map[key] ?? "unknown";
    const ok = ["ok", "alive", "healthy"].includes(s.toLowerCase()) || s.endsWith("ms");
    return { status: s, ok };
  };

  return (
    <div className="mx-auto w-full max-w-[1340px] space-y-4 px-7 py-6">
      <FadeIn index={0}>
        <PageHeader
          eyebrow="SERVICES"
          title="服务管理"
          subtitle="后端服务与 Provider 进程的运行状态"
          trailing={
            <VoltButton size="md" icon={<Plus />} onClick={() => setShowAdd(true)}>
              新增 Provider
            </VoltButton>
          }
        />
      </FadeIn>

      {/* 核心服务 */}
      <FadeIn index={1}>
        <VoltCard spotlight className="p-[22px]">
          <div className="flex items-center gap-2 font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-2">
            <Server className="size-4 text-accent-text" />
            核心服务
          </div>
          <div className="mt-4 grid grid-cols-3 gap-3">
            {SERVICE_LIST.map((s) => {
              const st = serviceState(s.key);
              return (
                <div key={s.key} className="rounded-lg border border-border bg-surface p-4">
                  <div className="flex items-center justify-between">
                    <span className="text-[13px] font-medium text-text">{s.label}</span>
                    <div className="flex items-center gap-1.5">
                      <button
                        className="rounded p-1 text-text-3 transition-colors hover:bg-surface-hover hover:text-text"
                        title="重启(需后端支持)"
                        disabled
                      >
                        <RotateCcw className="size-3" />
                      </button>
                      <span className={cn("size-1.5 rounded-full", st.ok ? "bg-bull" : "bg-bear")} />
                    </div>
                  </div>
                  <div className="mt-1 font-mono text-[11px] text-text-3">{s.desc}</div>
                  <div className={cn(
                    "mt-2 font-mono text-[12px] font-semibold",
                    st.ok ? "text-bull" : "text-bear"
                  )}>
                    {st.status.toUpperCase()}
                  </div>
                </div>
              );
            })}
          </div>
        </VoltCard>
      </FadeIn>

      {/* Provider 进程 */}
      <FadeIn index={2}>
        <VoltCard spotlight className="overflow-hidden">
          <div className="flex items-center justify-between border-b border-border px-5 py-3.5">
            <span className="font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-2">
              Provider 进程
            </span>
            <span className="font-mono text-[10px] text-text-3">
              {(providers ?? []).filter((p) => SERVICE_CATEGORIES.includes(String(p.category))).length} 个已注册
            </span>
          </div>
          {(providers ?? []).filter((p) => SERVICE_CATEGORIES.includes(String(p.category))).length === 0 ? (
            <EmptyState compact icon={<Server />} title="暂无 Provider" description="LLM / 通知 / 交易所 Provider 注册后,运行状态会显示在这里。" />
          ) : (
            <div className="divide-y divide-border/50">
              {providers!.filter((p) => SERVICE_CATEGORIES.includes(String(p.category))).map((p) => {
                const id = Number(p.id);
                const enabled = p.enabled !== false;
                return (
                  <div key={String(p.id)} className="flex items-center gap-3 px-5 py-3">
                    <span className="font-semibold text-text">{String(p.provider_name ?? p.name ?? p.id)}</span>
                    <span className="rounded-md bg-surface px-2 py-0.5 font-mono text-[10px] text-text-3">
                      {String(p.category ?? p.kind ?? "")}
                    </span>
                    {p.instance_name != null && (
                      <span className="font-mono text-[11px] text-text-3">{String(p.instance_name)}</span>
                    )}
                    <div className="ml-auto flex items-center gap-2">
                      {/* 编辑 */}
                      <button
                        onClick={() => setEditTarget(p as Record<string, unknown>)}
                        className="rounded-lg p-1.5 text-text-3 transition-colors hover:bg-surface-hover hover:text-text"
                        title="编辑配置"
                      >
                        <Pencil className="size-3.5" />
                      </button>
                      {/* 测试连接 */}
                      <button
                        onClick={() => test.mutate(id)}
                        disabled={test.isPending}
                        className="rounded-lg p-1.5 text-text-3 transition-colors hover:bg-surface-hover hover:text-text"
                        title="测试连接"
                      >
                        <TestTube className="size-3.5" />
                      </button>
                      {/* 启停 */}
                      <button
                        onClick={() => toggle.mutate({ id, enable: !enabled })}
                        disabled={toggle.isPending}
                        className={cn(
                          "rounded-lg p-1.5 transition-colors",
                          enabled ? "text-bull hover:bg-bull/10" : "text-text-3 hover:bg-surface-hover hover:text-text"
                        )}
                        title={enabled ? "停用" : "启用"}
                      >
                        {enabled ? <Square className="size-3.5" /> : <Play className="size-3.5" />}
                      </button>
                      <span className={cn(
                        "rounded-md px-2 py-0.5 text-[11px] font-semibold",
                        !enabled ? "bg-surface text-text-3" : String(p.status) === "active" ? "bg-bull/12 text-bull" : "bg-warn/12 text-warn"
                      )}>
                        {!enabled ? "disabled" : String(p.status ?? "unknown")}
                      </span>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </VoltCard>
      </FadeIn>
      {/* 新增 Provider */}
      {showAdd && <AddProviderDialog onClose={() => setShowAdd(false)} categories={SERVICE_CATEGORIES} defaultCategory="llm" />}

      {/* 编辑 Provider */}
      {editTarget && <EditProviderDialog provider={editTarget} onClose={() => setEditTarget(null)} />}
    </div>
  );
}

/* ---------- 编辑 Provider 弹窗 ---------- */

function EditProviderDialog({ provider, onClose }: { provider: Record<string, unknown>; onClose: () => void }) {
  const update = useUpdateProvider();
  const [config, setConfig] = useState(() => JSON.stringify(provider.config ?? {}, null, 2));
  const [apiKey, setApiKey] = useState("");
  const [error, setError] = useState("");
  const id = Number(provider.id);

  const submit = () => {
    setError("");
    let parsedConfig: Record<string, unknown>;
    try {
      parsedConfig = JSON.parse(config);
    } catch {
      setError("配置 JSON 格式不正确");
      return;
    }
    const body: Record<string, unknown> = { config: parsedConfig };
    if (apiKey) body.credentials = { api_key: apiKey };
    update.mutate(
      { id, ...body },
      {
        onSuccess: () => onClose(),
        onError: (e) => setError(e instanceof Error ? e.message : "保存失败"),
      }
    );
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/55 p-6" onClick={onClose}>
      <div className="w-full max-w-[440px] rounded-[16px] border border-border bg-card p-6 shadow-modal" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-center justify-between">
          <div className="text-[16px] font-bold text-text">
            编辑 {String(provider.provider_name ?? provider.name ?? provider.id)}
          </div>
          <button onClick={onClose} className="rounded-lg p-1.5 text-text-3 hover:bg-surface-hover hover:text-text">
            <X className="size-4" />
          </button>
        </div>
        <div className="mt-5 space-y-4">
          <div>
            <div className="mb-1.5 font-mono text-[10px] uppercase tracking-[0.08em] text-text-3">配置 (JSON)</div>
            <textarea
              value={config}
              onChange={(e) => setConfig(e.target.value)}
              rows={5}
              className="w-full rounded-lg border border-border bg-surface px-3 py-2.5 font-mono text-[12px] text-text outline-none focus:border-accent-text/60"
            />
          </div>
          <div>
            <div className="mb-1.5 font-mono text-[10px] uppercase tracking-[0.08em] text-text-3">
              更新 API Key(留空保持不变)
            </div>
            <input
              value={apiKey}
              onChange={(e) => setApiKey(e.target.value)}
              type="password"
              placeholder="sk-..."
              className="w-full rounded-lg border border-border bg-surface px-3 py-2.5 font-mono text-[13px] text-text outline-none focus:border-accent-text/60"
            />
          </div>
          {error && <div className="rounded-lg bg-bear/10 px-3 py-2 text-[12px] text-bear">{error}</div>}
          <div className="flex gap-2.5">
            <VoltButton variant="secondary" onClick={onClose} className="flex-1">取消</VoltButton>
            <VoltButton onClick={submit} disabled={update.isPending} className="flex-1">
              {update.isPending ? "保存中…" : "保存"}
            </VoltButton>
          </div>
        </div>
      </div>
    </div>
  );
}

/* ---------- 数据源管理 ---------- */

/* ---------- 动态 Provider 表单(按 Schema 渲染) ---------- */

function FormField({ field, value, onChange }: { field: FieldDef; value: string; onChange: (v: string) => void }) {
  return (
    <div>
      <div className="mb-1.5 flex items-baseline gap-2">
        <span className="font-mono text-[10px] uppercase tracking-[0.08em] text-text-3">{field.label}</span>
        {field.required && <span className="text-[10px] text-bear">*</span>}
      </div>
      <input
        value={value}
        onChange={(e) => onChange(e.target.value)}
        type={field.type === "password" ? "password" : field.type === "number" ? "number" : "text"}
        placeholder={field.placeholder}
        className="w-full rounded-lg border border-border bg-surface px-3 py-2.5 font-mono text-[13px] text-text outline-none focus:border-accent-text/60"
      />
      {field.hint && <div className="mt-1 text-[11px] text-text-3">{field.hint}</div>}
    </div>
  );
}

function AddProviderDialog({ onClose, categories, defaultCategory }: { onClose: () => void; categories: string[]; defaultCategory: string }) {
  const create = useCreateProvider();
  const [category, setCategory] = useState(defaultCategory);
  const [providerName, setProviderName] = useState("");
  const [instanceName, setInstanceName] = useState("");
  const [formValues, setFormValues] = useState<Record<string, string>>({});
  const [error, setError] = useState("");

  const schema = findProviderSchema(category, providerName);
  const availableProviders = providersByCategory(category);

  const setField = (key: string, value: string) => {
    setFormValues((prev) => ({ ...prev, [key]: value }));
  };

  const getFieldValue = (key: string, defaultValue?: string) => {
    return formValues[key] ?? defaultValue ?? "";
  };

  const selectProvider = (name: string) => {
    setProviderName(name);
    const s = findProviderSchema(category, name);
    if (s) {
      const defaults: Record<string, string> = {};
      for (const f of [...s.configFields, ...s.credentialFields]) {
        if (f.defaultValue) defaults[f.key] = f.defaultValue;
      }
      setFormValues(defaults);
    }
  };

  const submit = () => {
    setError("");
    if (!schema) { setError("请选择 Provider"); return; }
    const config: Record<string, unknown> = {};
    const credentials: Record<string, string> = {};
    for (const f of schema.configFields) {
      const v = getFieldValue(f.key, f.defaultValue);
      if (v) config[f.key] = f.type === "number" ? parseFloat(v) : v;
    }
    for (const f of schema.credentialFields) {
      const v = getFieldValue(f.key);
      if (v) credentials[f.key] = v;
      else if (f.required) { setError(`${f.label} 不能为空`); return; }
    }
    create.mutate(
      {
        category,
        provider_name: providerName,
        instance_name: category === "llm" ? instanceName || "default" : null,
        config,
        credentials: Object.keys(credentials).length > 0 ? credentials : null,
      },
      {
        onSuccess: () => onClose(),
        onError: (e) => setError(e instanceof Error ? e.message : "创建失败"),
      }
    );
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/55 p-6" onClick={onClose}>
      <div className="w-full max-w-[460px] rounded-[16px] border border-border bg-card p-6 shadow-modal" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-center justify-between">
          <div className="text-[16px] font-bold text-text">新增 Provider</div>
          <button onClick={onClose} className="rounded-lg p-1.5 text-text-3 hover:bg-surface-hover hover:text-text">
            <X className="size-4" />
          </button>
        </div>
        <div className="mt-5 space-y-4">
          {/* 分类 */}
          <div>
            <div className="mb-1.5 font-mono text-[10px] uppercase tracking-[0.08em] text-text-3">分类</div>
            <select
              value={category}
              onChange={(e) => { setCategory(e.target.value); setProviderName(""); setFormValues({}); }}
              className="w-full rounded-lg border border-border bg-surface px-3 py-2.5 text-[13px] text-text outline-none focus:border-accent-text/60"
            >
              {categories.map((k) => (
                <option key={k} value={k}>{CATEGORY_LABELS[k] ?? k}</option>
              ))}
            </select>
          </div>

          {/* Provider 选择 */}
          <div>
            <div className="mb-1.5 font-mono text-[10px] uppercase tracking-[0.08em] text-text-3">Provider</div>
            <div className="grid grid-cols-2 gap-1.5">
              {availableProviders.map((s) => (
                <button
                  key={s.name}
                  onClick={() => selectProvider(s.name)}
                  className={cn(
                    "rounded-lg border px-3 py-2 text-left text-[12.5px] font-medium transition-colors",
                    providerName === s.name
                      ? "border-accent-text/50 bg-accent-soft text-accent-text"
                      : "border-border bg-surface text-text-2 hover:border-border-hover hover:text-text"
                  )}
                >
                  {s.label}
                </button>
              ))}
            </div>
          </div>

          {/* 实例名(LLM) */}
          {category === "llm" && (
            <div>
              <div className="mb-1.5 font-mono text-[10px] uppercase tracking-[0.08em] text-text-3">实例名</div>
              <input
                value={instanceName}
                onChange={(e) => setInstanceName(e.target.value)}
                placeholder="default"
                className="w-full rounded-lg border border-border bg-surface px-3 py-2.5 font-mono text-[13px] text-text outline-none focus:border-accent-text/60"
              />
            </div>
          )}

          {/* 动态字段 */}
          {schema && (
            <>
              {schema.configFields.length > 0 && (
                <div className="space-y-3 border-t border-border/40 pt-4">
                  <div className="font-mono text-[10px] font-semibold uppercase tracking-[0.08em] text-text-3">配置</div>
                  {schema.configFields.map((f) => (
                    <FormField key={f.key} field={f} value={getFieldValue(f.key, f.defaultValue)} onChange={(v) => setField(f.key, v)} />
                  ))}
                </div>
              )}
              {schema.credentialFields.length > 0 && (
                <div className="space-y-3 border-t border-border/40 pt-4">
                  <div className="font-mono text-[10px] font-semibold uppercase tracking-[0.08em] text-text-3">凭证</div>
                  {schema.credentialFields.map((f) => (
                    <FormField key={f.key} field={f} value={getFieldValue(f.key)} onChange={(v) => setField(f.key, v)} />
                  ))}
                </div>
              )}
            </>
          )}

          {error && <div className="rounded-lg bg-bear/10 px-3 py-2 text-[12px] text-bear">{error}</div>}
          <VoltButton onClick={submit} disabled={!providerName || create.isPending} size="lg" className="w-full">
            {create.isPending ? "创建中…" : "创建"}
          </VoltButton>
        </div>
      </div>
    </div>
  );
}

export function DataSourcesPage() {
  const { data: providers } = useAdminProviders();
  const del = useDeleteProvider();
  const toggle = useToggleProvider();
  const test = useTestProvider();
  const [showAdd, setShowAdd] = useState(false);
  const [deleteConfirm, setDeleteConfirm] = useState<number | null>(null);

  // 按分类分组(只显示数据接入型)
  const dataProviders = (providers ?? []).filter((p) =>
    DATA_SOURCE_CATEGORIES.includes(String(p.category))
  );
  const grouped = dataProviders.reduce<Record<string, typeof dataProviders>>((acc, p) => {
    const cat = String(p.category ?? "other");
    (acc[cat] ??= []).push(p);
    return acc;
  }, {});

  return (
    <div className="mx-auto w-full max-w-[1340px] space-y-4 px-7 py-6">
      <FadeIn index={0}>
        <PageHeader
          eyebrow="DATA SOURCES"
          title="数据源"
          subtitle="行情 / 链上 / 新闻数据源的接入与管理"
          trailing={
            <VoltButton size="md" icon={<Plus />} onClick={() => setShowAdd(true)}>
              新增数据源
            </VoltButton>
          }
        />
      </FadeIn>

      {dataProviders.length === 0 ? (
        <FadeIn index={1}>
          <VoltCard>
            <EmptyState icon={<Database />} title="暂无数据源" description="添加第一个数据源来接入行情、链上或新闻数据。" action={<VoltButton onClick={() => setShowAdd(true)}>新增数据源</VoltButton>} />
          </VoltCard>
        </FadeIn>
      ) : (
        Object.entries(grouped).map(([cat, items], gi) => (
          <FadeIn key={cat} index={gi + 1}>
            <VoltCard spotlight className="overflow-hidden">
              <div className="flex items-center justify-between border-b border-border px-5 py-3.5">
                <span className="font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-2">
                  {CATEGORY_LABELS[cat] ?? cat}
                </span>
                <span className="font-mono text-[10px] text-text-3">{items!.length} 个</span>
              </div>
              <div className="divide-y divide-border/50">
                {items!.map((p) => {
                  const id = Number(p.id);
                  const enabled = p.enabled !== false;
                  return (
                    <div key={String(p.id)} className="flex items-center gap-3 px-5 py-3">
                      <span className="font-semibold text-text">{String(p.provider_name ?? p.name ?? p.id)}</span>
                      {p.instance_name != null && (
                        <span className="font-mono text-[11px] text-text-3">{String(p.instance_name)}</span>
                      )}
                      {p.credential_status != null && (
                        <span className={cn(
                          "rounded-md px-1.5 py-0.5 font-mono text-[10px]",
                          String(p.credential_status) === "configured" ? "bg-bull/12 text-bull" : "bg-warn/12 text-warn"
                        )}>
                          {String(p.credential_status)}
                        </span>
                      )}
                      <div className="ml-auto flex items-center gap-2">
                        <button
                          onClick={() => test.mutate(id)}
                          disabled={test.isPending}
                          className="rounded-lg p-1.5 text-text-3 transition-colors hover:bg-surface-hover hover:text-text"
                          title="测试连接"
                        >
                          <TestTube className="size-3.5" />
                        </button>
                        <button
                          onClick={() => toggle.mutate({ id, enable: !enabled })}
                          disabled={toggle.isPending}
                          className={cn(
                            "rounded-lg p-1.5 transition-colors",
                            enabled ? "text-bull hover:bg-bull/10" : "text-text-3 hover:bg-surface-hover hover:text-text"
                          )}
                          title={enabled ? "停用" : "启用"}
                        >
                          {enabled ? <Square className="size-3.5" /> : <Play className="size-3.5" />}
                        </button>
                        <button
                          onClick={() => setDeleteConfirm(id)}
                          className="rounded-lg p-1.5 text-text-3 transition-colors hover:bg-bear/10 hover:text-bear"
                          title="删除"
                        >
                          <Trash2 className="size-3.5" />
                        </button>
                        <span className={cn(
                          "rounded-md px-2 py-0.5 text-[11px] font-semibold",
                          !enabled ? "bg-surface text-text-3" : String(p.status) === "active" ? "bg-bull/12 text-bull" : "bg-warn/12 text-warn"
                        )}>
                          {!enabled ? "disabled" : String(p.status ?? "unknown")}
                        </span>
                      </div>
                    </div>
                  );
                })}
              </div>
            </VoltCard>
          </FadeIn>
        ))
      )}

      {/* 新增弹窗 */}
      {showAdd && <AddProviderDialog onClose={() => setShowAdd(false)} categories={DATA_SOURCE_CATEGORIES} defaultCategory="market_data" />}

      {/* 删除确认 */}
      {deleteConfirm != null && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/55 p-6" onClick={() => setDeleteConfirm(null)}>
          <div className="w-full max-w-[360px] rounded-[16px] border border-border bg-card p-6 shadow-modal" onClick={(e) => e.stopPropagation()}>
            <div className="text-[15px] font-bold text-text">确认删除</div>
            <div className="mt-2 text-[13px] text-text-2">删除后不可恢复,确定要删除该数据源吗?</div>
            <div className="mt-5 flex gap-2.5">
              <VoltButton variant="secondary" onClick={() => setDeleteConfirm(null)} className="flex-1">取消</VoltButton>
              <VoltButton
                variant="danger"
                onClick={() => {
                  del.mutate(deleteConfirm, { onSuccess: () => setDeleteConfirm(null) });
                }}
                disabled={del.isPending}
                className="flex-1"
              >
                {del.isPending ? "删除中…" : "删除"}
              </VoltButton>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}