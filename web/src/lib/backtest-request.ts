/** Body both backtest entries POST to /api/v2/backtest.
 * Local BTC candles on disk cover 2025-06-01 through 2025-10-31.
 */
export const LOCAL_BTC_TIMERANGE = "20250601-20251031";

export function backtestRequestBody(input: {
  dsl: Record<string, unknown>;
  strategyVersionId: string;
  symbols?: string[];
  initialCapital?: number;
  timerange?: string;
}) {
  const symbols = input.symbols?.filter(Boolean);
  return {
    dsl: input.dsl,
    timerange: input.timerange ?? LOCAL_BTC_TIMERANGE,
    symbols: symbols && symbols.length > 0 ? symbols : ["BTC/USDT"],
    initial_capital: input.initialCapital ?? 10000,
    strategy_version_id: input.strategyVersionId,
    client_request_id: crypto.randomUUID(),
  };
}
