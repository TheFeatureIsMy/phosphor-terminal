import { useState } from "react";
import { DeskChart } from "@/components/desk/DeskChart";
import { money, useDeskFacts } from "./useDeskFacts";

const TOOLS = [
  { id: "none", name: "只看图" },
  { id: "sim", name: "模拟" },
  { id: "bt", name: "回测" },
  { id: "gate", name: "门禁" },
] as const;

export function StackPreview() {
  const facts = useDeskFacts();
  const [tool, setTool] = useState<(typeof TOOLS)[number]["id"]>("sim");
  const chg = facts.change;

  return (
    <div className="hud">
      <div className="hud-chart" style={{ bottom: tool === "none" ? 52 : 272 }}>
        {facts.candleError ? <p style={{ padding: 16 }}>K 线没有取到。</p> : (
          <DeskChart candles={facts.candles} background="#07080b" text="#9aa3b2" grid="#151922" up="#3dbe7a" down="#e85d6c" />
        )}
      </div>
      <div className="hud-read">
        <b>{facts.price == null ? "—" : money(facts.price)}</b>
        <span>BTC/USDT 15 分钟 </span>
        <span className={chg == null ? "" : chg >= 0 ? "up" : "down"}>
          {chg == null ? "" : `${chg >= 0 ? "+" : ""}${chg.toFixed(2)}`}
        </span>
      </div>
      {tool !== "none" && (
        <section className="hud-panel">
          {tool === "sim" && (
            <>
              <p style={{ marginTop: 0 }}>{facts.running ? `${facts.venue} 在跑` : "模拟没连上"} · {facts.strategy}</p>
              <p>估值 {money(facts.total)} · 持仓 {facts.openTrades} · 已平 {facts.closedTrades} · 单笔 {facts.stake}</p>
              <p>{facts.balances.map((b) => `${b.currency} ${money(b.balance)}`).join("    ")}</p>
            </>
          )}
          {tool === "bt" && (
            <p>
              {facts.backtest
                ? `#${facts.backtest.id}  ${facts.backtest.trades} 笔  胜率 ${facts.backtest.win}  收益 ${facts.backtest.ret}  ${facts.backtest.range}`
                : "还没有回测。"}
            </p>
          )}
          {tool === "gate" && (
            <ul style={{ margin: 0, paddingLeft: 18 }}>
              {facts.gates.map((g) => <li key={g.label}><b>{g.label}</b> {g.detail}</li>)}
              {facts.gates.length === 0 && <li>没有未通过的检查。</li>}
            </ul>
          )}
        </section>
      )}
      <nav className="hud-tools">
        {TOOLS.map((item) => (
          <button key={item.id} aria-pressed={tool === item.id} onClick={() => setTool(item.id)}>{item.name}</button>
        ))}
      </nav>
    </div>
  );
}
