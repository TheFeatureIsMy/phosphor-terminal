import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  Background,
  BackgroundVariant,
  Controls,
  MiniMap,
  ReactFlow,
  addEdge,
  useEdgesState,
  useNodesState,
  type Connection,
  type Edge,
  type EdgeTypes,
  type Node,
  type NodeTypes,
} from "@xyflow/react";
import "@xyflow/react/dist/style.css";
import { Plus, Save, Send, Sparkles, Trash2 } from "lucide-react";
import { SignalInputNode } from "@/canvas/nodes/SignalInputNode";
import { IndicatorConditionNode } from "@/canvas/nodes/IndicatorConditionNode";
import { FilterNode } from "@/canvas/nodes/FilterNode";
import { PositionSizingNode } from "@/canvas/nodes/PositionSizingNode";
import { RiskPolicyNode } from "@/canvas/nodes/RiskPolicyNode";
import { ExecutionOutputNode } from "@/canvas/nodes/ExecutionOutputNode";
import StructureDefenseNode from "@/canvas/nodes/StructureDefenseNode";
import AccountRiskNode from "@/canvas/nodes/AccountRiskNode";
import MTFGuardNode from "@/canvas/nodes/MTFGuardNode";
import { SentimentNewsNode, TrendingNode, FundingNode, OnchainNode } from "@/canvas/nodes/AltDataNodes";
import { CircuitBreakerNode, StructureSignalNode, AIGrowthNode } from "@/canvas/nodes/PlatformNodes";
import MTFGuardEdge from "@/canvas/edges/MTFGuardEdge";
import { dslToGraph } from "@/canvas/converters/dslToGraph";
import { graphToDsl } from "@/canvas/converters/graphToDsl";
import { useCanvasAIGenerate, useValidateDSL } from "@/lib/hooks";
import { cn } from "@/lib/utils";
import "@/canvas/styles/nodes.css";
import "@/canvas/styles/volt-canvas.css";

const nodeTypes: NodeTypes = {
  signalInput: SignalInputNode,
  indicatorCondition: IndicatorConditionNode,
  filter: FilterNode,
  positionSizing: PositionSizingNode,
  riskPolicy: RiskPolicyNode,
  executionOutput: ExecutionOutputNode,
  structureDefense: StructureDefenseNode,
  accountRisk: AccountRiskNode,
  mtfGuard: MTFGuardNode,
  sentimentNews: SentimentNewsNode,
  trending: TrendingNode,
  funding: FundingNode,
  onchain: OnchainNode,
  circuitBreaker: CircuitBreakerNode,
  structureSignal: StructureSignalNode,
  aiGrowth: AIGrowthNode,
};

const edgeTypes: EdgeTypes = {
  mtfGuard: MTFGuardEdge,
};

/* 节点调色板：点击添加到画布 */
const PALETTE: { type: string; label: string; make: () => Node }[] = [
  {
    type: "signalInput",
    label: "信号输入",
    make: () => ({
      id: `n_${Date.now()}_sig`,
      type: "signalInput",
      position: { x: 40, y: 220 },
      data: { timeframe: "1d", symbols: ["BTC/USDT"] },
    }),
  },
  {
    type: "indicatorCondition",
    label: "指标条件",
    make: () => ({
      id: `n_${Date.now()}_ind`,
      type: "indicatorCondition",
      position: { x: 300, y: 100 },
      data: { ruleType: "indicator_threshold", indicator: "rsi", params: { period: 14 }, operator: "<", value: 30 },
    }),
  },
  {
    type: "filter",
    label: "过滤器",
    make: () => ({
      id: `n_${Date.now()}_flt`,
      type: "filter",
      position: { x: 300, y: 300 },
      data: { ruleType: "manipulation_score", maxScore: 0.5 },
    }),
  },
  {
    type: "positionSizing",
    label: "仓位",
    make: () => ({
      id: `n_${Date.now()}_pos`,
      type: "positionSizing",
      position: { x: 560, y: 100 },
      data: { type: "fixed_pct", positionPct: 0.05 },
    }),
  },
  {
    type: "riskPolicy",
    label: "风控",
    make: () => ({
      id: `n_${Date.now()}_risk`,
      type: "riskPolicy",
      position: { x: 560, y: 300 },
      data: { stoploss: -0.05, maxOpenTrades: 3, trailingStop: false },
    }),
  },
  {
    type: "executionOutput",
    label: "执行输出",
    make: () => ({
      id: `n_${Date.now()}_out`,
      type: "executionOutput",
      position: { x: 820, y: 200 },
      data: { entryLogic: "AND", exitLogic: "AND", schemaVersion: "2.5" },
    }),
  },
  {
    type: "structureDefense",
    label: "结构防御",
    make: () => ({
      id: `n_${Date.now()}_struct`,
      type: "structureDefense",
      position: { x: 300, y: 480 },
      data: { structures: ["liquidity_pool", "fvg"], minStructureScore: 70 },
    }),
  },
  {
    type: "accountRisk",
    label: "账户风控",
    make: () => ({
      id: `n_${Date.now()}_acct`,
      type: "accountRisk",
      position: { x: 560, y: 480 },
      data: { maxDailyLoss: 0.03, maxWeeklyLoss: 0.08, maxConsecutiveLosses: 4 },
    }),
  },
  {
    type: "sentimentNews",
    label: "情绪/新闻",
    make: () => ({
      id: `n_${Date.now()}_sent`,
      type: "sentimentNews",
      position: { x: 60, y: 480 },
      data: { ruleType: "sentiment_filter", source: "combined", minSentiment: 0, requirePositive: false },
    }),
  },
  {
    type: "trending",
    label: "热点/趋势",
    make: () => ({
      id: `n_${Date.now()}_trend`,
      type: "trending",
      position: { x: 60, y: 640 },
      data: { ruleType: "news_heat_filter", minHeatScore: 50, keywords: [] },
    }),
  },
  {
    type: "funding",
    label: "资金费率",
    make: () => ({
      id: `n_${Date.now()}_fund`,
      type: "funding",
      position: { x: 1080, y: 480 },
      data: { ruleType: "funding_filter", maxFundingRate: 0.0001, avoidCrowded: true },
    }),
  },
  {
    type: "onchain",
    label: "链上/巨鲸",
    make: () => ({
      id: `n_${Date.now()}_onch`,
      type: "onchain",
      position: { x: 1080, y: 640 },
      data: { ruleType: "onchain_filter", whaleThreshold: 1000000, requireInflow: false },
    }),
  },
  {
    type: "circuitBreaker",
    label: "熔断保护",
    make: () => ({
      id: `n_${Date.now()}_cb`,
      type: "circuitBreaker",
      position: { x: 1080, y: 800 },
      data: { ruleType: "circuit_breaker_filter", blockWhenTripped: true, respectKillSwitch: true },
    }),
  },
  {
    type: "structureSignal",
    label: "结构信号",
    make: () => ({
      id: `n_${Date.now()}_ssig`,
      type: "structureSignal",
      position: { x: 60, y: 800 },
      data: { ruleType: "structure_signal_filter", structureType: "liquidity_pool", minScore: 70, requireFresh: true },
    }),
  },
  {
    type: "aiGrowth",
    label: "AI 成长",
    make: () => ({
      id: `n_${Date.now()}_grow`,
      type: "aiGrowth",
      position: { x: 560, y: 800 },
      data: { ruleType: "ai_growth_filter", mode: "winning_pattern", minConfidence: 0.6 },
    }),
  },
  {
    type: "mtfGuard",
    label: "多周期守卫",
    make: () => ({
      id: `n_${Date.now()}_mtf`,
      type: "mtfGuard",
      position: { x: 820, y: 480 },
      data: {
        guardId: `guard_${Date.now()}`,
        name: "HTF Guard",
        fastTimeframe: "1h",
        slowTimeframe: "4h",
        sourceNode: "",
        targetNode: "",
        structureType: "fvg",
        shadowWindow: { mode: "shadow", maxFastCandles: 3, allowLowTfTouch: true, allowLowTfUpdateFilledRatio: false },
        violationPolicy: { temporaryViolation: "hold", reclaimPending: "hold", confirmedReclaim: "allow", confirmedBreak: "block" },
      },
    }),
  },
];

interface ChatMsg {
  role: "user" | "ai";
  text: string;
}

/* 计算从某节点出发的上游+下游链路（流水追踪） */
function computeFlowPath(nodeId: string, edges: Edge[]): { nodeIds: Set<string>; edgeIds: Set<string> } {
  const nodeIds = new Set<string>([nodeId])
  const edgeIds = new Set<string>()
  // 下游：从该节点出发能到达的
  const downQueue = [nodeId]
  while (downQueue.length) {
    const cur = downQueue.shift()!
    for (const e of edges) {
      if (e.source === cur) {
        edgeIds.add(e.id)
        if (!nodeIds.has(e.target)) { nodeIds.add(e.target); downQueue.push(e.target) }
      }
    }
  }
  // 上游：能到达该节点的
  const upQueue = [nodeId]
  while (upQueue.length) {
    const cur = upQueue.shift()!
    for (const e of edges) {
      if (e.target === cur) {
        edgeIds.add(e.id)
        if (!nodeIds.has(e.source)) { nodeIds.add(e.source); upQueue.push(e.source) }
      }
    }
  }
  return { nodeIds, edgeIds }
}

export function CanvasEditor({
  initialDsl,
  onSave,
}: {
  initialDsl: Record<string, unknown> | null;
  onSave?: (dsl: Record<string, unknown>) => void;
}) {
  const initial = initialDsl ? dslToGraph(initialDsl as never) : { nodes: [], edges: [] };
  const [nodes, setNodes, onNodesChange] = useNodesState(initial.nodes);
  const [edges, setEdges, onEdgesChange] = useEdgesState(initial.edges);

  // initialDsl 是异步加载的:mount 时常为 null,数据就绪后才变为真实 DSL。
  // useNodesState 只在 mount 取初值,因此需要在 initialDsl 首次就绪时初始化画布。
  // 用引用比较:仅当换成另一份 DSL(切策略/新版本)时才重置,避免覆盖画布上的编辑。
  const lastDslRef = useRef<unknown>(null);
  useEffect(() => {
    if (!initialDsl) return;
    if (lastDslRef.current === initialDsl) return;
    lastDslRef.current = initialDsl;
    const g = dslToGraph(initialDsl as never);
    setNodes(g.nodes);
    setEdges(g.edges);
  }, [initialDsl, setNodes, setEdges]);
  const [showAI, setShowAI] = useState(false);
  const [saveMsg, setSaveMsg] = useState("");
  const [tracedNodeId, setTracedNodeId] = useState<string | null>(null);
  const validate = useValidateDSL();

  // 选中的节点（供 AI 修改）
  const selectedNodes = useMemo(() => nodes.filter((n) => n.selected), [nodes]);

  // 流水追踪：点击节点时高亮上下游链路
  const traced = useMemo(() => {
    if (!tracedNodeId) return null
    return computeFlowPath(tracedNodeId, edges)
  }, [tracedNodeId, edges])

  const tracedNodes = useMemo(() => {
    if (!traced) return nodes
    return nodes.map((n) => ({ ...n, className: traced.nodeIds.has(n.id) ? "flow-traced" : "flow-dimmed" }))
  }, [nodes, traced])

  const tracedEdges = useMemo(() => {
    if (!traced) return edges
    return edges.map((e) => ({
      ...e,
      animated: traced.edgeIds.has(e.id),
      className: traced.edgeIds.has(e.id) ? "flow-traced-edge" : "flow-dimmed-edge",
    }))
  }, [edges, traced])

  const onConnect = useCallback(
    (conn: Connection) => setEdges((eds) => addEdge({ ...conn, id: `e_${conn.source}_${conn.target}` }, eds)),
    [setEdges]
  );

  const addNode = (make: () => Node) => {
    setNodes((ns) => [...ns, make()]);
  };

  const deleteSelected = () => {
    setNodes((ns) => ns.filter((n) => !n.selected));
    setEdges((eds) => eds.filter((e) => !e.selected));
  };

  const handleSave = () => {
    setSaveMsg("");
    const result = graphToDsl(nodes, edges);
    if (!result.dsl) {
      setSaveMsg(`无法保存: ${result.errors.map((e) => e.message).join("; ")}`);
      return;
    }
    validate.mutate(result.dsl as unknown as Record<string, unknown>, {
      onSuccess: (v) => {
        if (v.valid) {
          onSave?.(result.dsl as unknown as Record<string, unknown>);
          setSaveMsg("已保存为草稿版本");
        } else {
          setSaveMsg(`DSL 有 ${v.error_count} 个错误，未保存`);
        }
      },
    });
  };

  return (
    <div className="flex h-full">
      {/* 左侧节点调色板 */}
      <div className="flex w-[150px] shrink-0 flex-col gap-1.5 overflow-y-auto border-r border-border p-3">
        {/* AI 入口（顶部醒目） */}
        <button
          onClick={() => setShowAI((v) => !v)}
          className={cn(
            "mb-1 flex w-full items-center justify-center gap-2 rounded-lg px-2.5 py-2.5 text-[12px] font-semibold transition-all",
            showAI
              ? "bg-accent text-on-accent shadow-[0_0_12px_-2px_var(--glow-accent)]"
              : "bg-accent/12 text-accent-text hover:bg-accent/20"
          )}
        >
          <Sparkles className="size-4" />
          AI 助手
        </button>
        <div className="mb-1 mt-1 font-mono text-[10px] font-semibold uppercase tracking-[0.1em] text-text-3">
          节点
        </div>
        {PALETTE.map((p) => (
          <button
            key={p.type}
            onClick={() => addNode(p.make)}
            className="flex items-center gap-2 rounded-lg border border-border bg-surface px-2.5 py-2 text-left text-[12px] font-medium text-text-2 transition-colors hover:border-accent-text/40 hover:text-text"
          >
            <Plus className="size-3 shrink-0 text-accent-text" />
            {p.label}
          </button>
        ))}
        <div className="mt-2 border-t border-border/40 pt-2">
          <button
            onClick={deleteSelected}
            className="flex w-full items-center gap-2 rounded-lg px-2.5 py-2 text-left text-[12px] font-medium text-text-3 transition-colors hover:bg-bear/10 hover:text-bear"
          >
            <Trash2 className="size-3 shrink-0" />
            删除选中
          </button>
        </div>
        <div className="mt-auto space-y-1.5 border-t border-border/40 pt-2">
          <button
            onClick={handleSave}
            disabled={validate.isPending}
            className="flex w-full items-center justify-center gap-2 rounded-lg bg-accent px-2.5 py-2 text-[12px] font-semibold text-on-accent transition-colors hover:bg-accent-light disabled:opacity-50"
          >
            <Save className="size-3.5" />
            {validate.isPending ? "校验中…" : "保存"}
          </button>
        </div>
        {saveMsg && (
          <div className="rounded-lg bg-accent-soft px-2 py-1.5 text-[11px] font-medium text-accent-text">
            {saveMsg}
          </div>
        )}
      </div>

      {/* 画布 */}
      <div className="volt-canvas min-w-0 flex-1">
        <ReactFlow
          nodes={tracedNodes}
          edges={tracedEdges}
          nodeTypes={nodeTypes}
          edgeTypes={edgeTypes}
          onNodesChange={onNodesChange}
          onEdgesChange={onEdgesChange}
          onConnect={onConnect}
          onNodeClick={(_, node) => setTracedNodeId((cur) => (cur === node.id ? null : node.id))}
          onPaneClick={() => setTracedNodeId(null)}
          fitView
          deleteKeyCode={["Backspace", "Delete"]}
          proOptions={{ hideAttribution: true }}
        >
          <Background variant={BackgroundVariant.Dots} gap={22} size={1} color="var(--border)" />
          <Controls position="bottom-left" />
          <MiniMap position="bottom-right" pannable zoomable />
        </ReactFlow>
      </div>

      {/* 右侧 AI 对话面板 */}
      {showAI && (
        <AIPanel
          selectedCount={selectedNodes.length}
          onGenerated={(dsl) => {
            const g = dslToGraph(dsl as never);
            setNodes(g.nodes);
            setEdges(g.edges);
          }}
          onModifySelected={(prompt) => {
            // AI 修改选中节点：把选中节点数据 + 提示发给后端，返回修改后的 DSL
            setSaveMsg(`AI 修改选中 ${selectedNodes.length} 节点: ${prompt}`);
          }}
        />
      )}
    </div>
  );
}

/* ---------- AI 对话面板（生成 + 修改选中） ---------- */

function AIPanel({
  selectedCount,
  onGenerated,
  onModifySelected,
}: {
  selectedCount: number;
  onGenerated: (dsl: Record<string, unknown>) => void;
  onModifySelected: (prompt: string) => void;
}) {
  const generate = useCanvasAIGenerate();
  const [messages, setMessages] = useState<ChatMsg[]>([]);
  const [input, setInput] = useState("");
  const [symbol, setSymbol] = useState("BTC/USDT");
  const [mode, setMode] = useState<"generate" | "modify">("generate");
  const scrollRef = useRef<HTMLDivElement>(null);

  const canModify = mode === "modify" && selectedCount > 0;

  const send = () => {
    const prompt = input.trim();
    if (!prompt || generate.isPending) return;
    setInput("");
    setMessages((m) => [...m, { role: "user", text: prompt }]);

    if (mode === "modify") {
      onModifySelected(prompt);
      setMessages((m) => [...m, { role: "ai", text: `已发送修改指令，影响 ${selectedCount} 个选中节点。` }]);
      setTimeout(() => scrollRef.current?.scrollTo({ top: 99999, behavior: "smooth" }), 50);
      return;
    }

    generate.mutate(
      { prompt, symbol },
      {
        onSuccess: (res) => {
          const status = res.valid
            ? `已生成有效策略 DSL（${res.warning_count} 个警告），已渲染到画布。`
            : `生成的 DSL 有 ${res.error_count} 个错误：${res.errors.map((e) => e.message).join("; ")}`;
          setMessages((m) => [...m, { role: "ai", text: status }]);
          onGenerated(res.dsl);
          setTimeout(() => scrollRef.current?.scrollTo({ top: 99999, behavior: "smooth" }), 50);
        },
        onError: (e) => {
          setMessages((m) => [...m, { role: "ai", text: `生成失败: ${e instanceof Error ? e.message : "未知错误"}` }]);
        },
      }
    );
  };

  return (
    <div className="flex w-[320px] shrink-0 flex-col border-l border-border bg-card">
      {/* 头部 + 模式切换 */}
      <div className="border-b border-border px-4 py-3">
        <div className="flex items-center gap-2">
          <Sparkles className="size-4 text-accent-text" />
          <span className="text-[13px] font-semibold text-text">AI 策略助手</span>
        </div>
        <div className="mt-2.5 flex gap-1 rounded-lg bg-surface p-0.5">
          <button
            onClick={() => setMode("generate")}
            className={cn(
              "flex-1 rounded-md px-2.5 py-1.5 text-[11.5px] font-semibold transition-colors",
              mode === "generate" ? "bg-accent-soft text-accent-text" : "text-text-3 hover:text-text"
            )}
          >
            生成策略
          </button>
          <button
            onClick={() => setMode("modify")}
            className={cn(
              "flex-1 rounded-md px-2.5 py-1.5 text-[11.5px] font-semibold transition-colors",
              mode === "modify" ? "bg-accent-soft text-accent-text" : "text-text-3 hover:text-text"
            )}
          >
            修改选中 {selectedCount > 0 && `(${selectedCount})`}
          </button>
        </div>
      </div>

      {/* 对话流 */}
      <div ref={scrollRef} className="flex-1 space-y-2.5 overflow-y-auto p-3">
        {messages.length === 0 && (
          <div className="rounded-lg bg-surface p-3 text-[12px] leading-relaxed text-text-2">
            {mode === "generate" ? (
              <>
                用自然语言描述你的策略，例如：
                <div className="mt-2 rounded bg-card p-2 font-mono text-[11px] text-text-3">
                  "当 RSI 低于 30 时买入 BTC，高于 70 卖出，止损 5%"
                </div>
                AI 会生成对应的节点画布。
              </>
            ) : (
              <>
                {selectedCount > 0
                  ? `已选中 ${selectedCount} 个节点。描述要修改的内容，例如：`
                  : "先在画布上选中要修改的节点，再描述修改内容。例如："}
                <div className="mt-2 rounded bg-card p-2 font-mono text-[11px] text-text-3">
                  "把 RSI 阈值从 30 改成 25，止损收紧到 3%"
                </div>
                {selectedCount === 0 && (
                  <div className="mt-2 text-[11px] text-warn">当前未选中任何节点</div>
                )}
              </>
            )}
          </div>
        )}
        {messages.map((m, i) => (
          <div
            key={i}
            className={cn(
              "max-w-[90%] rounded-lg px-3 py-2 text-[12px] leading-relaxed",
              m.role === "user"
                ? "ml-auto bg-accent-soft text-accent-text"
                : "bg-surface text-text-2"
            )}
          >
            {m.text}
          </div>
        ))}
        {generate.isPending && (
          <div className="rounded-lg bg-surface px-3 py-2 text-[12px] text-text-3">
            AI 正在生成…
          </div>
        )}
      </div>

      {/* 输入区 */}
      <div className="space-y-2 border-t border-border p-3">
        <input
          value={symbol}
          onChange={(e) => setSymbol(e.target.value)}
          className="w-full rounded-lg border border-border bg-surface px-2.5 py-1.5 font-mono text-[11px] text-text outline-none focus:border-accent-text/60"
        />
        <div className="flex gap-1.5">
          <input
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && send()}
            placeholder="描述你的策略…"
            className="min-w-0 flex-1 rounded-lg border border-border bg-surface px-2.5 py-2 text-[12px] text-text outline-none focus:border-accent-text/60"
          />
          <button
            onClick={send}
            disabled={!input.trim() || generate.isPending}
            className="flex size-9 shrink-0 items-center justify-center rounded-lg bg-accent text-on-accent transition-colors hover:bg-accent-light disabled:opacity-50"
          >
            <Send className="size-4" />
          </button>
        </div>
      </div>
    </div>
  );
}