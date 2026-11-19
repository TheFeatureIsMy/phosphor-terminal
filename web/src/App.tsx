import { lazy, Suspense, useEffect, useState, type ComponentType } from "react";
import { BrowserRouter, Navigate, Route, Routes, useNavigate } from "react-router-dom";
import { Sidebar } from "@/components/shell/Sidebar";
import { GlobalStatusBar } from "@/components/shell/GlobalStatusBar";
import { CommandPalette } from "@/components/shell/CommandPalette";
import { PageHeader } from "@/components/shell/PageHeader";
import { ErrorBoundary } from "@/components/shell/ErrorBoundary";
import { LandingPage } from "@/pages/Landing/LandingPage";
import { InviteAcceptPage, LoginPage } from "@/features/auth";
import { getAuthToken } from "@/lib/api";
import { useLocation } from "react-router-dom";
import { ALL_ROUTES } from "@/lib/nav";
import DesignPreviews from "@/pages/Previews/DesignPreviews";

const DashboardPage = lazy(() =>
  import("@/features/dashboard").then((m) => ({ default: m.DashboardPage }))
);
const SignalCenterPage = lazy(() =>
  import("@/features/signal-center").then((m) => ({ default: m.SignalCenterPage }))
);
const ExecutionCenterPage = lazy(() =>
  import("@/features/execution").then((m) => ({ default: m.ExecutionCenterPage }))
);
const OrdersPositionsPage = lazy(() =>
  import("@/features/execution").then((m) => ({ default: m.OrdersPositionsPage }))
);
const ReconciliationBusPage = lazy(() =>
  import("@/features/execution").then((m) => ({ default: m.ReconciliationBusPage }))
);
const RiskCenterPage = lazy(() =>
  import("@/features/risk").then((m) => ({ default: m.RiskCenterPage }))
);
const StopProtectionPage = lazy(() =>
  import("@/features/risk").then((m) => ({ default: m.StopProtectionPage }))
);
const CircuitBreakersPage = lazy(() =>
  import("@/features/risk").then((m) => ({ default: m.CircuitBreakersPage }))
);
const LiveReadinessPage = lazy(() =>
  import("@/features/live-readiness").then((m) => ({ default: m.LiveReadinessPage }))
);
const MarketStructurePage = lazy(() =>
  import("@/features/structure").then((m) => ({ default: m.MarketStructurePage }))
);
const StructureMatrixPage = lazy(() =>
  import("@/features/structure").then((m) => ({ default: m.StructureMatrixPage }))
);
const ManipulationRadarPage = lazy(() =>
  import("@/features/manipulation").then((m) => ({ default: m.ManipulationRadarPage }))
);
const GrowthReviewPage = lazy(() =>
  import("@/features/growth").then((m) => ({ default: m.GrowthReviewPage }))
);
const FailureClusteringPage = lazy(() =>
  import("@/features/growth").then((m) => ({ default: m.FailureClusteringPage }))
);
const StrategyOptimizationPage = lazy(() =>
  import("@/features/growth").then((m) => ({ default: m.StrategyOptimizationPage }))
);
const AIResearchRoomPage = lazy(() =>
  import("@/features/ai-studio").then((m) => ({ default: m.AIResearchRoomPage }))
);
const AgentPlatformPage = lazy(() =>
  import("@/features/agent-platform").then((m) => ({ default: m.AgentPlatformPage }))
);
const MarketSentimentPage = lazy(() =>
  import("@/features/sentiment").then((m) => ({ default: m.MarketSentimentPage }))
);
const BacktestSimulationPage = lazy(() =>
  import("@/features/backtest").then((m) => ({ default: m.BacktestSimulationPage }))
);
const ServiceManagementPage = lazy(() =>
  import("@/features/system").then((m) => ({ default: m.ServiceManagementPage }))
);
const SystemSettingsPage = lazy(() =>
  import("@/features/settings").then((m) => ({ default: m.SystemSettingsPage }))
);
const ConnectionsPage = lazy(() =>
  import("@/features/settings").then((m) => ({ default: m.ConnectionsPage }))
);
const StrategyWorkspacePage = lazy(() =>
  import("@/features/strategy-workspace").then((m) => ({ default: m.StrategyWorkspacePage }))
);

function PageLoader() {
  return (
    <div className="flex h-full items-center justify-center text-text-3">
      <span className="font-mono text-[11px] tracking-[0.2em]">LOADING…</span>
    </div>
  );
}

const EXTRA_ROUTES: Record<string, ComponentType> = {
  executionCenter: ExecutionCenterPage,
  ordersPositions: OrdersPositionsPage,
  reconciliationBus: ReconciliationBusPage,
  riskCenter: RiskCenterPage,
  stopProtection: StopProtectionPage,
  circuitBreakers: CircuitBreakersPage,
  liveReadiness: LiveReadinessPage,
  marketStructure: MarketStructurePage,
  structureMatrix: StructureMatrixPage,
  manipulationRadar: ManipulationRadarPage,
  growthReview: GrowthReviewPage,
  failureClustering: FailureClusteringPage,
  strategyOptimization: StrategyOptimizationPage,
  aiResearchRoom: AIResearchRoomPage,
  agentPlatform: AgentPlatformPage,
  marketSentiment: MarketSentimentPage,
  backtestSimulation: BacktestSimulationPage,
  serviceManagement: ServiceManagementPage,
  connections: ConnectionsPage,
  systemSettings: SystemSettingsPage,
  strategyWorkspace: StrategyWorkspacePage,
};

/** 全量阶段前的占位页 */
function PlaceholderPage({ title }: { title: string }) {
  return (
    <div className="mx-auto w-full max-w-[1340px] px-7 py-6">
      <PageHeader eyebrow="COMING SOON" title={title} subtitle="该页面将在全量迁移阶段交付" />
    </div>
  );
}

function Shell() {
  const [paletteOpen, setPaletteOpen] = useState(false);
  const navigate = useNavigate();
  const { pathname } = useLocation();
  const [entered, setEntered] = useState(
    () => sessionStorage.getItem("alphaloop-launched") === "1"
  );
  useEffect(() => {
    if (!entered) {
      const t = window.setTimeout(() => setEntered(true), 30);
      return () => window.clearTimeout(t);
    }
  }, [entered]);

  useEffect(() => {
    const down = (e: KeyboardEvent) => {
      if (e.key === "k" && (e.metaKey || e.ctrlKey)) {
        e.preventDefault();
        setPaletteOpen((v) => !v);
        return;
      }
      // ⌘1-9 页面切换(带 shortcut 的路由)
      if ((e.metaKey || e.ctrlKey) && e.key >= "1" && e.key <= "9") {
        const idx = parseInt(e.key, 10);
        const target = ALL_ROUTES.find((r) => r.shortcut === idx);
        if (target) {
          e.preventDefault();
          navigate(target.path);
        }
      }
    };
    document.addEventListener("keydown", down);
    return () => document.removeEventListener("keydown", down);
  }, [navigate]);

  return (
    <>
      <div
        className="flex h-full bg-bg text-text transition-opacity duration-400 ease-out"
        style={{ opacity: entered ? 1 : 0 }}
      >
        <Sidebar />
        <div className="flex min-w-0 flex-1 flex-col">
          <GlobalStatusBar onOpenPalette={() => setPaletteOpen(true)} />
          <main className="terminal-grid flex min-h-0 flex-1 flex-col overflow-y-auto">
            <ErrorBoundary resetKey={pathname}>
            <Suspense fallback={<PageLoader />}>
            <Routes>
              <Route path="/data-sources" element={<Navigate to="/connections" replace />} />
              <Route path="/" element={<DashboardPage />} />
              <Route path="/signals" element={<SignalCenterPage />} />
              {ALL_ROUTES.filter(
                (r) => r.id !== "dashboard" && r.id !== "signalCenter"
              ).map((r) => {
                const Impl = EXTRA_ROUTES[r.id];
                return (
                  <Route
                    key={r.id}
                    path={r.path}
                    element={Impl ? <Impl /> : <PlaceholderPage title={r.label} />}
                  />
                );
              })}
            </Routes>
            </Suspense>
            </ErrorBoundary>
          </main>
        </div>
      </div>
      <CommandPalette open={paletteOpen} onClose={() => setPaletteOpen(false)} />
    </>
  );
}

function AppFrame() {
  const { pathname } = useLocation();
  if (pathname.startsWith("/previews")) return <DesignPreviews />;
  return <Shell />;
}

export default function App() {
  const preview = window.location.pathname.startsWith("/previews");
  const [launched, setLaunched] = useState(
    () => preview || sessionStorage.getItem("alphaloop-launched") === "1"
  );
  const [authed, setAuthed] = useState(() => Boolean(getAuthToken()));

  useEffect(() => {
    const onUnauthorized = () => setAuthed(false);
    window.addEventListener("alphaloop:unauthorized", onUnauthorized);
    return () => window.removeEventListener("alphaloop:unauthorized", onUnauthorized);
  }, []);

  const inviteToken = new URLSearchParams(window.location.search).get("invite_token");
  if (inviteToken) {
    return (
      <InviteAcceptPage
        token={inviteToken}
        onDone={() => {
          window.history.replaceState({}, "", "/");
          setLaunched(true);
          setAuthed(false);
        }}
      />
    );
  }

  if (!launched) {
    return (
      <LandingPage
        onDone={() => {
          sessionStorage.setItem("alphaloop-launched", "1");
          setLaunched(true);
        }}
      />
    );
  }
  if (!authed) {
    return <LoginPage onSuccess={() => setAuthed(true)} />;
  }
  return (
    <BrowserRouter>
      <AppFrame />
    </BrowserRouter>
  );
}