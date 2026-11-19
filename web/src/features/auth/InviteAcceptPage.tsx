import { useState } from "react";
import { ArrowUpRight, Loader2 } from "lucide-react";
import { api } from "@/lib/api";

/** Public page for accepting a tenant invite link (?invite_token=...). */
export function InviteAcceptPage({ token, onDone }: { token: string; onDone: () => void }) {
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const [done, setDone] = useState(false);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (busy) return;
    setBusy(true);
    setError("");
    try {
      await api.post("/auth/invites/accept", { token, username, password });
      setDone(true);
    } catch (err) {
      setError(err instanceof Error ? err.message : "邀请无效或已过期");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="flex h-full items-center justify-center bg-bg px-6 text-text">
      <form onSubmit={submit} className="w-full max-w-[380px] rounded-[18px] border border-border bg-card p-7">
        <div className="mb-6 flex items-center gap-3">
          <span className="inline-flex size-10 items-center justify-center rounded-[10px] bg-accent">
            <ArrowUpRight className="text-on-accent" size={22} strokeWidth={3} />
          </span>
          <div>
            <div className="font-display text-[18px] font-black tracking-[0.06em]">ALPHALOOP</div>
            <div className="font-mono text-[10px] tracking-[0.25em] text-text-3">JOIN WORKSPACE</div>
          </div>
        </div>

        {done ? (
          <>
            <p className="mb-4 text-[13px] text-text-2">账号已创建，现在可以登录。</p>
            <button type="button" onClick={onDone}
              className="w-full rounded-[8px] bg-accent px-3 py-2 text-[13px] font-semibold text-on-accent">
              去登录
            </button>
          </>
        ) : (
          <>
            <label className="mb-1 block text-[12px] text-text-2" htmlFor="invite-username">用户名</label>
            <input id="invite-username" value={username} onChange={(e) => setUsername(e.target.value)}
              className="mb-4 w-full rounded-[8px] border border-border bg-surface px-3 py-2 text-[13px] outline-none focus:border-accent" />
            <label className="mb-1 block text-[12px] text-text-2" htmlFor="invite-password">设置密码</label>
            <input id="invite-password" type="password" value={password} onChange={(e) => setPassword(e.target.value)}
              className="mb-4 w-full rounded-[8px] border border-border bg-surface px-3 py-2 text-[13px] outline-none focus:border-accent" />
            {error && <div className="mb-3 text-[12px] text-bear">{error}</div>}
            <button type="submit" disabled={busy || !username || !password}
              className="flex w-full items-center justify-center gap-2 rounded-[8px] bg-accent px-3 py-2 text-[13px] font-semibold text-on-accent disabled:opacity-50">
              {busy && <Loader2 className="animate-spin" size={14} />}
              接受邀请
            </button>
          </>
        )}
      </form>
    </div>
  );
}
