import { type ChangeEvent } from "react";

/**
 * 画布节点内联编辑控件。
 * 所有交互元素加 `nodrag nowheel` 类，防止 React Flow 拖拽/滚轮劫持。
 * 通过 onChange 回写 node.data（由节点组件用 useReactFlow().updateNodeData）。
 */

export function NodeSelect({
  value,
  options,
  onChange,
  ariaLabel,
}: {
  value: string;
  options: { value: string; label: string }[];
  onChange: (v: string) => void;
  ariaLabel?: string;
}) {
  return (
    <select
      className="pa-edit nodrag nowheel"
      value={value}
      aria-label={ariaLabel}
      onChange={(e: ChangeEvent<HTMLSelectElement>) => onChange(e.target.value)}
      onClick={(e) => e.stopPropagation()}
    >
      {options.map((o) => (
        <option key={o.value} value={o.value}>
          {o.label}
        </option>
      ))}
    </select>
  );
}

export function NodeNumber({
  value,
  onChange,
  step = 1,
  ariaLabel,
}: {
  value: number;
  onChange: (v: number) => void;
  step?: number;
  ariaLabel?: string;
}) {
  return (
    <input
      type="number"
      className="pa-edit pa-edit-num nodrag nowheel"
      value={Number.isFinite(value) ? value : 0}
      step={step}
      aria-label={ariaLabel}
      onChange={(e: ChangeEvent<HTMLInputElement>) => onChange(parseFloat(e.target.value) || 0)}
      onClick={(e) => e.stopPropagation()}
    />
  );
}

export function NodeText({
  value,
  onChange,
  placeholder,
  ariaLabel,
}: {
  value: string;
  onChange: (v: string) => void;
  placeholder?: string;
  ariaLabel?: string;
}) {
  return (
    <input
      type="text"
      className="pa-edit nodrag nowheel"
      value={value}
      placeholder={placeholder}
      aria-label={ariaLabel}
      onChange={(e: ChangeEvent<HTMLInputElement>) => onChange(e.target.value)}
      onClick={(e) => e.stopPropagation()}
    />
  );
}

export function NodeToggle({
  checked,
  onChange,
  ariaLabel,
}: {
  checked: boolean;
  onChange: (v: boolean) => void;
  ariaLabel?: string;
}) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      aria-label={ariaLabel}
      className={`pa-toggle nodrag nowheel ${checked ? "is-on" : ""}`}
      onClick={(e) => {
        e.stopPropagation();
        onChange(!checked);
      }}
    >
      <span className="pa-toggle-knob" />
    </button>
  );
}