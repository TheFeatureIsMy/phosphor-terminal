import { useEffect, useState } from "react";
import { Bell, Building2, Check, Database, MonitorSmartphone, Moon, Palette, Play, Plus, ScrollText, Server, Settings2, SlidersHorizontal, SunMedium, Trash2, Users, X } from "lucide-react";
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
import { api, getAuthToken } from "@/lib/api";
import { cn } from "@/lib/utils";

const GROUPS = [
  { id: "appearance", label: "外观", icon: Palette },
  { id: "tenant", label: "租户", icon: Building2 },
  { id: "execution", label: "执行运行时", icon: Server },
  { id: "members", label: "成员", icon: Users },
  { id: "sessions", label: "设备会话", icon: MonitorSmartphone },
  { id: "audit", label: "审计日志", icon: ScrollText },
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


/* ---------------- 租户 ---------------- */

type TenantInfo = { id: number; name: string; slug: string; role: string; plan: string };
type MeInfo = { is_superuser: boolean };
type SubscriptionInfo = { plan: string; status: string; current_period_end: string | null };
type UsageInfo = {
  plan: string;
  limits: { members: number; strategies: number; audit_days: number };
  usage: { members: number; strategies: number; audit_logs: number; active_sessions: number };
  warnings: { resource: string; used: number; limit: number }[];
};

const PLAN_LIMITS: Record<string, { members: number; strategies: number; auditDays: number }> = {
  free: { members: 5, strategies: 20, auditDays: 90 },
  pro: { members: 25, strategies: 200, auditDays: 365 },
  enterprise: { members: 200, strategies: 2000, auditDays: 1095 },
};

function TenantSection() {
  const [tenant, setTenant] = useState<TenantInfo | null>(null);
  const [isSuperuser, setIsSuperuser] = useState(false);
  const [nextPlan, setNextPlan] = useState("free");
  const [planMessage, setPlanMessage] = useState("");
  const [usage, setUsage] = useState<UsageInfo | null>(null);
  const [subscription, setSubscription] = useState<SubscriptionInfo | null>(null);
  const [error, setError] = useState("");

  useEffect(() => {
    api.get<TenantInfo>("/auth/tenant").then((value) => {
      setTenant(value);
      setNextPlan(value.plan);
    }).catch((err) => {
      setError(err instanceof Error ? err.message : "无法读取租户信息");
    });
    api.get<MeInfo>("/auth/me").then((me) => setIsSuperuser(me.is_superuser)).catch(() => {});
    api.get<UsageInfo>("/api/admin/tenant-usage").then(setUsage).catch(() => {});
    api.get<SubscriptionInfo>("/api/admin/tenant-subscription").then(setSubscription).catch(() => {});
  }, []);

  async function updatePlan() {
    setPlanMessage("");
    try {
      const updated = await api.put<TenantInfo>("/api/admin/tenant-plan", { plan: nextPlan });
      setTenant((current) => current ? { ...current, plan: updated.plan } : current);
      setPlanMessage("套餐已更新");
    } catch (err) {
      setPlanMessage(err instanceof Error ? err.message : "更新失败");
    }
  }

  return (
    <VoltCard className="p-[22px]">
      <div className="font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-2">
        当前租户
      </div>
      {error ? (
        <p className="mt-3 text-[12px] text-bear">{error}</p>
      ) : tenant ? (
        <>
        <dl className="mt-4 grid grid-cols-2 gap-3 text-[13px]">
          <div className="rounded-[10px] border border-border bg-surface p-3">
            <dt className="text-[11px] text-text-3">名称</dt>
            <dd className="mt-1 font-medium text-text">{tenant.name}</dd>
          </div>
          <div className="rounded-[10px] border border-border bg-surface p-3">
            <dt className="text-[11px] text-text-3">标识</dt>
            <dd className="mt-1 font-mono text-[12px] text-text">{tenant.slug}</dd>
          </div>
          <div className="rounded-[10px] border border-border bg-surface p-3">
            <dt className="text-[11px] text-text-3">角色</dt>
            <dd className="mt-1 uppercase tracking-wide text-accent-text">{tenant.role}</dd>
          </div>
          <div className="rounded-[10px] border border-border bg-surface p-3">
            <dt className="text-[11px] text-text-3">租户 ID</dt>
            <dd className="mt-1 font-mono text-[12px] text-text">{tenant.id}</dd>
          </div>
          <div className="rounded-[10px] border border-border bg-surface p-3">
            <dt className="text-[11px] text-text-3">订阅状态</dt>
            <dd className="mt-1 font-mono text-[12px] text-text">
              {subscription?.status ?? "none"}
              {subscription?.current_period_end
                ? ` · 至 ${subscription.current_period_end.slice(0, 10)}`
                : ""}
            </dd>
          </div>
          <div className="rounded-[10px] border border-border bg-surface p-3">
            <dt className="text-[11px] text-text-3">套餐</dt>
            <dd className="mt-1 uppercase tracking-wide text-accent-text">{tenant.plan}</dd>
          </div>
          <div className="rounded-[10px] border border-border bg-surface p-3">
            <dt className="text-[11px] text-text-3">配额</dt>
            <dd className="mt-1 font-mono text-[12px] text-text">
              {PLAN_LIMITS[tenant.plan]?.members ?? "—"} 成员 / {PLAN_LIMITS[tenant.plan]?.strategies ?? "—"} 策略
              {" · "}审计 {PLAN_LIMITS[tenant.plan]?.auditDays ?? "—"} 天
            </dd>
          </div>
        </dl>
        {usage && (
          <div className="mt-4 grid grid-cols-2 gap-3 text-[12px]">
            <div className="rounded-[10px] border border-border bg-surface p-3">
              <div className="text-[11px] text-text-3">成员用量</div>
              <div className={cn("mt-1 font-mono", usage.warnings.some((w) => w.resource === "members") ? "text-bear" : "text-text")}>
                {usage.usage.members} / {usage.limits.members}
                {usage.warnings.some((w) => w.resource === "members") && " · 接近上限"}
              </div>
            </div>
            <div className="rounded-[10px] border border-border bg-surface p-3">
              <div className="text-[11px] text-text-3">策略用量</div>
              <div className={cn("mt-1 font-mono", usage.warnings.some((w) => w.resource === "strategies") ? "text-bear" : "text-text")}>
                {usage.usage.strategies} / {usage.limits.strategies}
                {usage.warnings.some((w) => w.resource === "strategies") && " · 接近上限"}
              </div>
            </div>
            <div className="rounded-[10px] border border-border bg-surface p-3">
              <div className="text-[11px] text-text-3">审计条数</div>
              <div className="mt-1 font-mono text-text">{usage.usage.audit_logs}</div>
            </div>
            <div className="rounded-[10px] border border-border bg-surface p-3">
              <div className="text-[11px] text-text-3">活跃会话</div>
              <div className="mt-1 font-mono text-text">{usage.usage.active_sessions}</div>
            </div>
          </div>
        )}
        {isSuperuser && (
          <div className="mt-4 flex items-center gap-2 border-t border-border pt-4">
            <select
              value={nextPlan}
              onChange={(e) => setNextPlan(e.target.value)}
              className="rounded-[8px] border border-border bg-surface px-3 py-2 text-[12px] text-text"
            >
              <option value="free">free</option>
              <option value="pro">pro</option>
              <option value="enterprise">enterprise</option>
            </select>
            <button
              onClick={updatePlan}
              className="rounded-[8px] border border-accent-text/40 bg-accent-soft px-3 py-2 text-[12px] font-semibold text-accent-text"
            >
              更新套餐
            </button>
            {planMessage && <span className="text-[12px] text-text-2">{planMessage}</span>}
          </div>
        )}
        </>
      ) : (
        <p className="mt-3 text-[12px] text-text-3">正在加载租户信息…</p>
      )}
    </VoltCard>
  );
}


/* ---------------- 执行运行时 ---------------- */

type ExecutionProfile = {
  mode: "disabled" | "dedicated";
  freqtrade_url: string | null;
  api_username: string | null;
  has_credentials: boolean;
  has_exchange_credentials: boolean;
  enabled: boolean;
  max_open_trades: number;
  runtime_status: string;
  last_health_at: string | null;
  last_error: string | null;
};

function ExecutionRuntimeSection() {
  const [profile, setProfile] = useState<ExecutionProfile | null>(null);
  const [mode, setMode] = useState<"disabled" | "dedicated">("disabled");
  const [url, setUrl] = useState("");
  const [enabled, setEnabled] = useState(false);
  const [maxTrades, setMaxTrades] = useState(2);
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [message, setMessage] = useState("");
  const [health, setHealth] = useState<string>("");

  useEffect(() => {
    api.get<ExecutionProfile>("/api/admin/execution-profile").then((p) => {
      setProfile(p);
      setMode(p.mode);
      setUrl(p.freqtrade_url ?? "");
      setEnabled(p.enabled);
      setMaxTrades(p.max_open_trades);
      setUsername(p.api_username ?? "");
    }).catch((err) => setMessage(err instanceof Error ? err.message : "无法读取执行配置"));
  }, []);

  async function save() {
    setMessage("");
    try {
      const body: Record<string, unknown> = {
        mode, freqtrade_url: url || null, enabled, max_open_trades: maxTrades,
        api_username: username || null,
      };
      if (password) body.api_password = password;
      const p = await api.put<ExecutionProfile>("/api/admin/execution-profile", body);
      setProfile(p);
      setPassword("");
      setMessage("已保存");
    } catch (err) {
      setMessage(err instanceof Error ? err.message : "保存失败");
    }
  }

  async function checkHealth() {
    setHealth("检查中…");
    try {
      const h = await api.get<{ configured: boolean; reachable: boolean }>(
        "/api/admin/execution-profile/health",
      );
      setHealth(h.configured ? (h.reachable ? "运行时可达" : "运行时不可达") : "未配置");
    } catch (err) {
      setHealth(err instanceof Error ? err.message : "健康检查失败");
    }
  }

  return (
    <VoltCard className="p-[22px]">
      <div className="font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-2">
        租户执行运行时
      </div>
      <div className="mt-4 grid grid-cols-2 gap-3">
        <label className="text-[12px] text-text-2">
          模式
          <select
            value={mode}
            onChange={(e) => setMode(e.target.value as "disabled" | "dedicated")}
            className="mt-1 w-full rounded-[8px] border border-border bg-surface px-3 py-2 text-[13px] text-text"
          >
            <option value="disabled">disabled</option>
            <option value="dedicated">dedicated</option>
          </select>
        </label>
        <label className="text-[12px] text-text-2">
          Freqtrade URL
          <input
            value={url}
            onChange={(e) => setUrl(e.target.value)}
            placeholder="http://alphaloop-ft-42:8080"
            className="mt-1 w-full rounded-[8px] border border-border bg-surface px-3 py-2 font-mono text-[12px] text-text"
          />
        </label>
        <label className="text-[12px] text-text-2">
          API 用户名
          <input
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            className="mt-1 w-full rounded-[8px] border border-border bg-surface px-3 py-2 text-[13px] text-text"
          />
        </label>
        <label className="text-[12px] text-text-2">
          API 密码 {profile?.has_credentials ? "（已配置，留空不修改）" : ""}
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className="mt-1 w-full rounded-[8px] border border-border bg-surface px-3 py-2 text-[13px] text-text"
          />
        </label>
        <label className="text-[12px] text-text-2">
          最大同时持仓
          <input
            type="number"
            min={1}
            value={maxTrades}
            onChange={(e) => setMaxTrades(Number(e.target.value))}
            className="mt-1 w-full rounded-[8px] border border-border bg-surface px-3 py-2 text-[13px] text-text"
          />
        </label>
        <label className="flex items-center gap-2 self-end text-[12px] text-text-2">
          <input type="checkbox" checked={enabled} onChange={(e) => setEnabled(e.target.checked)} />
          启用
        </label>
      </div>
      <div className="mt-4 flex items-center gap-2">
        <VoltButton onClick={save}>保存</VoltButton>
        <VoltButton variant="secondary" onClick={checkHealth}>健康检查</VoltButton>
      </div>
      {message && <p className="mt-3 text-[12px] text-text-2">{message}</p>}
      {health && <p className="mt-1 text-[12px] text-accent-text">{health}</p>}
      {profile?.has_exchange_credentials && (
        <p className="mt-2 text-[11px] text-text-3">交易所 key/secret 已配置。</p>
      )}
      {profile && (
        <div className="mt-3 flex flex-wrap gap-4 text-[11px] text-text-3">
          <span>
            运行时状态：
            <span className="ml-1 font-mono text-text-2">{profile.runtime_status}</span>
          </span>
          <span>
            最后检查：{profile.last_health_at ?? "—"}
          </span>
          {profile.last_error && <span className="text-bear">{profile.last_error}</span>}
        </div>
      )}
    </VoltCard>
  );
}


/* ---------------- 成员 ---------------- */

type Member = {
  user_id: number;
  username: string;
  email: string;
  role: "owner" | "admin" | "trader" | "viewer";
  is_active: boolean;
};

const ROLES: Member["role"][] = ["owner", "admin", "trader", "viewer"];

function MembersSection() {
  const [members, setMembers] = useState<Member[]>([]);
  const [username, setUsername] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [role, setRole] = useState<Member["role"]>("viewer");
  const [message, setMessage] = useState("");
  const [inviteEmail, setInviteEmail] = useState("");
  const [inviteRole, setInviteRole] = useState<Member["role"]>("viewer");
  const [inviteLink, setInviteLink] = useState("");
  const [inviteSent, setInviteSent] = useState(false);
  const [inviteMessage, setInviteMessage] = useState("");

  async function createInvite() {
    setInviteMessage("");
    setInviteLink("");
    try {
      const res = await api.post<{ invite_link: string; email_sent: boolean }>("/auth/invites", {
        email: inviteEmail, role: inviteRole,
      });
      setInviteLink(res.invite_link);
      setInviteSent(res.email_sent);
      setInviteEmail("");
      setInviteMessage(res.email_sent ? "邀请已发送（链接仍可复制）。" : "邀请已创建，请把链接发给对方（仅显示一次）。");
    } catch (err) {
      setInviteMessage(err instanceof Error ? err.message : "创建邀请失败");
    }
  }

  async function load() {
    try {
      setMembers(await api.get<Member[]>("/auth/members"));
    } catch (err) {
      setMessage(err instanceof Error ? err.message : "需要租户 owner/admin 权限");
    }
  }

  useEffect(() => { load(); }, []);

  async function add() {
    setMessage("");
    try {
      await api.post("/auth/members", { username, email, password, role });
      setUsername(""); setEmail(""); setPassword(""); setRole("viewer");
      await load();
      setMessage("已添加");
    } catch (err) {
      setMessage(err instanceof Error ? err.message : "添加失败");
    }
  }

  async function changeRole(userId: number, next: Member["role"]) {
    try {
      await api.patch(`/auth/members/${userId}`, { role: next });
      await load();
    } catch (err) {
      setMessage(err instanceof Error ? err.message : "修改角色失败");
    }
  }

  async function remove(userId: number) {
    try {
      await api.del(`/auth/members/${userId}`);
      await load();
    } catch (err) {
      setMessage(err instanceof Error ? err.message : "移除失败");
    }
  }

  return (
    <VoltCard className="p-[22px]">
      <div className="font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-2">
        租户成员
      </div>
      <div className="mt-4 space-y-2">
        {members.map((m) => (
          <div key={m.user_id} className="flex items-center gap-3 rounded-[8px] border border-border bg-surface px-3 py-2">
            <div className="min-w-0 flex-1">
              <div className="text-[13px] text-text">{m.username}</div>
              <div className="font-mono text-[10px] text-text-3">{m.email}</div>
            </div>
            <select
              value={m.role}
              onChange={(e) => changeRole(m.user_id, e.target.value as Member["role"])}
              className="rounded-[6px] border border-border bg-bg px-2 py-1 text-[11px] text-text"
            >
              {ROLES.map((r) => <option key={r} value={r}>{r}</option>)}
            </select>
            <button
              onClick={() => remove(m.user_id)}
              className="text-bear hover:opacity-70"
              aria-label={`移除 ${m.username}`}
            >
              <Trash2 className="size-4" />
            </button>
          </div>
        ))}
      </div>

      <div className="mt-4 grid grid-cols-2 gap-2">
        <input placeholder="用户名" value={username} onChange={(e) => setUsername(e.target.value)}
          className="rounded-[8px] border border-border bg-surface px-3 py-2 text-[13px] text-text" />
        <input placeholder="邮箱" value={email} onChange={(e) => setEmail(e.target.value)}
          className="rounded-[8px] border border-border bg-surface px-3 py-2 text-[13px] text-text" />
        <input placeholder="初始密码" type="password" value={password} onChange={(e) => setPassword(e.target.value)}
          className="rounded-[8px] border border-border bg-surface px-3 py-2 text-[13px] text-text" />
        <select value={role} onChange={(e) => setRole(e.target.value as Member["role"])}
          className="rounded-[8px] border border-border bg-surface px-3 py-2 text-[13px] text-text">
          {ROLES.map((r) => <option key={r} value={r}>{r}</option>)}
        </select>
      </div>
      <div className="mt-3">
        <VoltButton onClick={add} icon={<Plus className="size-3.5" />}>添加成员</VoltButton>
      </div>
      {message && <p className="mt-3 text-[12px] text-text-2">{message}</p>}

      <div className="mt-6 border-t border-border pt-4">
        <div className="font-mono text-[10px] uppercase tracking-[0.08em] text-text-3">邀请链接</div>
        <div className="mt-2 flex gap-2">
          <input placeholder="对方邮箱" value={inviteEmail} onChange={(e) => setInviteEmail(e.target.value)}
            className="min-w-0 flex-1 rounded-[8px] border border-border bg-surface px-3 py-2 text-[13px] text-text" />
          <select value={inviteRole} onChange={(e) => setInviteRole(e.target.value as Member["role"])}
            className="rounded-[8px] border border-border bg-surface px-2 py-2 text-[12px] text-text">
            {ROLES.map((r) => <option key={r} value={r}>{r}</option>)}
          </select>
          <VoltButton variant="secondary" onClick={createInvite} disabled={!inviteEmail}>
            创建邀请
          </VoltButton>
        </div>
        {inviteMessage && <p className="mt-2 text-[12px] text-text-2">{inviteMessage}</p>}
        {inviteLink && (
          <div className="mt-2 flex items-center gap-2 rounded-[8px] border border-border bg-surface px-3 py-2">
            <code className="min-w-0 flex-1 truncate font-mono text-[11px] text-text-2">
              {inviteLink}
            </code>
            <button
              onClick={() => navigator.clipboard?.writeText(inviteLink)}
              className="text-[11px] text-accent-text hover:opacity-70"
            >
              复制链接
            </button>
          </div>
        )}
      </div>
    </VoltCard>
  );
}


/* ---------------- 设备会话 ---------------- */

type DeviceSession = {
  id: string;
  device_name: string | null;
  ip_address: string | null;
  created_at: string;
  last_seen_at: string;
  revoked: boolean;
};

function currentSessionId(): string | null {
  const token = getAuthToken();
  if (!token) return null;
  try {
    const part = token.split(".")[1].replace(/-/g, "+").replace(/_/g, "/");
    const payload = JSON.parse(atob(part));
    return payload.sid ?? null;
  } catch {
    return null;
  }
}

function SessionsSection() {
  const [sessions, setSessions] = useState<DeviceSession[]>([]);
  const [current, setCurrent] = useState<string | null>(null);
  const [message, setMessage] = useState("");

  async function load() {
    setCurrent(currentSessionId());
    try {
      setSessions(await api.get<DeviceSession[]>("/auth/sessions"));
    } catch (err) {
      setMessage(err instanceof Error ? err.message : "无法读取会话");
    }
  }

  useEffect(() => { load(); }, []);

  async function revoke(id: string) {
    try {
      await api.post(`/auth/sessions/${id}/revoke`);
      await load();
      setMessage("已撤销");
    } catch (err) {
      setMessage(err instanceof Error ? err.message : "撤销失败");
    }
  }

  return (
    <VoltCard className="p-[22px]">
      <div className="font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-2">
        登录设备
      </div>
      <div className="mt-4 space-y-2">
        {sessions.length === 0 && (
          <p className="text-[12px] text-text-3">暂无会话</p>
        )}
        {sessions.map((s) => (
          <div key={s.id} className="flex items-center gap-3 rounded-[8px] border border-border bg-surface px-3 py-2">
            <div className="min-w-0 flex-1">
              <div className="flex items-center gap-2 text-[13px] text-text">
                {s.device_name || "未知设备"}
                {s.id === current && (
                  <span className="rounded bg-accent-soft px-1.5 py-0.5 text-[10px] text-accent-text">当前</span>
                )}
                {s.revoked && (
                  <span className="rounded bg-bear/10 px-1.5 py-0.5 text-[10px] text-bear">已撤销</span>
                )}
              </div>
              <div className="font-mono text-[10px] text-text-3">
                {s.ip_address || "—"} · {new Date(s.created_at).toLocaleString()}
              </div>
            </div>
            {!s.revoked && (
              <button
                onClick={() => revoke(s.id)}
                className="text-bear hover:opacity-70"
                aria-label="撤销会话"
              >
                <X className="size-4" />
              </button>
            )}
          </div>
        ))}
      </div>
      {message && <p className="mt-3 text-[12px] text-text-2">{message}</p>}
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


/* ---------------- 审计日志 ---------------- */

type AuditEntry = {
  id: number;
  action: string;
  actor_user_id: number | null;
  detail: Record<string, unknown>;
  created_at: string | null;
};

const AUDIT_LABELS: Record<string, string> = {
  "plan.update": "套餐变更",
  "member.add": "添加成员",
  "member.role": "修改角色",
  "member.remove": "移除成员",
  "invite.create": "创建邀请",
  "invite.accept": "接受邀请",
  "profile.update": "执行配置",
  "runtime.provision": "启动运行时",
  "runtime.stop": "停止运行时",
  "quota.warning": "配额预警",
};

function AuditSection() {
  const [rows, setRows] = useState<AuditEntry[]>([]);
  const [error, setError] = useState("");
  const [actionFilter, setActionFilter] = useState("");
  const [archives, setArchives] = useState<{ name: string; size: number }[]>([]);

  async function load() {
    setError("");
    try {
      const query = actionFilter ? `&action=${encodeURIComponent(actionFilter)}` : "";
      setRows(await api.get<AuditEntry[]>(`/api/admin/tenant-audit?limit=50${query}`));
    } catch (err) {
      setError(err instanceof Error ? err.message : "无法读取审计日志");
    }
  }

  useEffect(() => { void load(); }, [actionFilter]);
  useEffect(() => {
    api.get<{ name: string; size: number }[]>("/api/admin/tenant-audit/archives")
      .then(setArchives)
      .catch(() => setArchives([]));
  }, []);

  async function downloadArchive(name: string) {
    const token = getAuthToken();
    const res = await fetch(`/api/admin/tenant-audit/archives/${encodeURIComponent(name)}`, {
      headers: token ? { Authorization: `Bearer ${token}` } : {},
    });
    if (!res.ok) {
      setError("下载归档失败");
      return;
    }
    const blob = await res.blob();
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement("a");
    anchor.href = url;
    anchor.download = name;
    anchor.click();
    URL.revokeObjectURL(url);
  }

  async function exportCsv() {
    const query = actionFilter ? `&action=${encodeURIComponent(actionFilter)}` : "";
    const token = getAuthToken();
    const res = await fetch(`/api/admin/tenant-audit/export?limit=50${query}`, {
      headers: token ? { Authorization: `Bearer ${token}` } : {},
    });
    if (!res.ok) {
      setError("导出失败");
      return;
    }
    const blob = await res.blob();
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement("a");
    anchor.href = url;
    anchor.download = "tenant-audit.csv";
    anchor.click();
    URL.revokeObjectURL(url);
  }

  return (
    <VoltCard className="overflow-hidden">
      <div className="flex items-center justify-between border-b border-border px-5 py-3.5">
        <div className="font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-2">
          审计日志 · {rows.length}
        </div>
        <div className="flex items-center gap-3">
          <select
            value={actionFilter}
            onChange={(e) => setActionFilter(e.target.value)}
            className="rounded-[6px] border border-border bg-bg px-2 py-1 text-[11px] text-text"
          >
            <option value="">全部动作</option>
            {Object.entries(AUDIT_LABELS).map(([action, label]) => (
              <option key={action} value={action}>{label}</option>
            ))}
          </select>
          <button onClick={() => void load()} className="text-[12px] text-accent-text">刷新</button>
          <button onClick={() => void exportCsv()} className="text-[12px] text-accent-text">导出 CSV</button>
        </div>
      </div>
      {error ? (
        <p className="p-5 text-[12px] text-bear">{error}</p>
      ) : rows.length === 0 ? (
        <EmptyState compact icon={<ScrollText />} title="暂无审计记录" description="租户管理动作会记录在这里。" />
      ) : (
        <div className="divide-y divide-border/50">
          {rows.map((row) => (
            <div key={row.id} className="flex items-start gap-4 px-5 py-3">
              <div className="min-w-0 flex-1">
                <div className="text-[13px] text-text">{AUDIT_LABELS[row.action] ?? row.action}</div>
                <div className="mt-1 font-mono text-[11px] text-text-3">
                  actor #{row.actor_user_id ?? "—"} · {JSON.stringify(row.detail)}
                </div>
              </div>
              <div className="shrink-0 font-mono text-[11px] text-text-3">
                {row.created_at ? row.created_at.replace("T", " ").slice(0, 19) : "—"}
              </div>
            </div>
          ))}
        </div>
      )}
      <div className="border-t border-border px-5 py-3">
        <div className="font-mono text-[10px] uppercase tracking-[0.08em] text-text-3">归档</div>
        {archives.length === 0 ? (
          <div className="mt-2 text-[12px] text-text-3">暂无归档</div>
        ) : (
          <div className="mt-2 flex flex-wrap gap-2">
            {archives.map((item) => (
              <button
                key={item.name}
                onClick={() => void downloadArchive(item.name)}
                className="rounded-[6px] border border-border bg-surface px-2.5 py-1 font-mono text-[11px] text-accent-text hover:border-border-hover"
              >
                {item.name} · {Math.round(item.size / 1024)} KB
              </button>
            ))}
          </div>
        )}
      </div>
    </VoltCard>
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
            {group === "tenant" && <TenantSection />}
            {group === "execution" && <ExecutionRuntimeSection />}
            {group === "members" && <MembersSection />}
            {group === "sessions" && <SessionsSection />}
            {group === "audit" && <AuditSection />}
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
