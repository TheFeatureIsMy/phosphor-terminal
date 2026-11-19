import { useEffect, useState } from "react";
import { useSearchParams } from "react-router-dom";
import { RunwayPreview } from "./RunwayPreview";
import { SplitPreview } from "./SplitPreview";
import { StackPreview } from "./StackPreview";
import "./previews.css";

const VIEWS = [
  { id: "runway", label: "四格盘" },
  { id: "split", label: "卷宗" },
  { id: "stack", label: "全图" },
] as const;

type ViewId = (typeof VIEWS)[number]["id"];

export default function DesignPreviews() {
  const [params, setParams] = useSearchParams();
  const initial = VIEWS.some((v) => v.id === params.get("v")) ? (params.get("v") as ViewId) : "runway";
  const [view, setView] = useState<ViewId>(initial);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement) return;
      if (e.key === "1") pick("runway");
      if (e.key === "2") pick("split");
      if (e.key === "3") pick("stack");
    };
    const pick = (id: ViewId) => {
      setView(id);
      setParams({ v: id }, { replace: true });
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [setParams]);

  const pick = (id: ViewId) => {
    setView(id);
    setParams({ v: id }, { replace: true });
  };

  return (
    <div className="pv-frame">
      <div className="pv-bar" role="tablist" aria-label="设计预览">
        <span>预览，正式界面没改</span>
        {VIEWS.map((v, i) => (
          <button key={v.id} aria-pressed={view === v.id} onClick={() => pick(v.id)}>
            {i + 1} {v.label}
          </button>
        ))}
      </div>
      <div className="pv-stage">
        {view === "runway" && <RunwayPreview />}
        {view === "split" && <SplitPreview />}
        {view === "stack" && <StackPreview />}
      </div>
    </div>
  );
}
