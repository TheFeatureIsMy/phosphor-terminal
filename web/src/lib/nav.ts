import {
  Activity,
  BarChart3,
  Brain,
  Cpu,
  Grid3x3,
  History,
  LayoutGrid,
  ListOrdered,
  OctagonX,
  PlayCircle,
  Radio,
  RefreshCcw,
  Link2,
  Server,
  Settings,
  Shield,
  ShieldAlert,
  ShieldCheck,
  Table2,
  TrendingUp,
  Users,
  Wand2,
  Zap,
  type LucideIcon,
} from "lucide-react";

export interface AppRoute {
  id: string;
  path: string;
  label: string;
  icon: LucideIcon;
  shortcut?: number;
  implemented?: boolean;
}

export interface NavGroup {
  label: string;
  routes: AppRoute[];
}

export const NAV_GROUPS: NavGroup[] = [
  {
    label: "概览",
    routes: [
      { id: "dashboard", path: "/", label: "总览控制台", icon: LayoutGrid, shortcut: 1, implemented: true },
      { id: "liveReadiness", path: "/live-readiness", label: "实盘准入", icon: ShieldCheck, shortcut: 2 },
    ],
  },
  {
    label: "策略",
    routes: [
      { id: "strategyWorkspace", path: "/strategy", label: "策略工作台", icon: Cpu, shortcut: 3 },
      { id: "backtestSimulation", path: "/backtest", label: "回测 / 模拟", icon: History, shortcut: 4 },
    ],
  },
  {
    label: "结构",
    routes: [
      { id: "marketStructure", path: "/market-structure", label: "市场结构", icon: BarChart3, shortcut: 5 },
      { id: "structureMatrix", path: "/structure-matrix", label: "结构矩阵", icon: Table2, shortcut: 6 },
      { id: "manipulationRadar", path: "/manipulation", label: "操纵雷达", icon: ShieldAlert, shortcut: 7 },
    ],
  },
  {
    label: "执行",
    routes: [
      { id: "executionCenter", path: "/execution", label: "执行中心", icon: PlayCircle, shortcut: 8 },
      { id: "ordersPositions", path: "/orders", label: "订单 / 持仓", icon: ListOrdered, shortcut: 9 },
      { id: "reconciliationBus", path: "/reconciliation", label: "对账总线", icon: RefreshCcw },
    ],
  },
  {
    label: "风控",
    routes: [
      { id: "riskCenter", path: "/risk", label: "风控中心", icon: Shield },
      { id: "stopProtection", path: "/stop-protection", label: "止损保护", icon: OctagonX },
      { id: "circuitBreakers", path: "/circuit-breakers", label: "熔断记录", icon: Zap },
    ],
  },
  {
    label: "AI 研究",
    routes: [
      { id: "aiResearchRoom", path: "/ai-research", label: "AI 投研室", icon: Brain },
      { id: "agentPlatform", path: "/agent-platform", label: "Agent 平台", icon: Users },
      { id: "signalCenter", path: "/signals", label: "信号中心", icon: Radio, implemented: true },
      { id: "marketSentiment", path: "/sentiment", label: "市场情绪", icon: Activity },
    ],
  },
  {
    label: "成长",
    routes: [
      { id: "growthReview", path: "/growth", label: "成长复盘", icon: TrendingUp },
      { id: "failureClustering", path: "/failure-clustering", label: "失败聚类", icon: Grid3x3 },
      { id: "strategyOptimization", path: "/optimization", label: "策略优化", icon: Wand2 },
    ],
  },
  {
    label: "系统",
    routes: [
      { id: "connections", path: "/connections", label: "连接", icon: Link2 },
      { id: "serviceManagement", path: "/services", label: "服务管理", icon: Server },
      { id: "systemSettings", path: "/settings", label: "系统设置", icon: Settings },
    ],
  },
];

export const ALL_ROUTES: AppRoute[] = NAV_GROUPS.flatMap((g) => g.routes);

export function routeByPath(pathname: string): AppRoute {
  return (
    ALL_ROUTES.find((r) => r.path === pathname) ??
    ALL_ROUTES.find((r) => r.id === "dashboard")!
  );
}