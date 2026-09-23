import { ListOrdered, Package } from "lucide-react";
import { PageHeader } from "@/components/shell/PageHeader";
import { EmptyState } from "@/components/shell/EmptyState";
import { VoltCard } from "@/components/shell/VoltCard";
import { FadeIn } from "@/components/effects/FadeIn";
import { useOrdersPositions } from "@/lib/hooks";
import { cn } from "@/lib/utils";

const fmt2 = (v: number) =>
  v.toLocaleString("zh-CN", { minimumFractionDigits: 2, maximumFractionDigits: 2 });

function sideChip(side: string) {
  const k = side.toLowerCase();
  if (k === "long" || k === "buy") return "bg-bull/12 text-bull";
  if (k === "short" || k === "sell") return "bg-bear/12 text-bear";
  return "bg-surface text-text-2";
}

export default function OrdersPositionsPage() {
  const { data } = useOrdersPositions();
  const orders = data?.orders ?? [];
  const positions = data?.positions ?? [];

  return (
    <div className="mx-auto w-full max-w-[1340px] space-y-4 px-7 py-6">
      <FadeIn index={0}>
        <PageHeader
          eyebrow="ORDERS & POSITIONS"
          title="订单 / 持仓"
          subtitle={`${positions.length} 持仓 · ${orders.length} 挂单`}
        />
      </FadeIn>

      {/* 持仓 */}
      <FadeIn index={1}>
        <VoltCard spotlight className="overflow-hidden">
          <div className="border-b border-border px-5 py-3.5 font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-2">
            开放持仓
          </div>
          {positions.length === 0 ? (
            <EmptyState compact icon={<Package />} title="当前无持仓" description="策略开仓后,持仓与未实现盈亏会实时显示在这里。" />
          ) : (
            <table className="w-full text-[13px]">
              <thead>
                <tr className="border-b border-border text-left font-mono text-[10px] uppercase tracking-[0.08em] text-text-3">
                  <th className="px-5 py-3 font-medium">标的</th>
                  <th className="px-3 py-3 font-medium">方向</th>
                  <th className="px-3 py-3 font-medium text-right">数量</th>
                  <th className="px-3 py-3 font-medium text-right">均价</th>
                  <th className="px-3 py-3 font-medium text-right">现价</th>
                  <th className="px-3 py-3 font-medium text-right">未实现盈亏</th>
                  <th className="px-5 py-3 font-medium text-right">止损 / 止盈</th>
                </tr>
              </thead>
              <tbody>
                {positions.map((p) => (
                  <tr key={p.id} className="border-b border-border/50 transition-colors last:border-0 hover:bg-surface-hover">
                    <td className="px-5 py-3 font-semibold text-text">{p.symbol}</td>
                    <td className="px-3 py-3">
                      <span className={cn("rounded-md px-2 py-0.5 text-[11.5px] font-semibold", sideChip(p.side))}>
                        {p.side}
                      </span>
                    </td>
                    <td className="tnum px-3 py-3 text-right font-mono text-text">{p.quantity}</td>
                    <td className="tnum px-3 py-3 text-right font-mono text-text-2">{fmt2(p.avg_entry_price)}</td>
                    <td className="tnum px-3 py-3 text-right font-mono text-text">{fmt2(p.current_price)}</td>
                    <td className={cn(
                      "tnum px-3 py-3 text-right font-mono font-semibold",
                      p.unrealized_pnl >= 0 ? "text-bull" : "text-bear"
                    )}>
                      {p.unrealized_pnl >= 0 ? "+" : ""}{fmt2(p.unrealized_pnl)}
                      <span className="ml-1 text-[11px] opacity-70">({fmt2(p.unrealized_pnl_pct)}%)</span>
                    </td>
                    <td className="tnum px-5 py-3 text-right font-mono text-[12px] text-text-3">
                      {p.stop_loss ? fmt2(p.stop_loss) : "—"} / {p.take_profit ? fmt2(p.take_profit) : "—"}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </VoltCard>
      </FadeIn>

      {/* 挂单 */}
      <FadeIn index={2}>
        <VoltCard spotlight className="overflow-hidden">
          <div className="border-b border-border px-5 py-3.5 font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-2">
            待处理订单
          </div>
          {orders.length === 0 ? (
            <EmptyState compact icon={<ListOrdered />} title="当前无挂单" description="限价单、止损单等待成交的订单会显示在这里。" />
          ) : (
            <table className="w-full text-[13px]">
              <thead>
                <tr className="border-b border-border text-left font-mono text-[10px] uppercase tracking-[0.08em] text-text-3">
                  <th className="px-5 py-3 font-medium">标的</th>
                  <th className="px-3 py-3 font-medium">方向</th>
                  <th className="px-3 py-3 font-medium">类型</th>
                  <th className="px-3 py-3 font-medium text-right">数量</th>
                  <th className="px-3 py-3 font-medium text-right">价格</th>
                  <th className="px-3 py-3 font-medium">状态</th>
                  <th className="px-5 py-3 font-medium">创建时间</th>
                </tr>
              </thead>
              <tbody>
                {orders.map((o) => (
                  <tr key={o.id} className="border-b border-border/50 transition-colors last:border-0 hover:bg-surface-hover">
                    <td className="px-5 py-3 font-semibold text-text">{o.symbol}</td>
                    <td className="px-3 py-3">
                      <span className={cn("rounded-md px-2 py-0.5 text-[11.5px] font-semibold", sideChip(o.side))}>
                        {o.side}
                      </span>
                    </td>
                    <td className="px-3 py-3 font-mono text-text-2">{o.type}</td>
                    <td className="tnum px-3 py-3 text-right font-mono text-text">{o.quantity}</td>
                    <td className="tnum px-3 py-3 text-right font-mono text-text">{o.price ? fmt2(o.price) : "市价"}</td>
                    <td className="px-3 py-3">
                      <span className="rounded-md bg-warn/12 px-2 py-0.5 text-[11.5px] font-semibold text-warn">
                        {o.status}
                      </span>
                    </td>
                    <td className="px-5 py-3 font-mono text-[11px] text-text-3">
                      {o.created_at ? new Date(o.created_at).toLocaleString("zh-CN", { hour12: false }) : "—"}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </VoltCard>
      </FadeIn>
    </div>
  );
}
