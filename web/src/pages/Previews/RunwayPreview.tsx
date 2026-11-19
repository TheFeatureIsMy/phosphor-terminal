import { useState } from "react";
import { DeskChart } from "@/components/desk/DeskChart";
import { money, useDeskFacts } from "./useDeskFacts";

const JOBS = [
  { id: "mkt", name: "行情" },
  { id: "bt", name: "回测" },
  { id: "sim", name: "模拟" },
  { id: "risk", name: "门禁" },
  { id: "res", name: "研究" },
] as const;

export function RunwayPreview() {
  const facts = useDeskFacts();
  const [job, setJob] = useState<(typeof JOBS)[number]["id"]>("mkt");
  const chg = facts.change;

  return (
    <div className="floor">
      <header className="floor-top">
        <span>BTC/USDT</span>
        <b>{facts.price == null ? "—" : money(facts.price)}</b>
        <span className={chg == null ? "" : chg >= 0 ? "up" : "down"}>
          {chg == null ? "等待报价" : `${chg >= 0 ? "+" : ""}${chg.toFixed(2)}`}
        </span>
        <span>15 分钟</span>
        <span style={{ marginLeft: "auto", color: facts.running ? "#3dbe7a" : "#e85d6c" }}>
          {facts.running ? `${facts.venue} 在跑` : "模拟未连接"}
        </span>
      </header>

      <nav className="floor-side">
        {JOBS.map((item) => (
          <button key={item.id} aria-pressed={job === item.id} onClick={() => setJob(item.id)}>
            {item.name}
          </button>
        ))}
      </nav>

      <section className="floor-chart">
        <div className="plot">
          {facts.candleError ? <p style={{ padding: 12 }}>K 线没有取到。</p> : (
            <DeskChart candles={facts.candles} background="#0e1116" text="#8b93a3" grid="#1a2030" up="#3dbe7a" down="#e85d6c" />
          )}
        </div>
      </section>

      <aside className="floor-ticket">
        <h2>{facts.liveAllowed ? "可以开实盘" : "实盘还不能开"}</h2>
        <div className="floor-row"><span>策略</span><b>{facts.timeframe}</b></div>
        <div className="floor-row"><span>估值</span><b>{money(facts.total)}</b></div>
        <div className="floor-row"><span>持仓</span><b>{facts.openTrades}</b></div>
        <div className="floor-row"><span>已平</span><b>{facts.closedTrades}</b></div>
        <div className="floor-row"><span>单笔</span><b>{facts.stake}</b></div>
        {facts.balances.map((row) => (
          <div className="floor-row" key={row.currency}><span>{row.currency}</span><b>{money(row.balance)}</b></div>
        ))}
      </aside>

      <section className="floor-book" style={{ gridColumn: "1 / -1" }}>
        {job === "mkt" && <p style={{ padding: 12 }}>图是币安公开的 15 分钟 K 线。右边是模拟账户，不是这张图的收益。</p>}
        {job === "bt" && (
          <p style={{ padding: 12 }}>
            {facts.backtest
              ? `回测 #${facts.backtest.id}：${facts.backtest.trades} 笔，胜率 ${facts.backtest.win}，收益 ${facts.backtest.ret}。${facts.backtest.range}`
              : "还没有回测。"}
          </p>
        )}
        {job === "sim" && <p style={{ padding: 12 }}>{facts.strategy}。没有成交时，账户仍是初始的 USDT 和 USDC。</p>}
        {job === "risk" && (
          <div>
            {facts.gates.map((g) => (
              <button key={g.label} aria-pressed={false}>{g.label} — {g.detail}</button>
            ))}
            {facts.gates.length === 0 && <p style={{ padding: 12 }}>没有未通过的检查。</p>}
          </div>
        )}
        {job === "res" && <p style={{ padding: 12 }}>投研、信号、Agent、情绪是分开的。币安官方 Agent 要浏览器授权，不用这把模拟密钥。</p>}
      </section>
    </div>
  );
}
