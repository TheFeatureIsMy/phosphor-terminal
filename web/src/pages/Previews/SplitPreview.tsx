import { useState } from "react";
import { DeskChart } from "@/components/desk/DeskChart";
import { money, useDeskFacts } from "./useDeskFacts";

const SECTIONS = [
  { id: "now", name: "现在" },
  { id: "test", name: "回测" },
  { id: "sim", name: "模拟" },
  { id: "gate", name: "实盘" },
  { id: "rest", name: "其他功能" },
] as const;

export function SplitPreview() {
  const facts = useDeskFacts();
  const [current, setCurrent] = useState("now");
  const jump = (id: string) => {
    setCurrent(id);
    document.getElementById(`folio-${id}`)?.scrollIntoView({ behavior: "smooth", block: "start" });
  };

  return (
    <div className="folio">
      <nav>
        {SECTIONS.map((s) => (
          <button key={s.id} aria-current={current === s.id} onClick={() => jump(s.id)}>{s.name}</button>
        ))}
      </nav>
      <main>
        <h1>这笔交易停在模拟</h1>
        <p style={{ maxWidth: "46ch" }}>策略已经有回测。模拟进程在币安 Demo 上跑。实盘门禁还没过，所以这里不能下真单。</p>
        <section id="folio-now">
          <h2>现在的价格</h2>
          <p className="num" style={{ fontSize: 28 }}>{facts.price == null ? "—" : money(facts.price)}</p>
          <div style={{ height: 280 }}>
            {facts.candleError ? <p>K 线没有取到。</p> : (
              <DeskChart candles={facts.candles} background="#f7f8fa" text="#52606e" grid="#e1e5ea" up="#1f8a4c" down="#c43838" />
            )}
          </div>
        </section>
        <section id="folio-test">
          <h2>回测</h2>
          {facts.backtest ? (
            <p>{facts.backtest.trades} 笔，胜率 {facts.backtest.win}，收益 {facts.backtest.ret}。{facts.backtest.range}</p>
          ) : <p>还没有回测。</p>}
        </section>
        <section id="folio-sim">
          <h2>模拟</h2>
          <p>{facts.running ? `${facts.venue} 在跑` : "进程没连上"}。{facts.strategy}。持仓 {facts.openTrades}，已平仓 {facts.closedTrades}，估值 {money(facts.total)}。单笔 {facts.stake}。</p>
          <p>{facts.balances.map((b) => `${b.currency} ${money(b.balance)}`).join("，")}</p>
        </section>
        <section id="folio-gate">
          <h2>{facts.liveAllowed ? "实盘可以启动" : "实盘还不能开"}</h2>
          <ul>
            {facts.gates.map((g) => <li key={g.label}><b>{g.label}</b> {g.detail}</li>)}
            {facts.gates.length === 0 && <li>没有未通过的检查。</li>}
          </ul>
        </section>
        <section id="folio-rest">
          <h2>其他功能</h2>
          <p>市场结构、操纵雷达、订单、对账、止损、熔断、信号、情绪、复盘、失败聚类、连接和服务状态，都在正式客户端的侧栏里。这一页只把主链路写清楚。</p>
        </section>
      </main>
      <aside>
        <p style={{ marginTop: 0 }}>账户</p>
        <p className="num">{money(facts.total)}</p>
        {facts.balances.map((b) => <p key={b.currency} className="num">{b.currency} {money(b.balance)}</p>)}
        <p>{facts.running ? "模拟进程在跑" : "模拟进程没连上"}</p>
      </aside>
    </div>
  );
}
