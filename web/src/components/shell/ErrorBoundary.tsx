import { Component, type ReactNode } from "react";
import { ShieldAlert } from "lucide-react";

/**
 * 全局渲染兜底:任何页面组件抛错时显示错误卡片而不是黑屏,
 * 点击可重试(重置错误状态)。
 */
export class ErrorBoundary extends Component<
  { children: ReactNode; resetKey?: string },
  { error: Error | null }
> {
  state = { error: null as Error | null };

  static getDerivedStateFromError(error: Error) {
    return { error };
  }

  componentDidCatch(error: Error, info: { componentStack: string }) {
    console.error("[ErrorBoundary]", error, info.componentStack);
  }

  componentDidUpdate(prev: { resetKey?: string }) {
    if (prev.resetKey !== this.props.resetKey && this.state.error) {
      this.setState({ error: null });
    }
  }

  render() {
    if (this.state.error) {
      return (
        <div className="mx-auto flex w-full max-w-[560px] flex-col items-center gap-4 px-7 py-24">
          <span className="flex size-12 items-center justify-center rounded-[12px] bg-bear/12">
            <ShieldAlert className="size-6 text-bear" />
          </span>
          <div className="text-[16px] font-bold text-text">页面渲染出错</div>
          <div className="max-w-full truncate rounded-lg bg-surface px-3 py-2 font-mono text-[11px] text-bear">
            {this.state.error.message}
          </div>
          <button
            onClick={() => this.setState({ error: null })}
            className="rounded-lg bg-accent-soft px-4 py-2 text-[13px] font-semibold text-accent-text hover:bg-accent-soft/80"
          >
            重试
          </button>
        </div>
      );
    }
    return this.props.children;
  }
}
