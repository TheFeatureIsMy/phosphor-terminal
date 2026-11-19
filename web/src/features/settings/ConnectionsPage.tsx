import { useMemo, useState } from "react";
import { useSearchParams } from "react-router-dom";
import { ExternalLink } from "lucide-react";
import { PageHeader } from "@/components/shell/PageHeader";
import {
  useAdminProviders,
  useCreateProvider,
  useDeleteProvider,
  useTestProvider,
  useToggleProvider,
  useUpdateProvider,
} from "@/lib/hooks";
import {
  ALL_PROVIDER_SCHEMAS,
  CATEGORY_LABELS,
  CONNECTION_GROUPS,
  CONNECTION_META,
  type FieldDef,
  type ProviderSchema,
} from "@/lib/provider-schemas";
import type { AdminProvider } from "@/lib/types";
import { cn } from "@/lib/utils";

const FALLBACK_PURPOSE: Record<string, string> = {
  cex: "交易所账户。只开交易，不要开提现。",
  dex: "链上钱包私钥。拿到私钥就能动这笔钱。",
  market_data: "公开行情，不需要密钥。",
  social: "社交数据的读取权限。",
  news: "新闻接口密钥。",
  onchain: "链上数据接口密钥。",
  notification: "告警发到这里。",
  llm: "研究用的模型。密钥只在保存时提交。",
};

export default function ConnectionsPage() {
  const { data: providers, isError } = useAdminProviders();
  const [params, setParams] = useSearchParams();
  const requested = params.get("group");
  const group = CONNECTION_GROUPS.some((g) => g.id === requested)
    ? requested!
    : CONNECTION_GROUPS[0].id;
  const [query, setQuery] = useState("");
  const rows = providers ?? [];

  const visible = useMemo(() => {
    const spec = CONNECTION_GROUPS.find((g) => g.id === group)!;
    const q = query.trim().toLowerCase();
    return ALL_PROVIDER_SCHEMAS.filter((schema) => {
      if (!spec.categories.includes(schema.category)) return false;
      if (!q) return true;
      return `${schema.label} ${schema.name}`.toLowerCase().includes(q);
    }).sort(
      (a, b) => spec.categories.indexOf(a.category) - spec.categories.indexOf(b.category),
    );
  }, [group, query]);

  return (
    <div className="mx-auto w-full max-w-[980px] px-7 py-6">
      <PageHeader
        eyebrow="CONNECTIONS"
        title="连接"
        subtitle="外部账号只在这一页填写。本机进程看服务管理，主题和告警看系统设置。密钥保存后不再显示。"
      />

      <div className="mt-6 flex flex-wrap items-center gap-2">
        {CONNECTION_GROUPS.map((item) => {
          const count = ALL_PROVIDER_SCHEMAS.filter(
            (schema) => item.categories.includes(schema.category) && rowsFor(schema, rows).length > 0,
          ).length;
          const total = ALL_PROVIDER_SCHEMAS.filter((schema) => item.categories.includes(schema.category)).length;
          const active = item.id === group;
          return (
            <button
              key={item.id}
              type="button"
              onClick={() => {
                setQuery("");
                setParams({ group: item.id }, { replace: true });
              }}
              className={cn(
                "rounded border px-3 py-1.5 font-mono text-[12px]",
                active ? "border-accent bg-accent text-black" : "border-border text-text-2",
              )}
            >
              {item.label}
              <span className={cn("ml-2", active ? "text-black/70" : "text-text-3")}>
                {count}/{total}
              </span>
            </button>
          );
        })}
        <input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="筛选名称"
          className="ml-auto w-[180px] rounded border border-border bg-bg px-3 py-1.5 font-mono text-[12px] text-text outline-none focus:border-accent-text"
        />
      </div>

      {isError && (
        <p className="mt-4 font-mono text-[12px] text-text-2">
          已保存的连接没读到。目录仍可查看，保存需要后端在跑。
        </p>
      )}

      <div className="mt-4 space-y-3">
        {visible.length === 0 && (
          <p className="font-mono text-[12px] text-text-3">这一组没有匹配的连接。</p>
        )}
        {visible.map((schema) => (
          <ConnectionCard key={`${schema.category}/${schema.name}`} schema={schema} providers={rows} />
        ))}
      </div>
    </div>
  );
}

function ConnectionCard({ schema, providers }: { schema: ProviderSchema; providers: AdminProvider[] }) {
  const create = useCreateProvider();
  const update = useUpdateProvider();
  const remove = useDeleteProvider();
  const test = useTestProvider();
  const toggle = useToggleProvider();
  const matches = rowsFor(schema, providers);
  const [open, setOpen] = useState(false);
  const [instanceDraft, setInstanceDraft] = useState<string | null>(null);
  const [mode, setMode] = useState<"demo" | "live" | null>(null);
  const [values, setValues] = useState<Record<string, string>>({});
  const [message, setMessage] = useState("");
  const [confirmDelete, setConfirmDelete] = useState(false);

  const instanceName = instanceDraft ?? String(matches[0]?.instance_name ?? schema.name);
  const resolvedName = instanceName.trim() || schema.name;
  const existing = schema.category === "llm"
    ? matches.find((row) => String(row.instance_name) === resolvedName)
    : matches[0];
  const prior = configOf(existing);
  const modeValue: "demo" | "live" = mode ?? (prior.mode === "live" ? "live" : "demo");
  const binance = schema.category === "cex" && schema.name === "binance";
  const meta = CONNECTION_META[`${schema.category}/${schema.name}`];
  const href = binance
    ? modeValue === "demo"
      ? "https://demo.binance.com/en/my/settings/api-management"
      : "https://www.binance.com/zh-CN/my/settings/api-management"
    : meta?.href;
  const hrefLabel = binance
    ? modeValue === "demo"
      ? "去模拟盘 API 管理"
      : "去主站创建密钥"
    : meta?.hrefLabel;
  const purpose = meta?.purpose ?? FALLBACK_PURPOSE[schema.category] ?? "保存后供对应模块读取。";
  const badge = statusBadge(schema, existing, matches.length);
  const chip = summaryChip(schema, existing);
  const busy = create.isPending || update.isPending || remove.isPending || test.isPending || toggle.isPending;

  function openForm() {
    const next: Record<string, string> = {};
    for (const field of schema.configFields) {
      const current = prior[field.key];
      next[field.key] = current != null && current !== "" ? String(current) : (field.defaultValue ?? "");
    }
    setValues(next);
    setOpen(true);
    setMessage("");
    setConfirmDelete(false);
  }

  async function save() {
    const config = buildConfig(schema, values, prior, binance ? modeValue : null);
    const creds = buildCredentials(schema, values);
    const missingCreds = schema.credentialFields.filter((field) => field.required && !creds?.[field.key]);
    const missingConfig = schema.configFields.filter(
      (field) => field.required && field.type !== "boolean" && (config[field.key] == null || config[field.key] === ""),
    );
    if (missingConfig.length > 0) {
      setMessage(`先填写${missingConfig.map((field) => field.label).join("、")}。`);
      return;
    }
    if (!existing && missingCreds.length > 0) {
      setMessage(`先填写${missingCreds.map((field) => field.label).join("、")}。`);
      return;
    }
    if (existing && creds && missingCreds.length > 0) {
      setMessage("更换密钥时，必填项要一起填。留空则保持原密钥。");
      return;
    }
    const body: Record<string, unknown> = {
      category: schema.category,
      provider_name: schema.name,
      enabled: true,
      config,
    };
    if (schema.category === "llm") body.instance_name = resolvedName;
    if (creds) body.credentials = creds;
    try {
      if (existing?.id != null) {
        await update.mutateAsync({ id: Number(existing.id), ...body });
      } else {
        await create.mutateAsync(body);
      }
      setValues((prev) => {
        const cleared = { ...prev };
        for (const field of schema.credentialFields) delete cleared[field.key];
        return cleared;
      });
      setOpen(false);
      setMessage("已保存。密钥不会再显示。");
    } catch (err) {
      setMessage(explain(err));
    }
  }

  async function runTest() {
    if (existing?.id == null) return;
    try {
      const result = await test.mutateAsync(Number(existing.id)) as {
        success?: boolean;
        error?: string | null;
        status?: string;
        latency_ms?: number | null;
      };
      setMessage(
        result.success
          ? `连接可用${result.latency_ms != null ? `，${result.latency_ms} ms` : ""}。`
          : `测试没通过：${result.error || result.status || "未知原因"}`,
      );
    } catch (err) {
      setMessage(explain(err));
    }
  }

  return (
    <article className="rounded-lg border border-border bg-surface px-4 py-4">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <div className="flex flex-wrap items-center gap-2">
            <h3 className="text-[15px] text-text">{schema.label}</h3>
            <span className="font-mono text-[10px] tracking-wide text-text-3">
              {CATEGORY_LABELS[schema.category] ?? schema.category}
            </span>
            <span className={cn("font-mono text-[10px] tracking-wide", badge.className)}>{badge.text}</span>
            {chip && (
              <span className="max-w-[280px] truncate rounded border border-border px-1.5 py-0.5 font-mono text-[10px] text-text-2">
                {chip}
              </span>
            )}
          </div>
          <p className="mt-1 max-w-[640px] text-[13px] leading-5 text-text-2">{purpose}</p>
          {existing?.last_error != null && String(existing.last_error) !== "" && (
            <p className="mt-1 font-mono text-[11px] text-bear">{String(existing.last_error)}</p>
          )}
        </div>
        <div className="flex flex-wrap gap-2">
          {href && hrefLabel && (
            <a
              href={href}
              target="_blank"
              rel="noreferrer"
              className="inline-flex items-center gap-1 rounded border border-border px-3 py-1.5 font-mono text-[12px] text-text-2"
            >
              {hrefLabel}
              <ExternalLink className="size-3" />
            </a>
          )}
          {existing?.id != null && (
            <button
              type="button"
              disabled={busy}
              onClick={() => void runTest()}
              className="rounded border border-border px-3 py-1.5 font-mono text-[12px] text-text-2 disabled:opacity-50"
            >
              测试
            </button>
          )}
          <button
            type="button"
            onClick={() => {
              if (open) {
                setOpen(false);
                setConfirmDelete(false);
                return;
              }
              openForm();
            }}
            className="rounded bg-accent px-3 py-1.5 font-mono text-[12px] text-black"
          >
            {existing ? "更换" : "填入"}
          </button>
        </div>
      </div>

      {open && (
        <div className="mt-4 grid gap-3 border-t border-border pt-4">
          {schema.category === "llm" && (
            <label className="block">
              <span className="font-mono text-[11px] text-text-3">实例名</span>
              <input
                value={instanceName}
                onChange={(e) => setInstanceDraft(e.target.value)}
                className="mt-1 w-full rounded border border-border bg-bg px-3 py-2 font-mono text-[13px] text-text outline-none focus:border-accent-text"
              />
              {matches.length > 1 && (
                <div className="mt-2 flex flex-wrap gap-2">
                  {matches.map((row) => (
                    <button
                      key={String(row.id)}
                      type="button"
                      onClick={() => setInstanceDraft(String(row.instance_name ?? resolvedName))}
                      className="rounded border border-border px-2 py-1 font-mono text-[11px] text-text-2"
                    >
                      {String(row.instance_name ?? schema.name)}
                    </button>
                  ))}
                </div>
              )}
            </label>
          )}
          {binance && (
            <div className="flex gap-2 font-mono text-[12px]">
              {(["demo", "live"] as const).map((id) => (
                <button
                  key={id}
                  type="button"
                  onClick={() => setMode(id)}
                  className={modeValue === id ? "text-accent-text" : "text-text-3"}
                >
                  {id === "demo" ? "Demo 模拟" : "主站实盘"}
                </button>
              ))}
            </div>
          )}
          {schema.configFields.filter((field) => !(binance && field.key === "base_url")).map((field) => (
            <FieldInput
              key={field.key}
              field={field}
              value={values[field.key] ?? ""}
              onChange={(value) => setValues((prev) => ({ ...prev, [field.key]: value }))}
            />
          ))}
          {schema.credentialFields.map((field) => (
            <FieldInput
              key={field.key}
              field={field}
              value={values[field.key] ?? ""}
              onChange={(value) => setValues((prev) => ({ ...prev, [field.key]: value }))}
            />
          ))}
          {existing && schema.credentialFields.length > 0 && (
            <p className="font-mono text-[11px] text-text-3">密钥留空则保持原值。更换时必填项要一起填。</p>
          )}
          <div className="flex flex-wrap items-center gap-2">
            <button
              type="button"
              disabled={busy}
              onClick={() => void save()}
              className="w-fit rounded bg-text px-3 py-1.5 font-mono text-[12px] text-bg disabled:opacity-50"
            >
              {busy ? "保存中" : "保存"}
            </button>
            {existing?.id != null && (
              <button
                type="button"
                disabled={busy}
                onClick={() => toggle.mutate({ id: Number(existing.id), enable: existing.enabled === false })}
                className="rounded border border-border px-3 py-1.5 font-mono text-[12px] text-text-2 disabled:opacity-50"
              >
                {existing.enabled === false ? "启用" : "停用"}
              </button>
            )}
            {existing?.id != null && !confirmDelete && (
              <button
                type="button"
                onClick={() => setConfirmDelete(true)}
                className="rounded border border-border px-3 py-1.5 font-mono text-[12px] text-text-3"
              >
                删除
              </button>
            )}
            {existing?.id != null && confirmDelete && (
              <button
                type="button"
                disabled={busy}
                onClick={async () => {
                  try {
                    await remove.mutateAsync(Number(existing.id));
                    setOpen(false);
                    setConfirmDelete(false);
                    setMessage("已删除。");
                  } catch (err) {
                    setMessage(explain(err));
                  }
                }}
                className="rounded border border-bear px-3 py-1.5 font-mono text-[12px] text-bear disabled:opacity-50"
              >
                确认删除
              </button>
            )}
          </div>
        </div>
      )}
      {message && <p className="mt-3 font-mono text-[12px] text-text-2">{message}</p>}
    </article>
  );
}

function FieldInput({
  field,
  value,
  onChange,
  secret,
}: {
  field: FieldDef;
  value: string;
  onChange: (value: string) => void;
  secret?: boolean;
}) {
  if (field.type === "boolean") {
    const on = value !== "false";
    return (
      <div className="flex items-center justify-between gap-3">
        <span className="font-mono text-[11px] text-text-3">{field.label}</span>
        <button
          type="button"
          onClick={() => onChange(on ? "false" : "true")}
          className={cn("font-mono text-[12px]", on ? "text-accent-text" : "text-text-3")}
        >
          {on ? "开" : "关"}
        </button>
      </div>
    );
  }
  return (
    <label className="block">
      <span className="font-mono text-[11px] text-text-3">{field.label}</span>
      <input
        type={secret || field.type === "password" ? "password" : field.type === "number" ? "number" : "text"}
        autoComplete="off"
        value={value}
        placeholder={field.placeholder ?? field.hint}
        onChange={(e) => onChange(e.target.value)}
        className="mt-1 w-full rounded border border-border bg-bg px-3 py-2 font-mono text-[13px] text-text outline-none focus:border-accent-text"
      />
    </label>
  );
}

function rowsFor(schema: ProviderSchema, providers: AdminProvider[]): AdminProvider[] {
  return providers.filter(
    (row) => String(row.category) === schema.category && String(row.provider_name) === schema.name,
  );
}

function configOf(row?: AdminProvider): Record<string, unknown> {
  return row?.config != null && typeof row.config === "object" ? (row.config as Record<string, unknown>) : {};
}

function statusBadge(schema: ProviderSchema, row: AdminProvider | undefined, matchCount: number) {
  if (!row) {
    return matchCount > 0
      ? { text: "新实例", className: "text-text-3" }
      : { text: "未配置", className: "text-text-3" };
  }
  if (row.enabled === false) return { text: "已停用", className: "text-text-3" };
  if (schema.credentialFields.length === 0 || row.credential_status === "configured") {
    return { text: "已配置", className: "text-bull" };
  }
  return { text: "未填密钥", className: "text-text-3" };
}

function summaryChip(schema: ProviderSchema, row?: AdminProvider): string | null {
  const config = configOf(row);
  if (schema.category === "cex" && schema.name === "binance" && row) {
    return config.mode === "live" ? "主站" : "Demo";
  }
  const raw = config.model ?? config.deployment ?? config.symbols ?? config.host;
  if (typeof raw !== "string" || raw.trim() === "") return null;
  return raw.length > 48 ? `${raw.slice(0, 48)}…` : raw;
}

function buildConfig(
  schema: ProviderSchema,
  values: Record<string, string>,
  prior: Record<string, unknown>,
  mode: "demo" | "live" | null,
): Record<string, unknown> {
  const config: Record<string, unknown> = {};
  for (const field of schema.configFields) {
    const raw = values[field.key];
    if (field.type === "boolean") {
      const source = raw != null && raw !== "" ? raw : field.defaultValue;
      config[field.key] = source !== "false";
      continue;
    }
    if (field.type === "number") {
      const text = raw?.trim();
      if (text) config[field.key] = Number(text);
      else if (typeof prior[field.key] === "number") config[field.key] = prior[field.key];
      else if (field.defaultValue) config[field.key] = Number(field.defaultValue);
      continue;
    }
    const text = raw?.trim();
    if (text) config[field.key] = text;
    else if (prior[field.key] != null && prior[field.key] !== "") config[field.key] = prior[field.key];
    else if (field.defaultValue) config[field.key] = field.defaultValue;
  }
  if (mode) {
    config.mode = mode;
    config.base_url = mode === "demo" ? "https://demo-api.binance.com/api" : "https://api.binance.com/api";
  }
  return config;
}

function buildCredentials(schema: ProviderSchema, values: Record<string, string>): Record<string, string> | null {
  const credentials: Record<string, string> = {};
  for (const field of schema.credentialFields) {
    const text = values[field.key]?.trim();
    if (text) credentials[field.key] = text;
  }
  return Object.keys(credentials).length > 0 ? credentials : null;
}

function explain(err: unknown): string {
  if (!(err instanceof Error)) return "保存失败";
  try {
    const body = JSON.parse(err.message) as { detail?: { code?: string; message?: string } | string };
    const detail = body.detail;
    if (typeof detail === "string") return detail;
    if (detail?.message) return detail.message;
    if (detail?.code === "unknown_provider") return "后端还没有这个连接。";
    if (detail?.code === "duplicate") return "已经有一份相同配置。";
    if (detail?.code) return detail.code;
  } catch {
    /* 后端返回的不是 JSON */
  }
  return err.message.slice(0, 180) || "保存失败";
}
