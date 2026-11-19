import { useEffect, useMemo, useRef, useState, type ReactNode } from "react";
import { useQuery } from "@tanstack/react-query";
import {
  CandlestickSeries,
  ColorType,
  createChart,
  createSeriesMarkers,
  HistogramSeries,
  type IPriceLine,
  type ISeriesApi,
  type IChartApi,
  type ISeriesMarkersPluginApi,
  type SeriesMarker,
  type Time,
} from "lightweight-charts";
import { api } from "@/lib/api";

interface Candle {
  time: number;
  open: number;
  high: number;
  low: number;
  close: number;
  volume?: number;
  enter?: number;
  exit?: number;
}

interface LiveTrade {
  id: number;
  pair: string;
  open_rate: number;
  current_rate: number;
  profit_pct: number;
  stake: number;
  open_time?: number;
}

interface LiveBoard {
  pair: string;
  timeframe: string;
  analyzed_at: string | null;
  bot_state: string;
  dry_run: boolean;
  last_price: number;
  rsi: number | null;
  decision: "enter" | "exit" | "wait";
  strategy_text: string;
  candle: Candle;
  candles: Candle[];
  open_trades: LiveTrade[];
}

interface HistTrade {
  id: number;
  open_time: number;
  close_time: number;
  open_rate: number;
  close_rate: number | null;
  profit_pct: number;
  exit_reason: string;
  stake: number;
}

interface Replay {
  pair: string;
  timeframe: string;
  summary: { trades: number; profit_abs: number; sharpe: number; winrate: number };
  candles: Candle[];
  trades: HistTrade[];
  paper: { running: boolean; open_trades: number };
}

const TIMEFRAMES = [
  ["1m", "1分"],
  ["5m", "5分"],
  ["15m", "15分"],
  ["30m", "30分"],
  ["1h", "60分"],
  ["4h", "4小时"],
  ["12h", "12小时"],
  ["1d", "日"],
] as const;

const BAR_SECONDS: Record<string, number> = {
  "1m": 60,
  "5m": 300,
  "15m": 900,
  "30m": 1800,
  "1h": 3600,
  "4h": 14400,
  "12h": 43200,
  "1d": 86400,
};

function clock(ts: number) {
  return new Date(ts * 1000).toISOString().slice(11, 16);
}

function PriceChart({
  candles,
  markers,
  entryPrice,
  lastPrice,
  follow,
  callout,
}: {
  candles: Candle[];
  markers: SeriesMarker<Time>[];
  entryPrice?: number | null;
  lastPrice?: number | null;
  follow?: boolean;
  callout?: { time: number; price: number; title: string; detail: string } | null;
}) {
  const [node, setNode] = useState<HTMLDivElement | null>(null);
  const candleSeries = useRef<ISeriesApi<"Candlestick"> | null>(null);
  const volumeSeries = useRef<ISeriesApi<"Histogram"> | null>(null);
  const markerApi = useRef<ISeriesMarkersPluginApi<Time> | null>(null);
  const priceLine = useRef<IPriceLine | null>(null);
  const lastLine = useRef<IPriceLine | null>(null);
  const chartRef = useRef<IChartApi | null>(null);
  const barKey = useRef("");
  const [spot, setSpot] = useState<{ x: number; y: number } | null>(null);

  useEffect(() => {
    if (!node) return;
    const style = getComputedStyle(document.documentElement);
    const bull = style.getPropertyValue("--bull").trim() || "#3df584";
    const bear = style.getPropertyValue("--bear").trim() || "#ff4d6d";
    const text = style.getPropertyValue("--text-2").trim() || "#9ba0ae";
    const line = style.getPropertyValue("--border").trim() || "#26262c";
    const chart = createChart(node, {
      autoSize: true,
      layout: {
        background: { type: ColorType.Solid, color: "transparent" },
        textColor: text,
        fontFamily: "IBM Plex Mono, ui-monospace, monospace",
      },
      grid: { vertLines: { color: line }, horzLines: { color: line } },
      rightPriceScale: { borderColor: line, scaleMargins: { top: 0.16, bottom: 0.18 } },
      timeScale: { borderColor: line, timeVisible: true, secondsVisible: false },
      crosshair: { vertLine: { color: "#8eb0d8", labelBackgroundColor: "#1b1b21" }, horzLine: { color: "#8eb0d8", labelBackgroundColor: "#1b1b21" } },
    });
    const series = chart.addSeries(CandlestickSeries, {
      upColor: bull,
      downColor: bear,
      borderVisible: false,
      wickUpColor: bull,
      wickDownColor: bear,
    });
    const volume = chart.addSeries(HistogramSeries, {
      priceFormat: { type: "volume" },
      priceScaleId: "volume",
    });
    chart.priceScale("volume").applyOptions({ scaleMargins: { top: 0.82, bottom: 0 } });
    chartRef.current = chart;
    candleSeries.current = series;
    volumeSeries.current = volume;
    markerApi.current = createSeriesMarkers(series, []);
    return () => {
      chart.remove();
      chartRef.current = null;
      candleSeries.current = null;
      volumeSeries.current = null;
      markerApi.current = null;
      priceLine.current = null;
      lastLine.current = null;
      barKey.current = "";
    };
  }, [node]);

  useEffect(() => {
    const series = candleSeries.current;
    const volume = volumeSeries.current;
    if (!series || !volume || candles.length === 0) return;
    const last = candles[candles.length - 1];
    const key = `${candles[0].time}:${candles.length}:${last.time}`;
    const bar = { time: last.time as Time, open: last.open, high: last.high, low: last.low, close: last.close };
    if (key !== barKey.current) {
      series.setData(candles.map((c) => ({ time: c.time as Time, open: c.open, high: c.high, low: c.low, close: c.close })));
      volume.setData(candles.map((c) => ({
        time: c.time as Time,
        value: c.volume ?? 0,
        color: c.close >= c.open ? "rgba(61,245,132,0.35)" : "rgba(255,77,109,0.35)",
      })));
      barKey.current = key;
      chartRef.current?.timeScale().scrollToRealTime();
    } else {
      series.update(bar);
      volume.update({
        time: last.time as Time,
        value: last.volume ?? 0,
        color: last.close >= last.open ? "rgba(61,245,132,0.35)" : "rgba(255,77,109,0.35)",
      });
    }
    markerApi.current?.setMarkers(markers);
    if (priceLine.current) series.removePriceLine(priceLine.current);
    priceLine.current = entryPrice
      ? series.createPriceLine({ price: entryPrice, color: "#d8ff3d", lineWidth: 1, lineStyle: 2, title: "入场" })
      : null;
    if (lastLine.current) series.removePriceLine(lastLine.current);
    lastLine.current = lastPrice
      ? series.createPriceLine({ price: lastPrice, color: "#8eb0d8", lineWidth: 1, title: "现价" })
      : null;
    if (follow) chartRef.current?.timeScale().fitContent();
  }, [candles, markers, entryPrice, lastPrice, follow]);

  useEffect(() => {
    const chart = chartRef.current;
    const series = candleSeries.current;
    if (!chart || !series || !callout) {
      setSpot(null);
      return;
    }
    const place = () => {
      const x = chart.timeScale().timeToCoordinate(callout.time as Time);
      const y = series.priceToCoordinate(callout.price);
      setSpot(x == null || y == null ? null : { x, y });
    };
    place();
    chart.timeScale().subscribeVisibleTimeRangeChange(place);
    return () => chart.timeScale().unsubscribeVisibleTimeRangeChange(place);
  }, [callout, candles]);

  return (
    <div className="relative h-full w-full">
      <div ref={setNode} className="h-full w-full" />
      {spot && callout && (
        <div className="pointer-events-none absolute z-20" style={{ left: spot.x, top: spot.y }}>
          <div className="absolute left-0 top-0 size-2 -translate-x-1/2 -translate-y-1/2 rounded-full bg-accent shadow-[0_0_12px_var(--accent)]" />
          <div className="absolute left-2 top-2 w-px h-8 bg-accent/70" />
          <div className="absolute left-2 top-10 w-[220px] border border-accent/40 bg-[#07080c]/90 px-3 py-2 backdrop-blur-sm">
            <div className="font-mono text-[10px] tracking-[0.18em] text-accent-text">{callout.title}</div>
            <div className="mt-1 font-mono text-[12px] leading-5 text-text">{callout.detail}</div>
          </div>
        </div>
      )}
    </div>
  );
}

function applyTick(candles: Candle[], tick: { price: number; bar_time: number }): Candle[] {
  if (!candles.length) return candles;
  const last = candles[candles.length - 1];
  if (tick.bar_time > last.time) {
    return [...candles.slice(-239), { time: tick.bar_time, open: tick.price, high: tick.price, low: tick.price, close: tick.price, volume: 0 }];
  }
  if (tick.bar_time < last.time) return candles;
  const close = tick.price;
  if (close === last.close) return candles;
  const next = { ...last, close, high: Math.max(last.high, close), low: Math.min(last.low, close) };
  const copy = candles.slice();
  copy[copy.length - 1] = next;
  return copy;
}

function LiveDesk({ mode, setMode, tf, setTf }: { mode: "live" | "history"; setMode: (m: "live" | "history") => void; tf: string; setTf: (tf: string) => void }) {
  const book = useQuery({
    queryKey: ["trace", "candles", tf],
    queryFn: () => api.get<{ candles: Candle[] }>(`/api/v2/trace/candles?timeframe=${tf}`),
    staleTime: Infinity,
  });
  const { data, error } = useQuery({
    queryKey: ["trace", "live"],
    queryFn: () => api.get<LiveBoard>("/api/v2/trace/live"),
    refetchInterval: 15_000,
    staleTime: 10_000,
  });
  const tick = useQuery({
    queryKey: ["trace", "tick", tf],
    queryFn: () => api.get<{ price: number; bar_time: number }>(`/api/v2/trace/tick?timeframe=${tf}`),
    refetchInterval: 1000,
  });
  const [candles, setCandles] = useState<Candle[] | null>(null);
  useEffect(() => {
    setCandles(null);
  }, [tf]);
  useEffect(() => {
    if (!book.data) return;
    setCandles((prev) => {
      const incoming = book.data.candles;
      if (!prev?.length) return incoming;
      const lastIn = incoming[incoming.length - 1];
      const lastPrev = prev[prev.length - 1];
      if (!lastIn || lastIn.time !== lastPrev.time) return incoming;
      const merged = incoming.slice();
      merged[merged.length - 1] = {
        ...lastIn,
        close: lastPrev.close,
        high: Math.max(Number(lastIn.high), lastPrev.high),
        low: Math.min(Number(lastIn.low), lastPrev.low),
      };
      return merged;
    });
  }, [book.data]);
  useEffect(() => {
    if (!tick.data) return;
    setCandles((prev) => (prev ? applyTick(prev, tick.data) : prev));
  }, [tick.data]);
  const markers = useMemo<SeriesMarker<Time>[]>(() => {
    if (!candles || !data) return [];
    const seconds = BAR_SECONDS[tf] ?? 300;
    const times = new Set(candles.map((c) => c.time));
    const out: SeriesMarker<Time>[] = [];
    for (const bar of data.candles) {
      if (!bar.enter && !bar.exit) continue;
      const slot = bar.time - (bar.time % seconds);
      if (!times.has(slot)) continue;
      if (bar.enter) out.push({ time: slot as Time, position: "belowBar", color: "#3df584", shape: "arrowUp", text: "开" });
      if (bar.exit) out.push({ time: slot as Time, position: "aboveBar", color: "#ff4d6d", shape: "arrowDown", text: "平" });
    }
    return out;
  }, [candles, data, tf]);

  if (book.isLoading || !candles) return <div className="h-[78vh] min-h-[680px] animate-pulse bg-[#07080c]" />;
  if (book.error) return <div className="px-6 py-16 font-mono text-[12px] text-text-3">这个周期的行情没有取到。</div>;

  const last = candles[candles.length - 1];
  const price = tick.data?.price ?? last.close;
  const seconds = BAR_SECONDS[tf] ?? 300;
  const align = (ts: number) => ts - (ts % seconds);
  const open = data?.open_trades[0];
  const marked = [...(data?.candles ?? [])].reverse().find((c) => c.enter || c.exit);
  const callout = open
    ? { time: align(open.open_time ?? last.time), price: open.open_rate, title: "持仓", detail: `${open.stake} USDT · ${open.profit_pct > 0 ? "+" : ""}${open.profit_pct}%` }
    : marked
      ? { time: align(marked.time), price: marked.close, title: marked.enter ? "开多" : "平仓", detail: data?.strategy_text ?? "" }
      : null;

  return (
    <Stage
      price={price}
      up={price >= last.open}
      eyebrow={`${data?.dry_run ? "DRY RUN" : "LIVE"} · ${(data?.bot_state ?? "running").toUpperCase()} · ${TIMEFRAMES.find(([id]) => id === tf)?.[1] ?? tf}`}
      rsi={data?.rsi ?? null}
      rows={[
        { k: "信号", v: data?.rsi == null ? "—" : `RSI ${data.rsi.toFixed(1)}`, on: true },
        { k: "判断", v: !data || data.decision === "wait" ? "未过线" : data.decision === "enter" ? "允许开多" : "要求平仓", on: Boolean(data && data.decision !== "wait") },
        { k: "执行", v: data?.dry_run === false ? "交易所" : "模拟撮合", on: true },
        { k: "下单", v: open ? `${open.pair} 持仓` : "无委托", on: Boolean(open) || Boolean(data && data.decision !== "wait") },
      ]}
      note={data?.strategy_text ?? "策略状态稍后跟上"}
      candles={candles}
      markers={markers}
      entryPrice={open?.open_rate}
      lastPrice={price}
      callout={callout}
      mode={mode}
      setMode={setMode}
      tf={tf}
      setTf={setTf}
    />
  );
}

function HistoryDesk({ mode, setMode, setTf }: { mode: "live" | "history"; setMode: (m: "live" | "history") => void; setTf: (tf: string) => void }) {
  const { data, error, isLoading } = useQuery({
    queryKey: ["trace", "replay"],
    queryFn: () => api.get<Replay>("/api/v2/trace/replay"),
    staleTime: Infinity,
  });
  const [cursor, setCursor] = useState(200);
  const [playing, setPlaying] = useState(false);

  useEffect(() => {
    if (!playing || !data) return;
    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    const timer = window.setInterval(() => {
      setCursor((c) => {
        if (c >= data.candles.length - 1) {
          setPlaying(false);
          return c;
        }
        return Math.min(data.candles.length - 1, c + (reduce ? 40 : 8));
      });
    }, reduce ? 500 : 90);
    return () => window.clearInterval(timer);
  }, [playing, data]);

  const now = data?.candles[Math.min(cursor, (data?.candles.length ?? 1) - 1)];
  const windowed = useMemo(() => {
    if (!data || !now) return [];
    const from = now.time - 60 * 60 * 30;
    return data.candles.filter((c) => c.time <= now.time && c.time >= from).slice(-180);
  }, [data, now]);
  const openNow = data?.trades.find((t) => now && t.open_time <= now.time && t.close_time > now.time);
  const justOpened = data?.trades.find((t) => now && t.open_time === now.time);
  const justClosed = data?.trades.find((t) => now && t.close_time === now.time);
  const stage = justOpened || justClosed ? 3 : openNow ? 2 : 1;
  const markers = useMemo<SeriesMarker<Time>[]>(() => {
    if (!data || !now) return [];
    const times = new Set(windowed.map((c) => c.time));
    return data.trades.flatMap((t) => {
      const out: SeriesMarker<Time>[] = [];
      if (t.open_time <= now.time && times.has(t.open_time)) out.push({ time: t.open_time as Time, position: "belowBar", color: "#3df584", shape: "arrowUp", text: "开" });
      if (t.close_time <= now.time && times.has(t.close_time)) out.push({ time: t.close_time as Time, position: "aboveBar", color: "#ff4d6d", shape: "arrowDown", text: "平" });
      return out;
    });
  }, [data, now, windowed]);

  if (isLoading) return <div className="h-[78vh] min-h-[680px] animate-pulse bg-[#07080c]" />;
  if (error || !data || !now) return <div className="px-6 py-16 font-mono text-[12px] text-text-3">历史行情没有加载。</div>;

  const callout = justOpened
    ? { time: justOpened.open_time, price: justOpened.open_rate, title: "开多", detail: `${justOpened.stake} USDT` }
    : justClosed
      ? { time: justClosed.close_time, price: justClosed.close_rate ?? justClosed.open_rate, title: "平仓", detail: `${justClosed.exit_reason} · ${justClosed.profit_pct}%` }
      : openNow
        ? { time: now.time, price: openNow.open_rate, title: "持仓中", detail: `入场 ${openNow.open_rate}` }
        : null;

  return (
    <Stage
      price={now.close}
      up={now.close >= now.open}
      eyebrow={`REPLAY · ${new Date(now.time * 1000).toISOString().slice(0, 16).replace("T", " ")} UTC`}
      rsi={null}
      rows={[
        { k: "信号", v: justOpened || justClosed ? "这根已触发" : "监视", on: Boolean(justOpened || justClosed) },
        { k: "判断", v: openNow ? "持有" : "空仓", on: Boolean(openNow) },
        { k: "执行", v: "历史回放", on: true },
        { k: "下单", v: openNow ? "持仓" : "无委托", on: Boolean(openNow) },
      ]}
      note={openNow ? `这笔将以 ${openNow.exit_reason} 结束` : "指针还没走到下一笔"}
      candles={windowed}
      markers={markers}
      entryPrice={openNow?.open_rate}
      follow
      callout={callout}
      transport={
        <div className="flex items-center gap-3">
          <button type="button" className="font-mono text-[12px] text-accent-text" onClick={() => setPlaying((v) => !v)}>{playing ? "暂停" : "回放"}</button>
          <input className="h-1 min-w-[160px] flex-1 accent-[var(--accent)]" type="range" min={180} max={data.candles.length - 1} value={cursor} onChange={(e) => { setPlaying(false); setCursor(Number(e.target.value)); }} />
        </div>
      }
      mode={mode}
      setMode={setMode}
      tf="5m"
      setTf={(next) => { setTf(next); setMode("live"); }}
    />
  );
}

function Stage({
  price,
  up,
  eyebrow,
  rsi,
  rows,
  note,
  candles,
  markers,
  entryPrice,
  lastPrice,
  follow,
  callout,
  transport,
  mode,
  setMode,
  tf,
  setTf,
}: {
  price: number;
  up: boolean;
  eyebrow: string;
  rsi: number | null;
  rows: { k: string; v: string; on: boolean }[];
  note: string;
  candles: Candle[];
  markers: SeriesMarker<Time>[];
  entryPrice?: number | null;
  lastPrice?: number | null;
  follow?: boolean;
  callout?: { time: number; price: number; title: string; detail: string } | null;
  transport?: ReactNode;
  mode: "live" | "history";
  setMode: (m: "live" | "history") => void;
  tf?: string;
  setTf?: (tf: string) => void;
}) {
  return (
    <section className="relative h-[78vh] min-h-[680px] overflow-hidden bg-[#07080c]">
      <div className="absolute inset-0">
        <PriceChart candles={candles} markers={markers} entryPrice={entryPrice} lastPrice={lastPrice} follow={follow} callout={callout} />
      </div>
      <header className="pointer-events-none absolute inset-x-0 top-0 z-10 flex items-start justify-between px-6 py-4">
        <div>
          <div className="font-mono text-[10px] tracking-[0.42em] text-accent-text">PHOSPHOR</div>
          <div className="mt-1 font-mono text-[12px] text-text-3">{eyebrow}</div>
        </div>
        {tf && setTf && (
          <div className="pointer-events-auto flex flex-wrap justify-end gap-x-3 gap-y-1 font-mono text-[12px]">
            {TIMEFRAMES.map(([id, label]) => (
              <button key={id} type="button" onClick={() => setTf(id)} className={tf === id ? "text-accent-text" : "text-text-3"}>
                {label}
              </button>
            ))}
          </div>
        )}
        <div className="pointer-events-auto flex gap-4 font-mono text-[12px]">
          {(["live", "history"] as const).map((id) => (
            <button key={id} type="button" onClick={() => setMode(id)} className={mode === id ? "text-accent-text" : "text-text-3"}>
              {id === "live" ? "运行中" : "历史过程"}
            </button>
          ))}
        </div>
      </header>
      <div className="pointer-events-none absolute left-6 top-16 z-10">
        <div className="font-mono text-[11px] tracking-[0.28em] text-text-3">BTC / USDT</div>
        <div key={price} className={`hud-price tnum mt-1 font-mono text-[64px] leading-none ${up ? "text-bull" : "text-bear"}`}>
          {price.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
        </div>
        <div className="mt-2 font-mono text-[12px] text-text-2">{rsi == null ? note : `RSI ${rsi.toFixed(1)} · ${note}`}</div>
      </div>
      <aside className="absolute bottom-16 right-8 z-10 w-[168px]">
        {rows.map((row) => (
          <div key={row.k} className="flex items-baseline justify-between border-t border-white/10 py-2">
            <span className="font-mono text-[10px] tracking-[0.16em] text-text-3">{row.k}</span>
            <span className={`font-mono text-[12px] ${row.on ? "text-text" : "text-text-3"}`}>{row.v}</span>
          </div>
        ))}
      </aside>
      {transport && <div className="absolute inset-x-6 bottom-4 z-10">{transport}</div>}
    </section>
  );
}

export function ChainReplay() {
  const [mode, setMode] = useState<"live" | "history">("live");
  const [tf, setTf] = useState("5m");
  return mode === "live"
    ? <LiveDesk mode={mode} setMode={setMode} tf={tf} setTf={setTf} />
    : <HistoryDesk mode={mode} setMode={setMode} setTf={setTf} />;
}
