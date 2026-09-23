"""AlphaLoop 端到端流程审计 — 逐业务流程走通，输出断点清单。"""
import json, urllib.request, urllib.error, datetime

BASE = "http://127.0.0.1:8000"
SPEC = json.load(urllib.request.urlopen(BASE + "/openapi.json", timeout=10))
COMPS = SPEC["components"]["schemas"]
EMA_DSL = json.load(open("/Users/mr_csx/work-app/phosphor-terminal/backend/tests/fixtures/dsl/ema_cross.json"))
EXPIRES = (datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(days=2)).strftime("%Y-%m-%dT%H:%M:%SZ")

def req(method, path, body=None):
    try:
        r = urllib.request.Request(BASE + path,
            data=json.dumps(body).encode() if body is not None else None,
            headers={"Content-Type": "application/json"}, method=method)
        resp = urllib.request.urlopen(r, timeout=30)
        try: data = json.loads(resp.read())
        except Exception: data = None
        return resp.getcode(), data
    except urllib.error.HTTPError as e:
        try: data = json.loads(e.read())
        except Exception: data = None
        return e.code, data
    except Exception as e:
        return 0, {"error": str(e)}

def auto_body(path, method="post"):
    """从 openapi 提取 requestBody，按类型填 dummy（用于不确定 schema 的接口）。"""
    node = SPEC["paths"].get(path, {}).get(method)
    if not node: return {}
    rb = node.get("requestBody", {}).get("content", {})
    sch = None
    for ct, meta in rb.items(): sch = meta.get("schema"); break
    def fill(s, depth=0):
        if depth > 4 or not isinstance(s, dict): return {}
        if "$ref" in s: return fill(COMPS.get(s["$ref"].split("/")[-1], {}), depth + 1)
        if "anyOf" in s or "oneOf" in s:
            arr = s.get("anyOf") or s.get("oneOf")
            return fill(arr[0], depth + 1) if arr else {}
        out = {}
        for k, v in (s.get("properties") or {}).items():
            if "$ref" in v: out[k] = fill(v, depth + 1); continue
            t = v.get("type")
            if t == "string": out[k] = v.get("enum", ["test"])[0] if v.get("enum") else "test"
            elif t in ("number", "integer"): out[k] = v.get("default", 1)
            elif t == "boolean": out[k] = v.get("default", True)
            elif t == "array": out[k] = []
            elif t == "object": out[k] = {}
        for k in s.get("required", []): out.setdefault(k, "test")
        return out
    return fill(sch or {})

VERDICT = {"OK": "✅", "PARAM": "🟡", "BROKEN": "🔴", "NET": "🌐"}
results = []
cur = [""]

def step(desc, method, path, body=None, ok=(200, 201, 202, 204), show=True):
    code, data = req(method, path, body)
    if code in ok: verdict = "OK"
    elif code in (400, 422): verdict = "PARAM"
    elif code in (404, 500, 502, 503): verdict = "BROKEN"
    elif code == 0: verdict = "NET"
    else: verdict = "CHECK"
    results.append((cur[0], desc, code, verdict, json.dumps(data, ensure_ascii=False)[:180] if data else ""))
    icon = VERDICT.get(verdict, "⚠️")
    if show: print(f"  {icon} [{code}] {verdict:6} {desc}")
    if verdict in ("BROKEN", "NET") and show and data:
        print(f"       -> {json.dumps(data, ensure_ascii=False)[:160]}")
    return code, data

# ════════ 1. 策略闭环 ════════
cur[0] = "1.策略闭环"
print(f"\n══ {cur[0]} ══")
code, d = step("创建策略", "POST", "/api/v2/strategies", {"name": "审计-策略闭环", "description": "e2e"})
sid = (d or {}).get("id")
step("保存 DSL 模板版本", "POST", f"/api/v2/strategies/{sid}/versions", {"rule_dsl": EMA_DSL, "created_by": "audit"})
step("DSL 校验", "POST", "/api/v2/strategies/validate-dsl", {"dsl": EMA_DSL})
code, ws = step("workspace 聚合(版本+readiness)", "GET", f"/api/v2/strategies/{sid}/workspace")
vid = (ws or {}).get("latest_version_id")
step("版本状态流转 draft→validated", "PATCH", f"/api/v2/strategies/{sid}/versions/{vid}/status", {"to_status": "validated"}, ok=(200, 409, 422))
step("真回滚(基于当前 DSL 再建新版本)", "POST", f"/api/v2/strategies/{sid}/versions", {"rule_dsl": EMA_DSL, "created_by": "audit-rollback"})
code, d = step("发起回测(202 命令入队)", "POST", "/api/v2/backtest", {"dsl": EMA_DSL, "timerange": "20250101-20250301", "symbols": ["BTC/USDT"], "initial_capital": 10000, "strategy_version_id": vid})
step("策略删除", "DELETE", f"/api/v2/strategies/{sid}", ok=(200, 204, 409))

# ════════ 2. 信号生命周期 ════════
cur[0] = "2.信号生命周期"
print(f"\n══ {cur[0]} ══")
code, d = step("创建信号", "POST", "/api/v2/signals", {"source_type": "manual", "symbol": "BTC/USDT", "direction": "long", "confidence": 0.8, "expires_at": EXPIRES, "reasoning": "audit"})
sig = (d or {}).get("id")
step("信号列表", "GET", "/api/v2/signals?limit=5")
step("信号详情", "GET", f"/api/v2/signals/{sig}")
step("next-actions", "GET", f"/api/v2/signals/{sig}/next-actions")
step("流转 pending→active", "POST", f"/api/v2/signals/{sig}/transition", {"target_status": "active", "reason": "audit"}, ok=(200, 409, 422))
step("流转 active→observed_in_paper", "POST", f"/api/v2/signals/{sig}/transition", {"target_status": "observed_in_paper", "reason": "audit"}, ok=(200, 409, 422))
step("发布到策略", "POST", f"/api/v2/signals/{sig}/publish-to-strategy", ok=(200, 201, 404, 409, 422))
step("归档", "POST", f"/api/v2/signals/{sig}/archive", ok=(200, 409, 422))

# ════════ 3. 风控闭环 ════════
cur[0] = "3.风控闭环"
print(f"\n══ {cur[0]} ══")
step("保存门禁规则", "PUT", "/api/risk/rules", {"daily_loss_limit": 5, "weekly_loss_limit": 10, "consecutive_losses_limit": 3, "max_drawdown": 15})
step("读取门禁规则", "GET", "/api/risk/rules")
step("风控总览(守卫)", "GET", "/api/risk/overview")
step("规则评估", "POST", "/api/risk/evaluate", auto_body("/api/risk/evaluate"), ok=(200, 400, 422))
step("禁止新开仓", "POST", "/api/risk/block-new-entries", {}, ok=(200, 201, 400, 422))
step("解除禁止", "POST", "/api/risk/unblock", {}, ok=(200, 201, 400, 422))
step("紧急停止", "POST", "/api/risk/emergency-stop", {}, ok=(200, 201, 410))
step("紧急恢复", "POST", "/api/risk/emergency-resume", {}, ok=(200, 201, 410))
step("熔断记录列表", "GET", "/api/risk/circuit-breakers")

# ════════ 4. 就绪度 ════════
cur[0] = "4.实盘就绪度"
print(f"\n══ {cur[0]} ══")
step("就绪度检查(显式)", "POST", "/api/overview/live-readiness/check", auto_body("/api/overview/live-readiness/check"), ok=(200, 422))
step("就绪度查询", "GET", "/api/overview/live-readiness")
step("全局状态", "GET", "/api/overview/global-status")

# ════════ 5. AI 研究闭环 ════════
cur[0] = "5.AI研究闭环"
print(f"\n══ {cur[0]} ══")
body = auto_body("/api/ai-research/v2/runs"); body.setdefault("symbol", "BTC/USDT")
code, d = step("创建研究 run", "POST", "/api/ai-research/v2/runs", body)
rid = None
if isinstance(d, dict): rid = d.get("id") or d.get("run_id") or (d.get("run") or {}).get("id")
step("研究 runs 列表(前端实际用 v1 路径)", "GET", "/api/ai-research/runs")
if rid:
    step("执行 run(需 LLM,允许业务失败)", "POST", f"/api/ai-research/v2/runs/{rid}/execute", {}, ok=(200, 202, 400, 409, 422, 502))
    step("发布信号(允许前置未满足)", "POST", f"/api/ai-research/v2/runs/{rid}/publish-signal", ok=(200, 201, 400, 404, 409, 422))

# ════════ 6. Agent 平台 ════════
cur[0] = "6.Agent平台"
print(f"\n══ {cur[0]} ══")
code, d = step("创建 Agent", "POST", "/api/agents", auto_body("/api/agents"))
aid = (d or {}).get("id") or (d or {}).get("agent_id")
step("Agent 列表", "GET", "/api/agents")
if aid:
    step("运行 Agent", "POST", f"/api/agents/{aid}/run", auto_body(f"/api/agents/{{agent_id}}/run"), ok=(200, 202, 400, 409, 422))
step("任务列表", "GET", "/api/agents/tasks")

# ════════ 7. 成长闭环 ════════
cur[0] = "7.成长闭环"
print(f"\n══ {cur[0]} ══")
code, d = step("生成每日复盘", "POST", "/api/growth/reports/daily-review", {"days": 7})
rid2 = (d or {}).get("id")
step("复盘列表", "GET", "/api/growth/reports")
code, d = step("生成候选策略", "POST", f"/api/growth/candidates/generate/{rid2}", ok=(200, 201, 400, 404, 422))
cid = (d or {}).get("id") if isinstance(d, dict) else None
step("候选列表", "GET", "/api/growth/candidates")
if cid:
    step("确认候选", "POST", f"/api/growth/candidates/{cid}/confirm", ok=(200, 400, 404, 409, 422))
    step("推进候选", "POST", f"/api/growth/candidates/{cid}/advance", ok=(200, 400, 404, 409, 422))

# ════════ 8. 回测/模拟记录 ════════
cur[0] = "8.回测记录"
print(f"\n══ {cur[0]} ══")
for p in ("/api/strategy-runs", "/api/v2/backtest/runs", "/api/v2/strategy-runs"):
    code, d = step(f"运行记录列表 {p}", "GET", p, ok=(200, 404))
    if code == 200: break

# ════════ 9. 执行/对账 ════════
cur[0] = "9.执行对账"
print(f"\n══ {cur[0]} ══")
step("刷新交易所状态(交易所不可达属预期)", "POST", "/api/reconciliation/refresh-exchange-state", {}, ok=(200, 201, 400, 502))
step("对账重试", "POST", "/api/reconciliation/retry", {}, ok=(200, 201, 400, 404, 422))

# ════════ 10. 系统管理 ════════
cur[0] = "10.系统管理"
print(f"\n══ {cur[0]} ══")
pbody = auto_body("/api/admin/providers")
pbody.setdefault("category", "llm"); pbody.setdefault("name", "audit-llm"); pbody.setdefault("provider", "openai")
code, d = step("创建 Provider", "POST", "/api/admin/providers", pbody)
pid = None
if isinstance(d, dict): pid = d.get("id") or d.get("provider_id")
step("Provider 列表", "GET", "/api/admin/providers")
if pid:
    step("测试连接(网络不可达属预期)", "POST", f"/api/admin/providers/{pid}/test", ok=(200, 400, 404, 502))
    step("禁用 Provider", "POST", f"/api/admin/providers/{pid}/disable", {})
    step("启用 Provider", "POST", f"/api/admin/providers/{pid}/enable", {})
    step("删除 Provider", "DELETE", f"/api/admin/providers/{pid}", ok=(200, 204, 404))
step("系统设置写入", "PUT", "/api/admin/system-settings/audit_key", {"value": "v1", "category": "audit", "updated_by": "web"})
step("系统设置读取", "GET", "/api/admin/system-settings", ok=(200, 404))
step("数据清理任务列表", "GET", "/api/admin/data-vacuum/jobs")
code, d = step("创建告警规则", "POST", "/api/alert-rules", {"name": "审计-规则", "condition_type": "price_above", "threshold": 1})
arid = (d or {}).get("id")
step("告警规则列表", "GET", "/api/alert-rules")
step("告警评估", "POST", "/api/alert-rules/evaluate", {})
if arid: step("删除告警规则", "DELETE", f"/api/alert-rules/{arid}")

# ════════ 汇总 ════════
print("\n" + "═" * 60)
from collections import defaultdict
agg = defaultdict(lambda: {"OK": 0, "PARAM": 0, "BROKEN": 0, "NET": 0, "CHECK": 0})
for f, s, c, v, note in results: agg[f][v] += 1
print(f"{'流程':<14}{'✅OK':>6}{'🟡参数':>7}{'🔴断点':>7}{'🌐网络':>7}{'⚠️其他':>7}")
for f, v in agg.items():
    print(f"{f:<14}{v['OK']:>6}{v['PARAM']:>7}{v['BROKEN']:>7}{v['NET']:>7}{v['CHECK']:>7}")
broken = [(f, s, c, n) for f, s, c, v, n in results if v in ("BROKEN", "NET")]
print(f"\n🔴 断点明细（{len(broken)} 条）:")
for f, s, c, n in broken: print(f"  [{c}] {f} · {s}\n      {n}")
json.dump(results, open("/Users/mr_csx/work-app/e2e_results.json", "w"), ensure_ascii=False, indent=1)
print("\n明细已存 e2e_results.json")
