import { PageHeader } from "@/components/shell/PageHeader";
import { EmptyState } from "@/components/shell/EmptyState";
import { Table2 } from "lucide-react";
import { VoltCard } from "@/components/shell/VoltCard";
import { FadeIn } from "@/components/effects/FadeIn";
import { useStructureMatrix } from "@/lib/hooks";
import type { MatrixCell } from "@/lib/types";
import { cn } from "@/lib/utils";

function cellTone(status: string): { bg: string; text: string } {
  const k = status.toLowerCase();
  if (k === "active") return { bg: "bg-bull/12", text: "text-bull" };
  if (k === "warning") return { bg: "bg-warn/12", text: "text-warn" };
  if (k === "violated") return { bg: "bg-bear/12", text: "text-bear" };
  return { bg: "bg-surface", text: "text-text-3" };
}

function Cell({ cell }: { cell?: MatrixCell }) {
  if (!cell) {
    return <td className="border-l border-border/40 px-3 py-2.5 text-center font-mono text-[11px] text-text-3">—</td>;
  }
  const tone = cellTone(cell.status);
  return (
    <td className="border-l border-border/40 px-3 py-2.5 text-center">
      <span className={cn("inline-block rounded-md px-2 py-1 font-mono text-[11px] font-semibold", tone.bg, tone.text)}>
        {(cell.current_strength * 100).toFixed(0)}%
      </span>
      {cell.temporary_violation && <span className="ml-1 text-bear">⚠</span>}
    </td>
  );
}

export default function StructureMatrixPage() {
  const { data } = useStructureMatrix("BTC/USDT");
  const rows = data?.rows ?? [];
  const zoneTypes = [...new Set(rows.flatMap((r) => Object.keys(r.cells)))];

  return (
    <div className="mx-auto w-full max-w-[1340px] space-y-4 px-7 py-6">
      <FadeIn index={0}>
        <PageHeader
          eyebrow="STRUCTURE MATRIX"
          title="结构矩阵"
          subtitle={`${data?.symbol ?? "BTC/USDT"} · 多周期结构强度矩阵 · 基准 ${data?.base_timeframe ?? "5m"}`}
        />
      </FadeIn>

      <FadeIn index={1}>
        <VoltCard spotlight className="overflow-x-auto">
          {rows.length === 0 ? (
            <EmptyState compact icon={<Table2 />} title="暂无矩阵数据" description="多周期结构强度识别后,矩阵会显示在这里。" />
          ) : (
            <table className="w-full text-[13px]">
              <thead>
                <tr className="border-b border-border text-left font-mono text-[10px] uppercase tracking-[0.08em] text-text-3">
                  <th className="px-5 py-3 font-medium">周期</th>
                  {zoneTypes.map((z) => (
                    <th key={z} className="border-l border-border/40 px-3 py-3 text-center font-medium">
                      {z}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {rows.map((row) => (
                  <tr key={row.timeframe} className="border-b border-border/50 transition-colors last:border-0 hover:bg-surface-hover">
                    <td className="px-5 py-2.5 font-mono font-semibold text-text">{row.timeframe}</td>
                    {zoneTypes.map((z) => (
                      <Cell key={z} cell={row.cells[z]} />
                    ))}
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </VoltCard>
      </FadeIn>

      {/* 图例 */}
      <FadeIn index={2}>
        <div className="flex items-center gap-5 font-mono text-[11px] text-text-3">
          <span className="flex items-center gap-1.5"><span className="size-2 rounded-sm bg-bull/40" /> active</span>
          <span className="flex items-center gap-1.5"><span className="size-2 rounded-sm bg-warn/40" /> warning</span>
          <span className="flex items-center gap-1.5"><span className="size-2 rounded-sm bg-bear/40" /> violated</span>
          <span className="flex items-center gap-1.5"><span className="size-2 rounded-sm bg-surface" /> inactive</span>
        </div>
      </FadeIn>
    </div>
  );
}
