/** 策略/版本状态 → 语义色（策略域共享；运行域/候选域各有自己的映射，勿混用） */
export function statusTone(s: string): string {
  const k = s.toLowerCase();
  if (["active", "running", "live_small", "paper_passed", "ready_for_live", "completed"].includes(k)) return "var(--bull)";
  if (["paused", "draft", "pending", "paper_running", "validated", "backtested"].includes(k)) return "var(--warn)";
  if (["failed", "error", "rejected", "archived"].includes(k)) return "var(--bear)";
  return "var(--text-3)";
}
