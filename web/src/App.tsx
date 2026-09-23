import { useEffect, useState } from "react";
import { BrowserRouter, Route, Routes, useNavigate } from "react-router-dom";
import { Sidebar } from "@/components/shell/Sidebar";
import { GlobalStatusBar } from "@/components/shell/GlobalStatusBar";
import { CommandPalette } from "@/components/shell/CommandPalette";
import { PageHeader } from "@/components/shell/PageHeader";
import { ErrorBoundary } from "@/components/shell/ErrorBoundary";
import { LandingPage } from "@/pages/Landing/LandingPage";
import { useLocation } from "react-router-dom";
import { ALL_ROUTES } from "@/lib/nav";
import DashboardPage from "@/pages/Dashboard/DashboardPage";
import SignalCenterPage from "@/pages/SignalCenter/SignalCenterPage";
import ExecutionCenterPage from "@/pages/Execution/ExecutionCenterPage";
import OrdersPositionsPage from "@/pages/Execution/OrdersPositionsPage";
import ReconciliationBusPage from "@/pages/Execution/ReconciliationBusPage";
import RiskCenterPage from "@/pages/Risk/RiskCenterPage";
import StopProtectionPage from "@/pages/Risk/StopProtectionPage";
import CircuitBreakersPage from "@/pages/Risk/CircuitBreakersPage";
import LiveReadinessPage from "@/pages/LiveReadiness/LiveReadinessPage";
import MarketStructurePage from "@/pages/Structure/MarketStructurePage";
import StructureMatrixPage from "@/pages/Structure/StructureMatrixPage";
import ManipulationRadarPage from "@/pages/Manipulation/ManipulationRadarPage";
import GrowthReviewPage from "@/pages/Growth/GrowthReviewPage";
import FailureClusteringPage from "@/pages/Growth/FailureClusteringPage";
import StrategyOptimizationPage from "@/pages/Growth/StrategyOptimizationPage";
import AIResearchRoomPage from "@/pages/AIStudio/AIResearchRoomPage";
import AgentPlatformPage from "@/pages/AgentPlatform/AgentPlatformPage";
import MarketSentimentPage from "@/pages/Sentiment/MarketSentimentPage";
import BacktestSimulationPage from "@/pages/Backtest/BacktestSimulationPage";
import { ServiceManagementPage, DataSourcesPage } from "@/pages/System/SystemPages";
import SystemSettingsPage from "@/pages/Settings/SystemSettingsPage";
import StrategyWorkspacePage from "@/pages/StrategyWorkspace/StrategyWorkspacePage";

const EXTRA_ROUTES: Record<string, () => React.JSX.Element> = {
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
  dataSourceManagement: DataSourcesPage,
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
            <Routes>
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
            </ErrorBoundary>
          </main>
        </div>
      </div>
      <CommandPalette open={paletteOpen} onClose={() => setPaletteOpen(false)} />
    </>
  );
}

export default function App() {
  // 启动过渡页(每次会话一次)
  const [launched, setLaunched] = useState(
    () => sessionStorage.getItem("alphaloop-launched") === "1"
  );
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
  return (
    <BrowserRouter>
      <Shell />
    </BrowserRouter>
  );
}