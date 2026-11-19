import { useState } from "react";
import { ArrowUpRight, Loader2 } from "lucide-react";
import { login } from "@/lib/api";

/** Minimal login gate: the backend requires a Bearer token for every API call. */
export function LoginPage({ onSuccess }: { onSuccess: () => void }) {
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (busy) return;
    setBusy(true);
    setError("");
    try {
      await login(username.trim(), password);
      onSuccess();
    } catch (err) {
      setError(err instanceof Error ? err.message : "登录失败");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="flex h-full items-center justify-center bg-bg px-6 text-text">
      <form
        onSubmit={submit}
        className="w-full max-w-[380px] rounded-[18px] border border-border bg-card p-7"
      >
        <div className="mb-6 flex items-center gap-3">
          <span className="inline-flex size-10 items-center justify-center rounded-[10px] bg-accent">
            <ArrowUpRight className="text-on-accent" size={22} strokeWidth={3} />
          </span>
          <div>
            <div className="font-display text-[18px] font-black tracking-[0.06em]">ALPHALOOP</div>
            <div className="font-mono text-[10px] tracking-[0.25em] text-text-3">SECURE TERMINAL</div>
          </div>
        </div>

        <label className="mb-1 block text-[12px] text-text-2" htmlFor="username">用户名</label>
        <input
          id="username"
          autoComplete="username"
          value={username}
          onChange={(e) => setUsername(e.target.value)}
          className="mb-4 w-full rounded-[8px] border border-border bg-surface px-3 py-2 text-[13px] outline-none focus:border-accent"
        />

        <label className="mb-1 block text-[12px] text-text-2" htmlFor="password">密码</label>
        <input
          id="password"
          type="password"
          autoComplete="current-password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          className="mb-4 w-full rounded-[8px] border border-border bg-surface px-3 py-2 text-[13px] outline-none focus:border-accent"
        />

        {error && <div className="mb-3 text-[12px] text-bear">{error}</div>}

        <button
          type="submit"
          disabled={busy || !username || !password}
          className="flex w-full items-center justify-center gap-2 rounded-[8px] bg-accent px-3 py-2 text-[13px] font-semibold text-on-accent disabled:opacity-50"
        >
          {busy && <Loader2 className="animate-spin" size={14} />}
          登录
        </button>

        <p className="mt-4 font-mono text-[10px] leading-5 text-text-3">
          后端开启了鉴权。没有账号时先调用 POST /auth/register 创建。
        </p>
      </form>
    </div>
  );
}
