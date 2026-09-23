import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api } from "./api";

/** 列表响应解包:兼容裸数组与包装对象({items}/{results}/{data}/自定义键),杜绝 xxx.map is not a function */
function unwrapList<T>(data: unknown): T[] {
  if (Array.isArray(data)) return data as T[];
  if (data && typeof data === "object") {
    const o = data as Record<string, unknown>;
    for (const k of ["items", "results", "data", "list", "agents", "providers", "runs", "signals", "reports", "candidates", "scores", "cases", "strategies"]) {
      if (Array.isArray(o[k])) return o[k] as T[];
    }
  }
  return [];
}
import type {
  DashboardKPIs,
  ExecutionCenterResponse,
  OrdersPositionsResponse,
  ReconciliationBusResponse,
  RiskOverviewResponse,
  StopProtectionResponse,
  CircuitBreakersResponse,
  MarketStructureResponse,
  StructureMatrixResponse,
  ManipulationScore,
  ManipulationCaseSummary,
  GrowthReport,
  StrategyCandidate,
  FailureClusteringResponse,
  AIResearchRun,
  AgentProfile,
  AgentTask,
  StrategyRunView,
  AdminProvider,
  SystemSettingView,
  SentimentMarket,
  RiskRules,
  RiskRulesUpdate,
  DashboardResponse,
  EquityPoint,
  GlobalStatusResponse,
  LiveReadinessResponse,
  SignalSummary,
  TradingCommandResponse,
  StartLiveSmallResponse,
  DisableAutoResponse,
} from "./types";

export function useDashboard() {
  return useQuery({
    placeholderData: keepPreviousData,    queryKey: ["overview", "dashboard"],
    queryFn: () => api.get<DashboardResponse>("/api/overview/dashboard"),
  });
}

export function useGlobalStatus() {
  return useQuery({
    placeholderData: keepPreviousData,    queryKey: ["overview", "global-status"],
    queryFn: () => api.get<GlobalStatusResponse>("/api/overview/global-status"),
    refetchInterval: 10_000,
  });
}

export function useLiveReadiness() {
  return useQuery({
    placeholderData: keepPreviousData,    queryKey: ["overview", "live-readiness"],
    queryFn: () => api.get<LiveReadinessResponse>("/api/overview/live-readiness"),
  });
}

export function useDashboardKPIs() {
  return useQuery({
    placeholderData: keepPreviousData,    queryKey: ["dashboard", "kpis"],
    queryFn: () => api.get<DashboardKPIs>("/api/dashboard/kpis"),
  });
}

export function useEquityCurve() {
  return useQuery({
    placeholderData: keepPreviousData,    queryKey: ["dashboard", "equity-curve"],
    queryFn: () => api.get<EquityPoint[]>("/api/dashboard/equity-curve"),
    staleTime: 60_000,
    refetchInterval: 60_000,
  });
}

export function useSignals() {
  return useQuery({
    placeholderData: keepPreviousData,    queryKey: ["signals", "list"],
    queryFn: () => api.get<SignalSummary[]>("/api/v2/signals"),
     select: (d) => unwrapList<SignalSummary>(d),
  });
}

export function useExecutionCenter() {
  return useQuery({
    placeholderData: keepPreviousData,    queryKey: ["execution", "center"],
    queryFn: () => api.get<ExecutionCenterResponse>("/api/execution/center"),
  });
}

export function useOrdersPositions() {
  return useQuery({
    placeholderData: keepPreviousData,    queryKey: ["execution", "orders-positions"],
    queryFn: () => api.get<OrdersPositionsResponse>("/api/execution/positions"),
  });
}

export function useReconciliationBus() {
  return useQuery({
    placeholderData: keepPreviousData,    queryKey: ["reconciliation", "bus"],
    queryFn: () => api.get<ReconciliationBusResponse>("/api/reconciliation/bus"),
  });
}

export function useRiskOverview() {
  return useQuery({
    placeholderData: keepPreviousData,    queryKey: ["risk", "overview"],
    queryFn: () => api.get<RiskOverviewResponse>("/api/risk/overview"),
  });
}

export function useStopProtection() {
  return useQuery({
    placeholderData: keepPreviousData,    queryKey: ["risk", "stop-protection"],
    queryFn: () => api.get<StopProtectionResponse>("/api/risk/stop-protection"),
  });
}

export function useCircuitBreakers() {
  return useQuery({
    placeholderData: keepPreviousData,    queryKey: ["risk", "circuit-breakers"],
    queryFn: () => api.get<CircuitBreakersResponse>("/api/risk/circuit-breakers"),
  });
}

export function useMarketStructure(symbol = "BTC/USDT", timeframe = "5m") {
  return useQuery({
    placeholderData: keepPreviousData,    queryKey: ["structure", "market-view", symbol, timeframe],
    queryFn: () =>
      api.get<MarketStructureResponse>(
        `/api/structure/market-view?symbol=${encodeURIComponent(symbol)}&timeframe=${timeframe}`
      ),
  });
}

export function useStructureMatrix(symbol = "BTC/USDT") {
  return useQuery({
    placeholderData: keepPreviousData,    queryKey: ["structure", "matrix", symbol],
    queryFn: () =>
      api.get<StructureMatrixResponse>(`/api/structure/matrix?symbol=${encodeURIComponent(symbol)}`),
  });
}

export function useManipulationScores() {
  return useQuery({
    placeholderData: keepPreviousData,    queryKey: ["manipulation", "scores"],
    queryFn: () => api.get<ManipulationScore[]>("/api/v2/manipulation/scores"),
     select: (d) => unwrapList<ManipulationScore>(d),
  });
}

export function useManipulationCases() {
  return useQuery({
    placeholderData: keepPreviousData,    queryKey: ["manipulation", "cases"],
    queryFn: () => api.get<ManipulationCaseSummary[]>("/api/v2/manipulation/cases"),
     select: (d) => unwrapList<ManipulationCaseSummary>(d),
  });
}

export function useGrowthReports() {
  return useQuery({
    placeholderData: keepPreviousData,    queryKey: ["growth", "reports"],
    queryFn: () => api.get<GrowthReport[]>("/api/growth/reports"),
     select: (d) => unwrapList<GrowthReport>(d),
  });
}

export function useStrategyCandidates() {
  return useQuery({
    placeholderData: keepPreviousData,    queryKey: ["growth", "candidates"],
    queryFn: () => api.get<StrategyCandidate[]>("/api/growth/candidates"),
     select: (d) => unwrapList<StrategyCandidate>(d),
  });
}

export function useFailureClustering() {
  return useQuery({
    placeholderData: keepPreviousData,    queryKey: ["growth", "failure-summary"],
    queryFn: () => api.get<FailureClusteringResponse>("/api/growth/failure-summary"),
  });
}

export function useAIResearchRuns() {
  return useQuery({
    placeholderData: keepPreviousData,    queryKey: ["ai-research", "runs"],
    queryFn: () => api.get<AIResearchRun[]>("/api/ai-research/runs"),
     select: (d) => unwrapList<AIResearchRun>(d),
  });
}

export function useAgents() {
  return useQuery({
    placeholderData: keepPreviousData,    queryKey: ["agents", "list"],
    queryFn: () => api.get<AgentProfile[]>("/api/agents"),
     select: (d) => unwrapList<AgentProfile>(d),
  });
}

export function useStrategyRuns() {
  return useQuery({
    placeholderData: keepPreviousData,    queryKey: ["strategy-runs", "list"],
    queryFn: () => api.get<StrategyRunView[]>("/api/v2/strategy-runs"),
     select: (d) => unwrapList<StrategyRunView>(d),
  });
}

export function useAdminProviders() {
  return useQuery({
    placeholderData: keepPreviousData,    queryKey: ["admin", "providers"],
    queryFn: () => api.get<AdminProvider[]>("/api/admin/providers"),
     select: (d) => unwrapList<AdminProvider>(d),
  });
}

export function useSystemSettings() {
  return useQuery({
    placeholderData: keepPreviousData,    queryKey: ["admin", "system-settings"],
    queryFn: () => api.get<SystemSettingView[]>("/api/admin/system-settings"),
     select: (d) => unwrapList<SystemSettingView>(d),
  });
}

/* ---------- Provider CRUD ---------- */

export function useCreateProvider() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (body: Record<string, unknown>) => api.post<AdminProvider>("/api/admin/providers", body),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["admin", "providers"] }),
  });
}

export function useUpdateProvider() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, ...body }: { id: number } & Record<string, unknown>) =>
      api.put<AdminProvider>(`/api/admin/providers/${id}`, body),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["admin", "providers"] }),
  });
}

export function useDeleteProvider() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: number) => api.del(`/api/admin/providers/${id}`),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["admin", "providers"] }),
  });
}

export function useTestProvider() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: number) => api.post(`/api/admin/providers/${id}/test`),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["admin", "providers"] }),
  });
}

export function useToggleProvider() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, enable }: { id: number; enable: boolean }) =>
      api.post(`/api/admin/providers/${id}/${enable ? "enable" : "disable"}`),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["admin", "providers"] }),
  });
}

export function useSentimentMarket() {
  return useQuery({
    placeholderData: keepPreviousData,    queryKey: ["sentiment", "market"],
    queryFn: () => api.get<SentimentMarket>("/api/sentiment/market"),
  });
}

export function useRiskRules() {
  return useQuery({
    placeholderData: keepPreviousData,
    queryKey: ["risk", "rules"],
    queryFn: () => api.get<RiskRules>("/api/risk/rules"),
  });
}

export function useUpdateRiskRules() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (body: RiskRulesUpdate) => api.put<RiskRules>("/api/risk/rules", body),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["risk"] }),
  });
}

export function useUpdateSystemSetting() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ key, value, category }: { key: string; value: Record<string, unknown>; category: string }) =>
      api.put(`/api/admin/system-settings/${encodeURIComponent(key)}`, { value, category, updated_by: "web" }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["admin", "system-settings"] }),
  });
}

/* ---------- Trading Control ---------- */

export function useStartPaper() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (body: {
      strategy_version_id: string;
      symbols: string[];
      stake_amount: number;
      initial_wallet: number;
      max_open_trades: number;
      exchange: string;
    }) => api.post<TradingCommandResponse>("/api/trading/start-paper", body),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["live-readiness"] });
      qc.invalidateQueries({ queryKey: ["execution"] });
    },
  });
}

export function useStartLiveSmall() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (body: {
      strategy_version_id: string;
      capital_pool_id: string;
      exchange_name: string;
      human_confirmed: boolean;
      confirmed_by: string;
    }) => api.post<StartLiveSmallResponse>("/api/trading/start-live-small", body),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["live-readiness"] });
      qc.invalidateQueries({ queryKey: ["execution"] });
    },
  });
}

export function useDisableAuto() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (body: { reason: string }) =>
      api.post<DisableAutoResponse>("/api/trading/disable-auto", body),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["live-readiness"] });
      qc.invalidateQueries({ queryKey: ["execution"] });
      qc.invalidateQueries({ queryKey: ["dashboard"] });
    },
  });
}

/* ---------- Signal Actions ---------- */

export function useSignalDetail(id: string | null) {
  return useQuery({
    placeholderData: keepPreviousData,
    queryKey: ["signals", "detail", id],
    queryFn: () => api.get<Record<string, unknown>>(`/api/v2/signals/${id}`),
    enabled: !!id,
  });
}

export function useSignalNextActions(id: string | null) {
  return useQuery({
    placeholderData: keepPreviousData,
    queryKey: ["signals", "next-actions", id],
    queryFn: () => api.get<{ signal_id: string; status: string; next_actions: { type: string; enabled: boolean; label: string }[] }>(`/api/v2/signals/${id}/next-actions`),
    enabled: !!id,
  });
}

export function useSignalTransition() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, target_status, reason }: { id: string; target_status: string; reason?: string }) =>
      api.post(`/api/v2/signals/${id}/transition`, { target_status, reason }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["signals"] }),
  });
}

export function useSignalArchive() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => api.post(`/api/v2/signals/${id}/archive`),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["signals"] }),
  });
}

export function usePublishToStrategy() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => api.post(`/api/v2/signals/${id}/publish-to-strategy`),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["signals"] });
      qc.invalidateQueries({ queryKey: ["strategies"] });
    },
  });
}

export function useObservePaper() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => api.post(`/api/v2/signals/${id}/observe-paper`),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["signals"] }),
  });
}

/* ---------- Growth Candidate Actions ---------- */

export function useAdvanceCandidate() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => api.post(`/api/growth/candidates/${id}/advance`),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["growth"] }),
  });
}

export function useConfirmCandidate() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => api.post(`/api/growth/candidates/${id}/confirm`),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["growth"] });
      qc.invalidateQueries({ queryKey: ["strategies"] });
    },
  });
}

/* ---------- AI Research Actions ---------- */

export function useCreateResearchRun() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (body: { symbol: string; market?: string; analysis_date: string }) =>
      api.post<{ id: number }>("/api/ai-research/v2/runs", {
        market: "crypto",
        timeframe: "1d",
        ...body,
      }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["ai-research"] }),
  });
}

export function useExecuteResearchRun() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (runId: number) =>
      api.post(`/api/ai-research/v2/runs/${runId}/execute`),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["ai-research"] }),
  });
}

/* ---------- Strategy Workspace ---------- */

export function useStrategyWorkspace(strategyId: string | null) {
  return useQuery({
    placeholderData: keepPreviousData,
    queryKey: ["strategies", strategyId, "workspace"],
    queryFn: () => api.get<Record<string, unknown>>(`/api/v2/strategies/${strategyId}/workspace`),
    enabled: !!strategyId,
  });
}

export function useValidateDSL() {
  return useMutation({
    mutationFn: (dsl: Record<string, unknown>) =>
      api.post<{ valid: boolean; error_count: number; warning_count: number; errors: { code: string; path: string; message: string; severity: string }[]; warnings: { code: string; path: string; message: string; severity: string }[] }>(
        "/api/v2/strategies/validate-dsl", { dsl }
      ),
  });
}

/* ---------- Backtest Detail ---------- */

export function useBacktestDetail(backtestId: number | null) {
  return useQuery({
    placeholderData: keepPreviousData,
    queryKey: ["backtest", "detail", backtestId],
    queryFn: () => api.get<Record<string, unknown>>(`/api/v2/backtest/${backtestId}`),
    enabled: backtestId != null,
  });
}

/* ---------- Alert Rules ---------- */

export function useAlertRules() {
  return useQuery({
    placeholderData: keepPreviousData,
    queryKey: ["alert-rules"],
    queryFn: () => api.get<{ rules: Record<string, unknown>[] }>("/api/alert-rules"),
  });
}

export function useCreateAlertRule() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (body: Record<string, unknown>) => api.post("/api/alert-rules", body),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["alert-rules"] }),
  });
}

export function useUpdateAlertRule() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, ...body }: { id: string } & Record<string, unknown>) =>
      api.put(`/api/alert-rules/${id}`, body),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["alert-rules"] }),
  });
}

export function useDeleteAlertRule() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => api.del(`/api/alert-rules/${id}`),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["alert-rules"] }),
  });
}

export function useEvaluateAlertRules() {
  return useMutation({
    mutationFn: () => api.post("/api/alert-rules/evaluate"),
  });
}

/* ---------- Canvas AI Generation ---------- */

export interface CanvasAIResult {
  dsl: Record<string, unknown>;
  valid: boolean;
  error_count: number;
  warning_count: number;
  errors: { code: string; path: string; message: string; severity: string }[];
  warnings: { code: string; path: string; message: string; severity: string }[];
  llm_error: string | null;
}

export function useCanvasAIGenerate() {
  return useMutation({
    mutationFn: (body: { prompt: string; symbol?: string }) =>
      api.post<CanvasAIResult>("/api/canvas/ai-generate", body),
  });
}

/* ---------- Strategy Version Create ---------- */

export function useCreateVersion(strategyId: string | null) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (body: { rule_dsl: Record<string, unknown>; created_by?: string }) =>
      api.post(`/api/v2/strategies/${strategyId}/versions`, body),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["strategies"] });
      qc.invalidateQueries({ queryKey: ["strategies", strategyId, "workspace"] });
    },
  });
}

/* ---------- Strategy Version Status Transition ---------- */

export function useTransitionVersion(strategyId: string | null) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ versionId, toStatus }: { versionId: string; toStatus: string }) =>
      api.patch(`/api/v2/strategies/${strategyId}/versions/${versionId}/status`, { to_status: toStatus }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["strategies"] });
      qc.invalidateQueries({ queryKey: ["strategies", strategyId, "workspace"] });
    },
  });
}

/* ---------- Agent Platform ---------- */

export function useAgentRuntimes() {
  return useQuery({
    placeholderData: keepPreviousData,
    queryKey: ["agents", "runtimes"],
    queryFn: () =>
      api.get<{ runtimes: Record<string, { available: boolean; reason: string | null }> }>(
        "/api/agents/runtimes"
      ),
    staleTime: 60_000,
  });
}

export function useAgentTasks() {
  return useQuery({
    placeholderData: keepPreviousData,
    queryKey: ["agents", "tasks"],
    queryFn: () => api.get<{ tasks: AgentTask[] }>("/api/agents/tasks"),
    select: (d) => d.tasks ?? [],
    refetchInterval: 10_000,
  });
}

export function useCreateAgent() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (body: Record<string, unknown>) => api.post<AgentProfile>("/api/agents", body),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["agents"] }),
  });
}

export function useUpdateAgent() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, ...body }: { id: number } & Record<string, unknown>) =>
      api.put<AgentProfile>(`/api/agents/${id}`, body),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["agents"] }),
  });
}

export function useDeleteAgent() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: number) => api.del(`/api/agents/${id}`),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["agents"] }),
  });
}

export function useRunAgent() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, ...body }: { id: number; symbol?: string; prompt?: string }) =>
      api.post<{ task_id: string }>(`/api/agents/${id}/run`, body),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["agents"] }),
  });
}

export function useCreateDailyReview() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (days: number) =>
      api.post("/api/growth/reports/daily-review", { days }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["growth"] }),
  });
}
