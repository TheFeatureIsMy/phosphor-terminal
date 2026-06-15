const LS_LANG = "alphaloop.guide.lang";
const DEFAULT_ROUTE = "/welcome";

const NAV = [
  { group: { zh: "概念", en: "Concepts" }, items: [
    { path: "/concepts/01-what-is-quant",   zh: "什么是量化交易",       en: "What Is Quant Trading" },
    { path: "/concepts/02-smc-ict",         zh: "SMC / ICT 五分钟入门",  en: "SMC / ICT in 5 Minutes" },
    { path: "/concepts/03-market-structure",zh: "市场结构: 趋势 BOS CHoCH", en: "Market Structure: BOS & CHoCH" },
    { path: "/concepts/04-order-block",     zh: "订单块 (Order Block)",   en: "Order Blocks" },
    { path: "/concepts/05-fair-value-gap",  zh: "公允价值缺口 (FVG)",     en: "Fair Value Gaps" },
    { path: "/concepts/06-liquidity",       zh: "流动性池与扫荡",         en: "Liquidity, Sweeps, BSL/SSL" },
    { path: "/concepts/07-multi-timeframe", zh: "多周期与影子窗口",       en: "Multi-Timeframe & Shadow Window" },
    { path: "/concepts/08-risk-basics",     zh: "风控基础",              en: "Risk Basics" },
    { path: "/concepts/09-dryrun-vs-live",  zh: "回测 / 干跑 / 实盘",     en: "Backtest / Dry-Run / Live" },
    { path: "/concepts/10-ai-roles",        zh: "AlphaLoop 中的 AI 角色", en: "AI Roles in AlphaLoop" },
  ]},
  { group: { zh: "概览", en: "Overview" }, items: [
    { path: "/pages/overview/dashboard",      zh: "总览仪表盘",        en: "Dashboard" },
    { path: "/pages/overview/live-readiness", zh: "实盘就绪",          en: "Live Readiness" },
  ]},
  { group: { zh: "策略", en: "Strategy" }, items: [
    { path: "/pages/strategy/strategy-workspace",  zh: "策略工作台",      en: "Strategy Workspace" },
    { path: "/pages/strategy/strategy-canvas",     zh: "策略画布",        en: "Strategy Canvas" },
    { path: "/pages/strategy/backtest-simulation", zh: "回测与模拟",      en: "Backtest & Simulation" },
  ]},
  { group: { zh: "结构", en: "Structure" }, items: [
    { path: "/pages/structure/market-structure",   zh: "市场结构",        en: "Market Structure" },
    { path: "/pages/structure/structure-matrix",   zh: "结构矩阵 · HTF",  en: "Structure Matrix · HTF" },
    { path: "/pages/structure/manipulation-radar", zh: "操纵雷达",        en: "Manipulation Radar" },
  ]},
  { group: { zh: "执行", en: "Execution" }, items: [
    { path: "/pages/execution/execution-center",    zh: "执行中心",       en: "Execution Center" },
    { path: "/pages/execution/orders-positions",    zh: "订单与持仓",     en: "Orders & Positions" },
    { path: "/pages/execution/reconciliation-bus",  zh: "对账总线",       en: "Reconciliation Bus" },
  ]},
  { group: { zh: "风控", en: "Risk" }, items: [
    { path: "/pages/risk/risk-center",       zh: "风控中心",          en: "Risk Center" },
    { path: "/pages/risk/stop-protection",   zh: "止损保护",          en: "Stop Protection" },
    { path: "/pages/risk/circuit-breakers",  zh: "熔断器",            en: "Circuit Breakers" },
  ]},
  { group: { zh: "AI 研究", en: "AI Research" }, items: [
    { path: "/pages/ai-research/ai-research-room", zh: "AI 研究室",     en: "AI Research Room" },
    { path: "/pages/ai-research/agent-platform",   zh: "Agent 平台",     en: "Agent Platform" },
    { path: "/pages/ai-research/signal-center",    zh: "信号中心",       en: "Signal Center" },
    { path: "/pages/ai-research/market-sentiment", zh: "市场情绪",       en: "Market Sentiment" },
  ]},
  { group: { zh: "成长", en: "Growth" }, items: [
    { path: "/pages/growth/growth-review",        zh: "成长复盘",        en: "Growth Review" },
    { path: "/pages/growth/failure-clustering",   zh: "失败聚类",        en: "Failure Clustering" },
    { path: "/pages/growth/strategy-optimization", zh: "策略优化",        en: "Strategy Optimization" },
  ]},
  { group: { zh: "系统", en: "System" }, items: [
    { path: "/pages/system/service-management",     zh: "服务管理",       en: "Service Management" },
    { path: "/pages/system/data-source-management", zh: "数据源管理",     en: "Data Source Management" },
    { path: "/pages/system/settings",               zh: "设置",          en: "Settings" },
  ]},
  { group: { zh: "情景手册", en: "Walkthroughs" }, items: [
    { path: "/walkthroughs/first-strategy",     zh: "第一个策略",            en: "First Strategy" },
    { path: "/walkthroughs/daily-trading-loop", zh: "日常交易闭环",          en: "Daily Trading Loop" },
    { path: "/walkthroughs/htf-tribunal-flow",  zh: "HTF Tribunal 走查",     en: "HTF Tribunal Flow" },
    { path: "/walkthroughs/risk-incident",      zh: "风险事件处理",          en: "Risk Incident" },
    { path: "/walkthroughs/improve-strategy",   zh: "迭代优化策略",          en: "Improve Strategy" },
  ]},
];

const sidebarEl = document.getElementById("sidebar");
const chapterEl = document.getElementById("chapter");
const langBtn   = document.getElementById("lang-toggle");
const searchBtn = document.getElementById("search-toggle");
const searchModal = document.getElementById("search-modal");
const searchInput = document.getElementById("search-input");
const searchList  = document.getElementById("search-results");
const pagerPrev = document.getElementById("pager-prev");
const pagerNext = document.getElementById("pager-next");

let state = {
  lang: localStorage.getItem(LS_LANG) || "zh",
  route: "",
  searchIndex: null,
};

function flatNav() {
  const out = [];
  for (const g of NAV) for (const it of g.items) out.push(it);
  return out;
}

function renderSidebar() {
  const lang = state.lang;
  sidebarEl.innerHTML = NAV.map(g => `
    <h3>${g.group[lang]}</h3>
    <ul>
      ${g.items.map(it => `<li><a href="#${it.path}" data-path="${it.path}">${it[lang]}</a></li>`).join("")}
    </ul>
  `).join("");
  markActive();
}

function markActive() {
  for (const a of sidebarEl.querySelectorAll("a")) {
    if (a.dataset.path === state.route) a.classList.add("active");
    else a.classList.remove("active");
  }
}

async function loadChapter(route) {
  state.route = route;
  const file = `content/${state.lang}${route}.html`;
  chapterEl.innerHTML = '<p class="loading">载入中…</p>';
  try {
    const res = await fetch(file, { cache: "no-store" });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    chapterEl.innerHTML = await res.text();
    chapterEl.scrollIntoView({ behavior: "instant", block: "start" });
  } catch (err) {
    chapterEl.innerHTML = `<h1>404</h1><p>未找到章节 <code>${route}</code> (${state.lang})。</p>`;
  }
  markActive();
  renderPager();
}

function renderPager() {
  const flat = flatNav();
  const idx = flat.findIndex(it => it.path === state.route);
  const prev = idx > 0 ? flat[idx - 1] : null;
  const next = idx >= 0 && idx < flat.length - 1 ? flat[idx + 1] : null;
  if (prev) { pagerPrev.hidden = false; pagerPrev.href = `#${prev.path}`; pagerPrev.textContent = `◀ ${prev[state.lang]}`; }
  else      { pagerPrev.hidden = true; }
  if (next) { pagerNext.hidden = false; pagerNext.href = `#${next.path}`; pagerNext.textContent = `${next[state.lang]} ▶`; }
  else      { pagerNext.hidden = true; }
}

function currentRoute() {
  const h = location.hash.replace(/^#/, "");
  return h && h.startsWith("/") ? h : DEFAULT_ROUTE;
}

function setLang(lang) {
  state.lang = lang;
  localStorage.setItem(LS_LANG, lang);
  document.documentElement.setAttribute("data-lang", lang);
  document.documentElement.setAttribute("lang", lang === "zh" ? "zh-CN" : "en");
  renderSidebar();
  loadChapter(state.route || currentRoute());
}

langBtn.addEventListener("click", () => setLang(state.lang === "zh" ? "en" : "zh"));
window.addEventListener("hashchange", () => loadChapter(currentRoute()));

// Search
async function ensureIndex() {
  if (state.searchIndex) return state.searchIndex;
  const res = await fetch("assets/search-index.json", { cache: "no-store" });
  state.searchIndex = await res.json();
  return state.searchIndex;
}
function openSearch() { searchModal.hidden = false; searchInput.value = ""; searchInput.focus(); renderSearch(""); }
function closeSearch() { searchModal.hidden = true; }
async function renderSearch(q) {
  const idx = await ensureIndex();
  const lang = state.lang;
  const term = q.trim().toLowerCase();
  const hits = idx.filter(entry => {
    if (!term) return true;
    const hay = [entry.title_zh, entry.title_en, ...(entry.keywords || [])].join(" ").toLowerCase();
    return hay.includes(term);
  }).slice(0, 30);
  searchList.innerHTML = hits.map(h =>
    `<li data-path="${h.path}"><span class="hit-section">${h.section_zh} · ${h.section_en}</span>${lang === "zh" ? h.title_zh : h.title_en}</li>`
  ).join("");
}
searchBtn.addEventListener("click", openSearch);
searchInput.addEventListener("input", e => renderSearch(e.target.value));
searchList.addEventListener("click", e => {
  const li = e.target.closest("li");
  if (li) { location.hash = `#${li.dataset.path}`; closeSearch(); }
});
window.addEventListener("keydown", e => {
  if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "k") { e.preventDefault(); openSearch(); }
  else if (e.key === "Escape" && !searchModal.hidden) { closeSearch(); }
});
searchModal.addEventListener("click", e => { if (e.target === searchModal) closeSearch(); });

// Boot
document.documentElement.setAttribute("data-lang", state.lang);
document.documentElement.setAttribute("lang", state.lang === "zh" ? "zh-CN" : "en");
renderSidebar();
loadChapter(currentRoute());
