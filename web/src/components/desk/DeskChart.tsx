import { useEffect, useRef } from "react";
import {
  CandlestickSeries,
  ColorType,
  HistogramSeries,
  createChart,
  type IChartApi,
  type ISeriesApi,
  type Time,
} from "lightweight-charts";

export interface DeskCandle {
  time: number;
  open: number;
  high: number;
  low: number;
  close: number;
  volume?: number;
}

export function DeskChart({
  candles,
  volume = false,
  background = "#121216",
  text = "#9ba0ae",
  grid = "#1c1c22",
  up = "#3df584",
  down = "#ff4d6d",
}: {
  candles: DeskCandle[];
  volume?: boolean;
  background?: string;
  text?: string;
  grid?: string;
  up?: string;
  down?: string;
}) {
  const node = useRef<HTMLDivElement>(null);
  const chart = useRef<IChartApi | null>(null);
  const series = useRef<ISeriesApi<"Candlestick"> | null>(null);
  const volumeSeries = useRef<ISeriesApi<"Histogram"> | null>(null);

  useEffect(() => {
    const el = node.current;
    if (!el) return;
    const next = createChart(el, {
      autoSize: true,
      layout: {
        background: { type: ColorType.Solid, color: background },
        textColor: text,
        fontFamily: '"JetBrains Mono", ui-monospace, monospace',
        fontSize: 11,
        attributionLogo: false,
      },
      grid: {
        vertLines: { color: grid },
        horzLines: { color: grid },
      },
      rightPriceScale: { borderColor: "#26262c" },
      timeScale: { borderColor: "#26262c", timeVisible: true, secondsVisible: false },
      crosshair: {
        vertLine: { color: "#d8ff3d", labelBackgroundColor: "#22260f" },
        horzLine: { color: "#d8ff3d", labelBackgroundColor: "#22260f" },
      },
      handleScroll: true,
      handleScale: true,
    });
    const price = next.addSeries(CandlestickSeries, {
      upColor: up,
      downColor: down,
      borderUpColor: up,
      borderDownColor: down,
      wickUpColor: up,
      wickDownColor: down,
    });
    const bars = volume
      ? next.addSeries(HistogramSeries, {
          priceFormat: { type: "volume" },
          priceScaleId: "volume",
        })
      : null;
    if (bars) next.priceScale("volume").applyOptions({ scaleMargins: { top: 0.8, bottom: 0 } });
    chart.current = next;
    series.current = price;
    volumeSeries.current = bars;
    const observer = new ResizeObserver(() => next.timeScale().fitContent());
    observer.observe(el);
    return () => {
      observer.disconnect();
      next.remove();
      chart.current = null;
      series.current = null;
      volumeSeries.current = null;
    };
  }, [background, text, grid, up, down, volume]);

  useEffect(() => {
    if (!series.current || candles.length === 0) return;
    const rows = candles.map((bar) => ({
      time: bar.time as Time,
      open: bar.open,
      high: bar.high,
      low: bar.low,
      close: bar.close,
    }));
    series.current.setData(rows);
    volumeSeries.current?.setData(
      candles.map((bar) => ({
        time: bar.time as Time,
        value: bar.volume ?? 0,
        color: bar.close >= bar.open ? "rgba(31,191,117,0.35)" : "rgba(240,68,82,0.35)",
      })),
    );
    chart.current?.timeScale().fitContent();
  }, [candles]);

  return <div ref={node} className="h-full min-h-0 w-full" />;
}
