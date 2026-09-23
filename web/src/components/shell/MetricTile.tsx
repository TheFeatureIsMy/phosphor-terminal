import { cn } from "@/lib/utils";

/** 统一指标块(对应 Swift MetricTileGrid):label + 大号 tabular 数字 + icon */
export function MetricTile({
  label,
  value,
  color,
  icon,
}: {
  label: string;
  value: string;
  color?: string;
  icon?: React.ReactNode;
}) {
  return (
    <div
      className={cn(
        "rounded-lg border border-border bg-surface p-4 transition-colors",
        "hover:border-border-hover hover:bg-surface-hover"
      )}
    >
      <div className="flex items-center gap-2">
        {icon && (
          <span
            className="flex size-[22px] items-center justify-center rounded-lg [&>svg]:size-3"
            style={{
              color: color ?? "var(--accent-text)",
              background: "color-mix(in srgb, currentColor 12%, transparent)",
            }}
          >
            {icon}
          </span>
        )}
        <span className="truncate font-mono text-[11px] font-semibold uppercase tracking-[0.08em] text-text-3">
          {label}
        </span>
      </div>
      <div
        className="tnum mt-2 truncate font-display text-[22px] font-bold"
        style={{ color: color ?? "var(--text)" }}
      >
        {value}
      </div>
    </div>
  );
}

export function MetricTileGrid({
  tiles,
  columns = 4,
}: {
  tiles: { label: string; value: string; color?: string; icon?: React.ReactNode }[];
  columns?: number;
}) {
  return (
    <div
      className="grid gap-3"
      style={{ gridTemplateColumns: `repeat(${columns}, minmax(0, 1fr))` }}
    >
      {tiles.map((t) => (
        <MetricTile key={t.label} {...t} />
      ))}
    </div>
  );
}
