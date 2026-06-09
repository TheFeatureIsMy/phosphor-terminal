# AlphaLoop User Guide Site Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a bilingual, zero-build static HTML user guide site at `docs/user-guide/` covering 10 concepts + 25 page chapters + 5 walkthroughs, and wire it into the macOS app via a sidebar link and Dashboard top card.

**Architecture:** Hand-authored HTML partials loaded by a tiny hash-router (`app.js`) into a shell `index.html`. CSS variables port AlphaLoop's design tokens 1:1. Folder-per-language (`content/zh/...`, `content/en/...`). macOS integration via `NSWorkspace.shared.open(_:)` opening the local `index.html` (bundled or repo-relative).

**Tech Stack:** Plain HTML5 + CSS3 + vanilla ES module JS (no framework, no build step). Swift 6.2 + SwiftUI for app integration. L10n through existing `L10n.<Domain>` pattern.

**Spec:** `docs/superpowers/specs/2026-06-10-user-guide-site-design.md`

---

## Phase 0 — Scaffolding

### Task 0.1: Create directory layout

**Files:**
- Create: `docs/user-guide/assets/fonts/.gitkeep`
- Create: `docs/user-guide/content/concepts/.gitkeep`
- Create: `docs/user-guide/content/pages/overview/.gitkeep`
- Create: `docs/user-guide/content/pages/strategy/.gitkeep`
- Create: `docs/user-guide/content/pages/structure/.gitkeep`
- Create: `docs/user-guide/content/pages/execution/.gitkeep`
- Create: `docs/user-guide/content/pages/risk/.gitkeep`
- Create: `docs/user-guide/content/pages/ai-research/.gitkeep`
- Create: `docs/user-guide/content/pages/growth/.gitkeep`
- Create: `docs/user-guide/content/pages/system/.gitkeep`
- Create: `docs/user-guide/content/walkthroughs/.gitkeep`

- [ ] **Step 1: Create the tree**

```bash
mkdir -p docs/user-guide/assets/fonts
mkdir -p docs/user-guide/content/{zh,en}/{concepts,walkthroughs}
mkdir -p docs/user-guide/content/{zh,en}/pages/{overview,strategy,structure,execution,risk,ai-research,growth,system}
for d in docs/user-guide/assets/fonts \
         docs/user-guide/content/zh/concepts docs/user-guide/content/en/concepts \
         docs/user-guide/content/zh/walkthroughs docs/user-guide/content/en/walkthroughs; do
  touch "$d/.gitkeep"
done
```

- [ ] **Step 2: Verify**

Run: `find docs/user-guide -type d | sort`
Expected: 22 directories listed, two language trees mirrored.

- [ ] **Step 3: Commit**

```bash
git add docs/user-guide
git commit -m "chore(user-guide): scaffold site directory layout"
```

---

## Phase 1 — Site Framework

### Task 1.1: Write `index.html` shell

**Files:**
- Create: `docs/user-guide/index.html`

- [ ] **Step 1: Author the shell**

```html
<!doctype html>
<html lang="zh-CN" data-lang="zh">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>AlphaLoop · 用户指南</title>
  <link rel="stylesheet" href="assets/styles.css">
</head>
<body>
  <header class="topbar">
    <a class="brand" href="#/">
      <span class="brand-mark">α</span>
      <span class="brand-name">AlphaLoop Guide</span>
    </a>
    <div class="topbar-actions">
      <button id="lang-toggle" class="lang-toggle" aria-label="Toggle language">
        <span data-lang-zh>中</span><span class="lang-sep">◍</span><span data-lang-en>en</span>
      </button>
      <button id="search-toggle" class="search-toggle" aria-label="Search">⌘K</button>
    </div>
  </header>
  <div class="layout">
    <nav class="sidebar" id="sidebar" aria-label="Guide navigation"></nav>
    <main class="chapter" id="chapter" tabindex="-1"><p class="loading">载入中…</p></main>
  </div>
  <div class="search-modal" id="search-modal" hidden>
    <div class="search-shell">
      <input id="search-input" type="search" autocomplete="off" placeholder="搜索章节…" />
      <ul id="search-results"></ul>
    </div>
  </div>
  <footer class="footer">
    <span>© 2026 AlphaLoop</span>
    <nav class="pager">
      <a id="pager-prev" rel="prev">◀ 上一章</a>
      <a id="pager-next" rel="next">下一章 ▶</a>
    </nav>
  </footer>
  <script type="module" src="assets/app.js"></script>
</body>
</html>
```

- [ ] **Step 2: Open in browser to verify markup**

Run: `open docs/user-guide/index.html`
Expected: page renders without errors (will be unstyled; OK for now).

- [ ] **Step 3: Commit**

```bash
git add docs/user-guide/index.html
git commit -m "feat(user-guide): add index.html shell"
```

### Task 1.2: Write `styles.css` (design token port)

**Files:**
- Create: `docs/user-guide/assets/styles.css`

- [ ] **Step 1: Author full stylesheet**

```css
:root {
  --bg:            #0a0c10;
  --bg-elevated:   #11141a;
  --card:          rgba(20, 24, 32, 0.6);
  --card-strong:   rgba(20, 24, 32, 0.85);
  --border:        rgba(255, 255, 255, 0.08);
  --border-strong: rgba(255, 255, 255, 0.14);
  --text-primary:  #e8eaee;
  --text-2nd:      #9ca0a8;
  --text-muted:    #5e636d;
  --accent:        #00ff9d;
  --state-yellow:  #f5c542;
  --state-orange:  #ff9b3d;
  --state-red:     #ff5470;

  --space-xxs:  4px;  --space-xs:  8px;  --space-sm: 12px;
  --space-md:  16px;  --space-lg: 24px;  --space-xl: 32px;  --space-xxl: 48px;
  --radius-sm:  6px;  --radius-md: 10px; --radius-card: 16px;

  --font-display: "Fraunces", Georgia, serif;
  --font-body:    "Inter", -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  --font-mono:    "JetBrains Mono", "SF Mono", ui-monospace, monospace;
}

* { box-sizing: border-box; }
html, body { margin: 0; padding: 0; background: var(--bg); color: var(--text-primary); font-family: var(--font-body); font-size: 15px; line-height: 1.65; }
body {
  background:
    radial-gradient(1200px 600px at 20% -10%, rgba(0,255,157,0.05), transparent 60%),
    radial-gradient(900px 500px at 100% 10%, rgba(0,255,157,0.03), transparent 60%),
    var(--bg);
  min-height: 100vh;
}
body::before {
  content: ""; position: fixed; inset: 0; pointer-events: none; z-index: 0;
  background-image: radial-gradient(rgba(255,255,255,0.05) 1px, transparent 1px);
  background-size: 24px 24px; opacity: 0.4;
}
a { color: var(--accent); text-decoration: none; }
a:hover { text-decoration: underline; }
code, pre, .mono { font-family: var(--font-mono); font-size: 13px; }

/* Topbar */
.topbar {
  position: sticky; top: 0; z-index: 10;
  display: flex; align-items: center; justify-content: space-between;
  padding: var(--space-md) var(--space-xl);
  background: var(--card-strong); backdrop-filter: blur(20px);
  border-bottom: 1px solid var(--border);
}
.brand { display: flex; align-items: center; gap: var(--space-sm); }
.brand-mark { font-family: var(--font-display); font-size: 22px; color: var(--accent); }
.brand-name { font-family: var(--font-display); font-size: 18px; letter-spacing: 0.02em; }
.topbar-actions { display: flex; gap: var(--space-sm); }
.lang-toggle, .search-toggle {
  background: transparent; color: var(--text-2nd);
  border: 1px solid var(--border-strong); border-radius: var(--radius-sm);
  padding: 6px 10px; font-family: var(--font-mono); font-size: 12px;
  cursor: pointer; transition: border-color 120ms, color 120ms;
}
.lang-toggle:hover, .search-toggle:hover { border-color: var(--accent); color: var(--text-primary); }
.lang-sep { margin: 0 6px; opacity: 0.4; }
html[data-lang="zh"] .lang-toggle [data-lang-zh] { color: var(--accent); }
html[data-lang="en"] .lang-toggle [data-lang-en] { color: var(--accent); }

/* Layout */
.layout { display: grid; grid-template-columns: 260px 1fr; min-height: calc(100vh - 64px); position: relative; z-index: 1; }
.sidebar {
  padding: var(--space-lg) var(--space-md);
  border-right: 1px solid var(--border);
  background: rgba(10, 12, 16, 0.6); backdrop-filter: blur(10px);
  overflow-y: auto; max-height: calc(100vh - 64px); position: sticky; top: 64px;
}
.sidebar h3 {
  font-family: var(--font-mono); font-size: 11px; letter-spacing: 0.15em;
  text-transform: uppercase; color: var(--text-muted);
  margin: var(--space-lg) 0 var(--space-xs);
}
.sidebar h3:first-child { margin-top: 0; }
.sidebar ul { list-style: none; margin: 0; padding: 0; }
.sidebar a {
  display: block; padding: 6px var(--space-sm); border-radius: var(--radius-sm);
  color: var(--text-2nd); font-size: 13px; line-height: 1.5;
  border-left: 2px solid transparent;
}
.sidebar a:hover { color: var(--text-primary); text-decoration: none; background: rgba(255,255,255,0.03); }
.sidebar a.active { color: var(--accent); border-left-color: var(--accent); background: rgba(0,255,157,0.05); }

/* Chapter */
.chapter {
  padding: var(--space-xxl) var(--space-xxl);
  max-width: 860px; margin: 0 auto;
  animation: fadeUp 250ms ease both;
}
@keyframes fadeUp { from { opacity: 0; transform: translateY(6px); } to { opacity: 1; transform: none; } }
.chapter h1 { font-family: var(--font-display); font-weight: 500; font-size: 32px; line-height: 1.2; margin: 0 0 var(--space-xs); }
.chapter h2 { font-family: var(--font-display); font-weight: 500; font-size: 22px; margin: var(--space-xl) 0 var(--space-sm); }
.chapter h3 { font-family: var(--font-body); font-weight: 600; font-size: 16px; margin: var(--space-lg) 0 var(--space-xs); color: var(--text-primary); }
.chapter p { color: var(--text-2nd); }
.chapter strong { color: var(--text-primary); }
.chapter .chapter-meta { color: var(--text-muted); font-family: var(--font-mono); font-size: 12px; margin-bottom: var(--space-lg); }
.chapter blockquote.lede {
  border-left: 2px solid var(--accent); margin: 0 0 var(--space-lg);
  padding: var(--space-sm) var(--space-md);
  font-family: var(--font-display); font-size: 18px; font-style: italic; color: var(--text-primary);
  background: rgba(0,255,157,0.04);
}
.chapter blockquote.pull {
  margin: var(--space-lg) 0; padding: var(--space-md) var(--space-lg);
  border: 1px solid var(--border); border-radius: var(--radius-md);
  background: var(--card); backdrop-filter: blur(10px);
}
.chapter blockquote.pull cite { display: block; margin-top: var(--space-xs); color: var(--text-muted); font-size: 12px; font-style: normal; }
.chapter .callout {
  margin: var(--space-lg) 0; padding: var(--space-md);
  border: 1px solid var(--border-strong); border-radius: var(--radius-md);
  background: var(--card);
}
.chapter .sources { margin-top: var(--space-xxl); padding-top: var(--space-lg); border-top: 1px solid var(--border); }
.chapter .sources ol { color: var(--text-muted); font-size: 13px; padding-left: 20px; }
.chapter .sources a { color: var(--text-2nd); }
.chapter sup.cite { color: var(--accent); font-size: 11px; padding: 0 2px; cursor: pointer; }
.chapter .diagram { display: block; width: 100%; max-width: 760px; margin: var(--space-lg) auto; }
.chapter table { width: 100%; border-collapse: collapse; margin: var(--space-md) 0; font-size: 13px; }
.chapter th, .chapter td { padding: 8px 12px; border-bottom: 1px solid var(--border); text-align: left; }
.chapter th { color: var(--text-muted); font-weight: 500; font-family: var(--font-mono); font-size: 11px; text-transform: uppercase; letter-spacing: 0.1em; }
.chapter ul, .chapter ol { color: var(--text-2nd); }
.chapter li { margin-bottom: 4px; }

/* Footer + pager */
.footer { display: flex; justify-content: space-between; align-items: center; padding: var(--space-lg) var(--space-xl); border-top: 1px solid var(--border); color: var(--text-muted); font-size: 12px; }
.pager { display: flex; gap: var(--space-lg); }
.pager a { color: var(--text-2nd); cursor: pointer; }
.pager a[hidden] { display: none; }

/* Search modal */
.search-modal {
  position: fixed; inset: 0; z-index: 100; background: rgba(0,0,0,0.6); backdrop-filter: blur(6px);
  display: flex; align-items: flex-start; justify-content: center; padding-top: 12vh;
}
.search-modal[hidden] { display: none; }
.search-shell {
  width: min(640px, 92vw); background: var(--card-strong); border: 1px solid var(--border-strong);
  border-radius: var(--radius-card); overflow: hidden;
}
.search-shell input {
  width: 100%; padding: var(--space-md) var(--space-lg);
  background: transparent; color: var(--text-primary); border: 0; outline: 0;
  font-family: var(--font-body); font-size: 16px;
  border-bottom: 1px solid var(--border);
}
.search-shell ul { list-style: none; margin: 0; padding: 0; max-height: 50vh; overflow-y: auto; }
.search-shell li { padding: 10px var(--space-lg); cursor: pointer; color: var(--text-2nd); }
.search-shell li:hover, .search-shell li.focused { background: rgba(0,255,157,0.06); color: var(--text-primary); }
.search-shell li .hit-section { display: block; font-size: 11px; color: var(--text-muted); font-family: var(--font-mono); text-transform: uppercase; }

/* Reduced motion */
@media (prefers-reduced-motion: reduce) {
  .chapter { animation: none; }
}

/* Narrow screens */
@media (max-width: 880px) {
  .layout { grid-template-columns: 1fr; }
  .sidebar { position: static; max-height: none; border-right: 0; border-bottom: 1px solid var(--border); }
  .chapter { padding: var(--space-lg); }
}
```

- [ ] **Step 2: Reload page in browser**

Run: `open docs/user-guide/index.html`
Expected: dark themed page with sticky topbar and grid layout (main content empty).

- [ ] **Step 3: Commit**

```bash
git add docs/user-guide/assets/styles.css
git commit -m "feat(user-guide): add styles.css with design-token CSS variables"
```

### Task 1.3: Write `app.js` (router + lang toggle + search)

**Files:**
- Create: `docs/user-guide/assets/app.js`

- [ ] **Step 1: Author script**

```js
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
    { path: "/pages/overview/dashboard",      zh: "Dashboard",        en: "Dashboard" },
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
```

- [ ] **Step 2: Reload page**

Run: `open docs/user-guide/index.html`
Expected: sidebar renders with grouped chapter list; clicking shows 404 (no content yet); ⌘K opens search modal.

- [ ] **Step 3: Commit**

```bash
git add docs/user-guide/assets/app.js
git commit -m "feat(user-guide): add app.js router, lang toggle, search modal"
```

### Task 1.4: Seed `search-index.json`

**Files:**
- Create: `docs/user-guide/assets/search-index.json`

- [ ] **Step 1: Author seed index**

```json
[
  {"path":"/welcome","section_zh":"开始","section_en":"Start","title_zh":"欢迎","title_en":"Welcome","keywords":["intro","start","入门"]},
  {"path":"/concepts/01-what-is-quant","section_zh":"概念","section_en":"Concepts","title_zh":"什么是量化交易","title_en":"What Is Quant Trading","keywords":["quant","量化"]},
  {"path":"/concepts/02-smc-ict","section_zh":"概念","section_en":"Concepts","title_zh":"SMC / ICT 五分钟入门","title_en":"SMC / ICT in 5 Minutes","keywords":["smc","ict","smart money"]},
  {"path":"/concepts/03-market-structure","section_zh":"概念","section_en":"Concepts","title_zh":"市场结构 BOS CHoCH","title_en":"Market Structure BOS CHoCH","keywords":["bos","choch","mss","结构"]},
  {"path":"/concepts/04-order-block","section_zh":"概念","section_en":"Concepts","title_zh":"订单块 Order Block","title_en":"Order Blocks","keywords":["ob","order block","订单块"]},
  {"path":"/concepts/05-fair-value-gap","section_zh":"概念","section_en":"Concepts","title_zh":"公允价值缺口 FVG","title_en":"Fair Value Gaps","keywords":["fvg","gap","公允价值"]},
  {"path":"/concepts/06-liquidity","section_zh":"概念","section_en":"Concepts","title_zh":"流动性 BSL SSL","title_en":"Liquidity BSL SSL","keywords":["liquidity","sweep","流动性"]},
  {"path":"/concepts/07-multi-timeframe","section_zh":"概念","section_en":"Concepts","title_zh":"多周期 影子窗口","title_en":"Multi-Timeframe Shadow Window","keywords":["mtf","shadow","htf","ltf","多周期"]},
  {"path":"/concepts/08-risk-basics","section_zh":"概念","section_en":"Concepts","title_zh":"风控基础","title_en":"Risk Basics","keywords":["risk","止损","drawdown"]},
  {"path":"/concepts/09-dryrun-vs-live","section_zh":"概念","section_en":"Concepts","title_zh":"回测 干跑 实盘","title_en":"Backtest Dryrun Live","keywords":["backtest","dryrun","freqtrade","回测"]},
  {"path":"/concepts/10-ai-roles","section_zh":"概念","section_en":"Concepts","title_zh":"AI 角色","title_en":"AI Roles","keywords":["ai","agent","finbert"]},

  {"path":"/pages/overview/dashboard","section_zh":"概览","section_en":"Overview","title_zh":"Dashboard","title_en":"Dashboard","keywords":["dashboard","总览"]},
  {"path":"/pages/overview/live-readiness","section_zh":"概览","section_en":"Overview","title_zh":"实盘就绪","title_en":"Live Readiness","keywords":["readiness","实盘"]},
  {"path":"/pages/strategy/strategy-workspace","section_zh":"策略","section_en":"Strategy","title_zh":"策略工作台","title_en":"Strategy Workspace","keywords":["strategy","workspace"]},
  {"path":"/pages/strategy/strategy-canvas","section_zh":"策略","section_en":"Strategy","title_zh":"策略画布","title_en":"Strategy Canvas","keywords":["canvas","dag","graph"]},
  {"path":"/pages/strategy/backtest-simulation","section_zh":"策略","section_en":"Strategy","title_zh":"回测与模拟","title_en":"Backtest Simulation","keywords":["backtest","simulation"]},
  {"path":"/pages/structure/market-structure","section_zh":"结构","section_en":"Structure","title_zh":"市场结构","title_en":"Market Structure","keywords":["structure"]},
  {"path":"/pages/structure/structure-matrix","section_zh":"结构","section_en":"Structure","title_zh":"结构矩阵 HTF Tribunal","title_en":"Structure Matrix HTF Tribunal","keywords":["matrix","htf","tribunal","mtf"]},
  {"path":"/pages/structure/manipulation-radar","section_zh":"结构","section_en":"Structure","title_zh":"操纵雷达","title_en":"Manipulation Radar","keywords":["manipulation","radar","wick"]},
  {"path":"/pages/execution/execution-center","section_zh":"执行","section_en":"Execution","title_zh":"执行中心","title_en":"Execution Center","keywords":["execution","订单"]},
  {"path":"/pages/execution/orders-positions","section_zh":"执行","section_en":"Execution","title_zh":"订单与持仓","title_en":"Orders Positions","keywords":["orders","positions"]},
  {"path":"/pages/execution/reconciliation-bus","section_zh":"执行","section_en":"Execution","title_zh":"对账总线","title_en":"Reconciliation Bus","keywords":["reconciliation","bus","对账"]},
  {"path":"/pages/risk/risk-center","section_zh":"风控","section_en":"Risk","title_zh":"风控中心","title_en":"Risk Center","keywords":["risk","center"]},
  {"path":"/pages/risk/stop-protection","section_zh":"风控","section_en":"Risk","title_zh":"止损保护","title_en":"Stop Protection","keywords":["stop","止损"]},
  {"path":"/pages/risk/circuit-breakers","section_zh":"风控","section_en":"Risk","title_zh":"熔断器","title_en":"Circuit Breakers","keywords":["circuit","breaker","熔断"]},
  {"path":"/pages/ai-research/ai-research-room","section_zh":"AI 研究","section_en":"AI Research","title_zh":"AI 研究室","title_en":"AI Research Room","keywords":["research","ai"]},
  {"path":"/pages/ai-research/agent-platform","section_zh":"AI 研究","section_en":"AI Research","title_zh":"Agent 平台","title_en":"Agent Platform","keywords":["agent","platform"]},
  {"path":"/pages/ai-research/signal-center","section_zh":"AI 研究","section_en":"AI Research","title_zh":"信号中心","title_en":"Signal Center","keywords":["signal","center"]},
  {"path":"/pages/ai-research/market-sentiment","section_zh":"AI 研究","section_en":"AI Research","title_zh":"市场情绪","title_en":"Market Sentiment","keywords":["sentiment","finbert","情绪"]},
  {"path":"/pages/growth/growth-review","section_zh":"成长","section_en":"Growth","title_zh":"成长复盘","title_en":"Growth Review","keywords":["growth","review","复盘"]},
  {"path":"/pages/growth/failure-clustering","section_zh":"成长","section_en":"Growth","title_zh":"失败聚类","title_en":"Failure Clustering","keywords":["failure","clustering"]},
  {"path":"/pages/growth/strategy-optimization","section_zh":"成长","section_en":"Growth","title_zh":"策略优化","title_en":"Strategy Optimization","keywords":["optimize","tuning"]},
  {"path":"/pages/system/service-management","section_zh":"系统","section_en":"System","title_zh":"服务管理","title_en":"Service Management","keywords":["service","management"]},
  {"path":"/pages/system/data-source-management","section_zh":"系统","section_en":"System","title_zh":"数据源管理","title_en":"Data Source Management","keywords":["data","source"]},
  {"path":"/pages/system/settings","section_zh":"系统","section_en":"System","title_zh":"设置","title_en":"Settings","keywords":["settings","设置"]},

  {"path":"/walkthroughs/first-strategy","section_zh":"情景手册","section_en":"Walkthroughs","title_zh":"第一个策略","title_en":"First Strategy","keywords":["first","strategy","onboarding"]},
  {"path":"/walkthroughs/daily-trading-loop","section_zh":"情景手册","section_en":"Walkthroughs","title_zh":"日常交易闭环","title_en":"Daily Trading Loop","keywords":["daily","loop"]},
  {"path":"/walkthroughs/htf-tribunal-flow","section_zh":"情景手册","section_en":"Walkthroughs","title_zh":"HTF Tribunal 走查","title_en":"HTF Tribunal Flow","keywords":["htf","tribunal","mtf"]},
  {"path":"/walkthroughs/risk-incident","section_zh":"情景手册","section_en":"Walkthroughs","title_zh":"风险事件处理","title_en":"Risk Incident","keywords":["incident","risk"]},
  {"path":"/walkthroughs/improve-strategy","section_zh":"情景手册","section_en":"Walkthroughs","title_zh":"迭代优化策略","title_en":"Improve Strategy","keywords":["improve","tune"]}
]
```

- [ ] **Step 2: Verify in browser**

Run: `open docs/user-guide/index.html` → press ⌘K
Expected: search modal lists all 40 entries.

- [ ] **Step 3: Commit**

```bash
git add docs/user-guide/assets/search-index.json
git commit -m "feat(user-guide): seed search-index.json with 40 entries"
```

### Task 1.5: Write `welcome.html` partials (both langs)

**Files:**
- Create: `docs/user-guide/content/zh/welcome.html`
- Create: `docs/user-guide/content/en/welcome.html`

- [ ] **Step 1: Author zh welcome**

```html
<h1>欢迎使用 AlphaLoop</h1>
<p class="chapter-meta">入门 · 5 分钟</p>
<blockquote class="lede">这是一本写给"第一次打开 AlphaLoop"的人的指南。</blockquote>

<p>AlphaLoop 是一个 AI 驱动的加密货币量化交易工作台。它把"读图 → 找信号 → 验证 → 下单 → 复盘"的全流程拆成了 25 个页面,每个页面只解决一个问题。这本指南会先教你<strong>概念</strong>,再带你逐页认识<strong>界面</strong>,最后用 5 个真实<strong>场景</strong>把所有页面串起来。</p>

<h2>怎么读这本指南</h2>
<ul>
  <li><strong>概念书</strong> — 10 章,从"什么是量化"到"AI 在 AlphaLoop 里扮演什么角色"。不懂行话先看这里。</li>
  <li><strong>页面手册</strong> — 25 章,每个 App 页面一章。看到陌生界面就翻这里。</li>
  <li><strong>情景手册</strong> — 5 章,从零到上线的真实流程。学完概念后做一遍,等于上了一节实战课。</li>
</ul>

<h2>三条最重要的建议</h2>
<ol>
  <li><strong>从小仓位开始</strong>。AlphaLoop 默认开启"干跑(Dry-Run)"模式 — 用真实行情但假币下单,先在这里跑两周。</li>
  <li><strong>看懂"为什么"</strong>。每个 AI 信号、每条风控决策都会附原因码。不理解就到 Charges & Reasons 面板看一眼。</li>
  <li><strong>关注 HTF Tribunal</strong>。低周期的突破都是"暂时的",高周期蜡烛收盘才算数。结构矩阵页面的倒计时是你最该盯的。</li>
</ol>

<h2>第一次打开,建议这样走</h2>
<p>→ <a href="#/concepts/01-what-is-quant">概念 · 什么是量化交易</a> → <a href="#/concepts/02-smc-ict">SMC / ICT 五分钟入门</a> → <a href="#/walkthroughs/first-strategy">情景 · 第一个策略</a>。</p>
```

- [ ] **Step 2: Author en welcome**

```html
<h1>Welcome to AlphaLoop</h1>
<p class="chapter-meta">Start · 5 min read</p>
<blockquote class="lede">This guide is for someone who just opened AlphaLoop for the first time.</blockquote>

<p>AlphaLoop is an AI-driven crypto quant trading workbench. It breaks the full "read chart → find signal → validate → place order → review" loop into 25 dedicated pages, each solving exactly one problem. This guide teaches you the <strong>concepts</strong> first, walks you through every <strong>page</strong>, then ties it all together with 5 real <strong>walkthroughs</strong>.</p>

<h2>How to read this guide</h2>
<ul>
  <li><strong>Concepts</strong> — 10 chapters, from "what is quant" to "AI roles in AlphaLoop." Read here when jargon stops making sense.</li>
  <li><strong>Pages</strong> — 25 chapters, one per app page. Land on an unfamiliar screen → look it up here.</li>
  <li><strong>Walkthroughs</strong> — 5 chapters, end-to-end scenarios. After concepts, doing one is like taking a hands-on class.</li>
</ul>

<h2>Three pieces of advice that matter</h2>
<ol>
  <li><strong>Start small.</strong> AlphaLoop defaults to <em>dry-run</em> mode — real market data, paper orders. Live there for at least two weeks.</li>
  <li><strong>Understand the "why."</strong> Every AI signal and every risk decision carries a reason code. If something feels opaque, peek at the Charges &amp; Reasons panel.</li>
  <li><strong>Watch the HTF Tribunal.</strong> Low-timeframe breaks are provisional; only the high-timeframe candle close confirms. The countdown on the Structure Matrix page is your best friend.</li>
</ol>

<h2>Suggested first path</h2>
<p>→ <a href="#/concepts/01-what-is-quant">Concept · What Is Quant Trading</a> → <a href="#/concepts/02-smc-ict">SMC / ICT in 5 Minutes</a> → <a href="#/walkthroughs/first-strategy">Walkthrough · First Strategy</a>.</p>
```

- [ ] **Step 3: Browser smoke test**

Run: `open docs/user-guide/index.html` → loads `welcome` by default
Expected: dark-themed welcome renders; lang toggle swaps to English.

- [ ] **Step 4: Commit**

```bash
git add docs/user-guide/content/zh/welcome.html docs/user-guide/content/en/welcome.html
git commit -m "feat(user-guide): add bilingual welcome chapter"
```

---

## Phase 2 — Concepts (10 chapters × 2 langs = 20 files)

Each task in this phase follows the same template:

1. Author the zh partial (400–800 zh-chars body, blockquote lede, optional pull quote with `<cite>`, optional inline `<svg class="diagram">`, body sections `<h2>`/`<h3>`, "在 AlphaLoop 中" deep links, `<section class="sources">` with `<ol>` of cited URLs).
2. Author the en partial mirroring the zh structure.
3. Open the chapter in the browser to eyeball.
4. Commit both partials together.

### Task 2.1: Concept 01 — What Is Quant Trading

**Files:**
- Create: `docs/user-guide/content/zh/concepts/01-what-is-quant.html`
- Create: `docs/user-guide/content/en/concepts/01-what-is-quant.html`

- [ ] **Step 1: zh body**

```html
<h1>什么是量化交易</h1>
<p class="chapter-meta">概念 · 01 / 10 · 5 分钟</p>
<blockquote class="lede">量化交易,就是把"决策标准"写成代码,让程序按规则下单,而不是靠手感。</blockquote>

<p>传统交易者看着图说"这里像支撑位,我买一点"。量化交易者会问:<em>"支撑位的定义是什么? 在过去 1000 根 K 线里它的胜率是多少? 一次最多亏多少?"</em> 把这些问题逐条写成代码,得到的就是一个<strong>策略 (strategy)</strong>。</p>

<h2>三个必须分清的角色</h2>
<svg class="diagram" viewBox="0 0 600 180" xmlns="http://www.w3.org/2000/svg">
  <style>
    .lbl { font: 600 13px "Inter"; fill: #e8eaee; }
    .sub { font: 12px "Inter"; fill: #9ca0a8; }
    .box { fill: rgba(255,255,255,0.04); stroke: rgba(255,255,255,0.14); rx: 10; }
    .acc { stroke: #00ff9d; fill: rgba(0,255,157,0.08); }
    .arrow { stroke: #5e636d; stroke-width: 1.5; fill: none; marker-end: url(#ah); }
  </style>
  <defs>
    <marker id="ah" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="8" markerHeight="8" orient="auto">
      <path d="M0 0 L10 5 L0 10 z" fill="#5e636d"/>
    </marker>
  </defs>
  <rect class="box" x="20" y="40" width="160" height="100" />
  <text class="lbl" x="100" y="80" text-anchor="middle">策略 Strategy</text>
  <text class="sub" x="100" y="100" text-anchor="middle">规则的集合</text>
  <rect class="box acc" x="220" y="40" width="160" height="100" />
  <text class="lbl" x="300" y="80" text-anchor="middle">信号 Signal</text>
  <text class="sub" x="300" y="100" text-anchor="middle">"现在该不该做"</text>
  <rect class="box" x="420" y="40" width="160" height="100" />
  <text class="lbl" x="500" y="80" text-anchor="middle">订单 Order</text>
  <text class="sub" x="500" y="100" text-anchor="middle">真去下了</text>
  <path class="arrow" d="M180 90 L220 90" />
  <path class="arrow" d="M380 90 L420 90" />
</svg>

<h2>为什么要量化</h2>
<ul>
  <li><strong>可验证</strong>:策略写成代码后,可以拿历史数据跑一遍("回测"),不再是"我感觉这招很灵"。</li>
  <li><strong>不会困</strong>:程序 7×24 盯盘,你不会错过凌晨 3 点的信号。</li>
  <li><strong>纪律</strong>:止损是 -2% 就一定是 -2%,不会"再等等说不定回来"。</li>
</ul>

<h2>量化≠稳赚</h2>
<p>量化只是把决策"标准化",不是"魔法"。一个糟糕的策略量化后会更稳地亏钱。AlphaLoop 把整个量化生命周期 — <strong>生成 → 回测 → 干跑 → 小仓位实盘 → 复盘</strong> — 拆到了不同页面里,目的就是让你在每一步都能<em>看到证据</em>再决定。</p>

<h2>在 AlphaLoop 中</h2>
<ul>
  <li>策略生成: <a href="#/pages/ai-research/ai-research-room">AI 研究室</a> 和 <a href="#/pages/strategy/strategy-canvas">策略画布</a></li>
  <li>验证: <a href="#/pages/strategy/backtest-simulation">回测与模拟</a></li>
  <li>从干跑到上线: <a href="#/walkthroughs/first-strategy">情景 · 第一个策略</a></li>
</ul>
```

- [ ] **Step 2: en body**

```html
<h1>What Is Quant Trading</h1>
<p class="chapter-meta">Concept · 01 / 10 · 5 min</p>
<blockquote class="lede">Quant trading means writing your decision criteria as code and letting the machine execute, not your gut.</blockquote>

<p>A discretionary trader sees a chart and says, "this looks like support, I'll buy a bit." A quant trader asks, <em>"what's the precise definition of support? Across the last 1,000 candles, what's the win rate? What's the worst single loss?"</em> Answer every one of those questions in code, and you have a <strong>strategy</strong>.</p>

<h2>Three roles to distinguish</h2>
<svg class="diagram" viewBox="0 0 600 180" xmlns="http://www.w3.org/2000/svg">
  <style>
    .lbl { font: 600 13px "Inter"; fill: #e8eaee; }
    .sub { font: 12px "Inter"; fill: #9ca0a8; }
    .box { fill: rgba(255,255,255,0.04); stroke: rgba(255,255,255,0.14); rx: 10; }
    .acc { stroke: #00ff9d; fill: rgba(0,255,157,0.08); }
    .arrow { stroke: #5e636d; stroke-width: 1.5; fill: none; marker-end: url(#ah); }
  </style>
  <defs>
    <marker id="ah" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="8" markerHeight="8" orient="auto">
      <path d="M0 0 L10 5 L0 10 z" fill="#5e636d"/>
    </marker>
  </defs>
  <rect class="box" x="20" y="40" width="160" height="100" />
  <text class="lbl" x="100" y="80" text-anchor="middle">Strategy</text>
  <text class="sub" x="100" y="100" text-anchor="middle">a set of rules</text>
  <rect class="box acc" x="220" y="40" width="160" height="100" />
  <text class="lbl" x="300" y="80" text-anchor="middle">Signal</text>
  <text class="sub" x="300" y="100" text-anchor="middle">"act right now?"</text>
  <rect class="box" x="420" y="40" width="160" height="100" />
  <text class="lbl" x="500" y="80" text-anchor="middle">Order</text>
  <text class="sub" x="500" y="100" text-anchor="middle">actually filled</text>
  <path class="arrow" d="M180 90 L220 90" />
  <path class="arrow" d="M380 90 L420 90" />
</svg>

<h2>Why quantify</h2>
<ul>
  <li><strong>Falsifiable</strong>: rules in code can be back-tested. "I feel this works" becomes "the equity curve says so."</li>
  <li><strong>Never tired</strong>: software watches the tape 24/7. You don't miss the 3 a.m. signal.</li>
  <li><strong>Discipline</strong>: a -2% stop is exactly -2%. No "let me wait, maybe it comes back."</li>
</ul>

<h2>Quant ≠ free money</h2>
<p>Quant standardizes decisions; it doesn't conjure profit. A bad strategy will lose money <em>more reliably</em> when automated. AlphaLoop splits the entire quant lifecycle — <strong>generate → backtest → dry-run → small live → review</strong> — across distinct pages so you can <em>see evidence</em> before each step.</p>

<h2>In AlphaLoop</h2>
<ul>
  <li>Strategy generation: <a href="#/pages/ai-research/ai-research-room">AI Research Room</a> and <a href="#/pages/strategy/strategy-canvas">Strategy Canvas</a></li>
  <li>Validation: <a href="#/pages/strategy/backtest-simulation">Backtest &amp; Simulation</a></li>
  <li>From dry-run to live: <a href="#/walkthroughs/first-strategy">Walkthrough · First Strategy</a></li>
</ul>
```

- [ ] **Step 3: Commit**

```bash
git add docs/user-guide/content/zh/concepts/01-what-is-quant.html docs/user-guide/content/en/concepts/01-what-is-quant.html
git commit -m "feat(user-guide): add concept 01 — what is quant trading"
```

### Task 2.2 – 2.10: Concepts 02–10

Each concept chapter follows the same author–commit pattern. For brevity the plan lists titles, the **required body structure**, and the **citations to embed in `<section class="sources">`** — author each partial accordingly (400–800 zh-chars body, blockquote lede, one inline SVG, body, "在 AlphaLoop 中" links, sources).

| Concept | Slug | Required citations |
|---|---|---|
| 02 SMC / ICT in 5 Minutes | `02-smc-ict` | [TradeThePool — SMC Terminology](https://tradethepool.com/technical-skill/smart-money-concepts-terminology) · [DailyPriceAction — SMC Definitive Guide](https://dailypriceaction.com/blog/smart-money-concepts) |
| 03 Market Structure: BOS & CHoCH | `03-market-structure` | [FluxCharts — BOS Explained](https://www.fluxcharts.com/articles/break-of-structure-bos-explained) · [LuxAlgo — MSS in ICT](https://www.luxalgo.com/blog/market-structure-shifts-mss-in-ict-trading) |
| 04 Order Blocks | `04-order-block` | TradeThePool · DailyPriceAction |
| 05 Fair Value Gaps | `05-fair-value-gap` | DailyPriceAction |
| 06 Liquidity Pools, Sweeps, BSL/SSL | `06-liquidity` | DailyPriceAction |
| 07 Multi-Timeframe & Shadow Window | `07-multi-timeframe` | [TradingStrategyGuides — MTF Top-Down](https://tradingstrategyguides.com/day-10-multi-timeframe-analysis-ict-smc-the-top-down-approach-explained) |
| 08 Risk Basics | `08-risk-basics` | (internal) |
| 09 Backtest / Dry-Run / Live | `09-dryrun-vs-live` | [Freqtrade Backtesting docs](https://www.freqtrade.io/en/2023.8/backtesting) |
| 10 AI Roles in AlphaLoop | `10-ai-roles` | (internal) |

For each row 2.2 – 2.10:

- [ ] **Step 1: Author zh partial** at `docs/user-guide/content/zh/concepts/<slug>.html`. Mandatory structure (omit "Sources" only when "(internal)"):

```html
<h1>{{中文标题}}</h1>
<p class="chapter-meta">概念 · {{NN}} / 10 · {{分钟}} 分钟</p>
<blockquote class="lede">{{一句话定义}}</blockquote>
<blockquote class="pull">{{外部权威引用 — 一段话}}<cite>— {{Source}}<sup class="cite">[1]</sup></cite></blockquote>
<svg class="diagram" viewBox="0 0 600 220" xmlns="http://www.w3.org/2000/svg">
  <!-- 自绘示意图: 蜡烛 / 区域 / 箭头, 仅用 var-equivalent 色: #e8eaee #00ff9d #ff5470 #f5c542 #5e636d -->
</svg>
<h2>为什么重要</h2>
<p>…</p>
<h2>怎么识别</h2>
<p>…</p>
<h2>常见坑</h2>
<p>…</p>
<h2>在 AlphaLoop 中</h2>
<ul><li><a href="#/pages/structure/market-structure">市场结构</a></li><li><a href="#/pages/structure/structure-matrix">结构矩阵</a></li></ul>
<section class="sources">
  <h3>引用</h3>
  <ol>
    <li><a href="{{URL}}" target="_blank" rel="noreferrer noopener">{{Source title}}</a></li>
  </ol>
</section>
```

- [ ] **Step 2: Author en partial** mirroring structure at `docs/user-guide/content/en/concepts/<slug>.html`.
- [ ] **Step 3: Commit** the pair with message `feat(user-guide): add concept {{NN}} — {{english title}}`.

### Task 2.11: Cross-link audit

- [ ] **Step 1: Verify each concept chapter's "在 AlphaLoop 中" links resolve to existing routes**

Run: `grep -hoE 'href="#/[^"]+"' docs/user-guide/content/zh/concepts/*.html | sort -u`
Expected: every href matches an entry in `NAV` inside `assets/app.js`.

- [ ] **Step 2: Commit if any link was fixed**

```bash
git add docs/user-guide/content/
git commit -m "fix(user-guide): repair broken concept deep-links"
```

---

## Phase 3 — Page Chapters (25 chapters × 2 langs = 50 files)

Every page chapter follows the **7-section template** from the spec. The standard skeleton (use verbatim, adapt content):

```html
<h1>{{页面中文名}}</h1>
<p class="chapter-meta">页面手册 · {{Section}} · {{N}} 分钟</p>
<blockquote class="lede">{{一句话: 这个页面解决什么问题}}</blockquote>

<h2>1 · TL;DR</h2>
<p>…</p>

<h2>2 · 谁会用,什么时候用</h2>
<p>…</p>

<h2>3 · 页面解剖</h2>
<svg class="diagram" viewBox="0 0 600 320" xmlns="http://www.w3.org/2000/svg">
  <!-- 带 1️⃣ 2️⃣ 3️⃣ 数字标注的页面框线图 -->
</svg>
<ol>
  <li><strong>① …</strong> — 在这里看 {{什么}}</li>
  <li><strong>② …</strong> — …</li>
</ol>

<h2>4 · 关键指标怎么读</h2>
<h3>{{指标名}}</h3>
<p>什么意思 / 什么算好 / 什么算坏 / 怎么处置。</p>

<h2>5 · 常见操作 Step-by-Step</h2>
<ol>
  <li>点击 ② 区的 ⟳ 刷新</li>
  <li>…</li>
</ol>

<h2>6 · 幕后</h2>
<p>每 5s 调用 <code>/api/...</code>; Redis 命中则直出,缺失则服务计算 → mock 兜底。</p>

<h2>7 · 相关</h2>
<ul>
  <li>概念: <a href="#/concepts/04-order-block">订单块</a></li>
  <li>场景: <a href="#/walkthroughs/htf-tribunal-flow">HTF Tribunal 走查</a></li>
</ul>
```

### Task 3.X (Overview · 2 chapters)

- [ ] **Task 3.1**: `pages/overview/dashboard.{zh,en}.html` — Dashboard 总览。Highlight: workflow rail, learn card, AI 建议、市场情绪、机会矩阵、组合统计。Section names: 概览 / Overview.
- [ ] **Task 3.2**: `pages/overview/live-readiness.{zh,en}.html` — 实盘就绪 checklist (账户绑定 / 风控开关 / 干跑成绩 / Freqtrade 健康).

Each step:

- [ ] Author zh partial
- [ ] Author en partial
- [ ] Commit: `feat(user-guide): add page chapter — <slug>`

### Task 3.X (Strategy · 3 chapters)

- [ ] **Task 3.3**: `strategy-workspace` — 策略列表 / 状态 / 创建按钮 / 启停。
- [ ] **Task 3.4**: `strategy-canvas` — React DAG 编辑器 (节点类型 / 连线 / 校验 / 保存)。
- [ ] **Task 3.5**: `backtest-simulation` — 配置 / 区间 / 指标卡片 / 回撤曲线。

### Task 3.X (Structure · 3 chapters)

- [ ] **Task 3.6**: `market-structure` — Causal Storyboard, BOS/CHoCH 标注, 时间轴。
- [ ] **Task 3.7**: `structure-matrix` — HTF Tribunal 设计 (Fast Track 健康条 / 8-state rail / 240px 倒计时环 / Verdict / Evidence Matrix / Shadow Windows / Charges / Hearings). Cross-link spec `docs/superpowers/specs/2026-06-10-structure-matrix-htf-tribunal-design.md`.
- [ ] **Task 3.8**: `manipulation-radar` — wick hunt / spoof score / stop-run heat.

### Task 3.X (Execution · 3 chapters)

- [ ] **Task 3.9**: `execution-center` — 下单面板 / 模式 / 数量 / 风控预检。
- [ ] **Task 3.10**: `orders-positions` — 实时订单簿 / 持仓 / PnL。
- [ ] **Task 3.11**: `reconciliation-bus` — 对账事件流 / 漂移检测 / 重放。

### Task 3.X (Risk · 3 chapters)

- [ ] **Task 3.12**: `risk-center` — 总览面板 / 限额 / 当前敞口。
- [ ] **Task 3.13**: `stop-protection` — 止损规则 / 移动止损 / 时间止损。
- [ ] **Task 3.14**: `circuit-breakers` — 日内亏损断路器 / 异常波动断路器 / 历史触发。

### Task 3.X (AI Research · 4 chapters)

- [ ] **Task 3.15**: `ai-research-room` — Run 列表 / 阶段进度 / 候选策略评分。
- [ ] **Task 3.16**: `agent-platform` — Agent registry / 健康 / 配置 / 部署。
- [ ] **Task 3.17**: `signal-center` — 三层信号 (alpha / risk / context) / 融合 verdict。
- [ ] **Task 3.18**: `market-sentiment` — FinBERT 时间序列 / Top 头条 / 标签云。

### Task 3.X (Growth · 3 chapters)

- [ ] **Task 3.19**: `growth-review` — 周报 / 命中率 / 利润漏斗。
- [ ] **Task 3.20**: `failure-clustering` — 错误聚类卡片 / 失败原因 Top-N。
- [ ] **Task 3.21**: `strategy-optimization` — 自动调参 / 收敛曲线 / 接受变更。

### Task 3.X (System · 3 chapters)

- [ ] **Task 3.22**: `service-management` — Backend / Redis / Freqtrade 健康状态。
- [ ] **Task 3.23**: `data-source-management` — 交易所连接 / API key / 节流。
- [ ] **Task 3.24**: `settings` — 通用 / 显示 (含 "显示 Dashboard 学习卡" toggle) / 账户 / 调试。
- [ ] **Task 3.25**: link audit identical to Task 2.11 (run `grep` across `content/zh/pages/`).

For each Task 3.1 – 3.24:

- [ ] **Step 1: Author zh partial** at `docs/user-guide/content/zh/pages/<group>/<slug>.html` using the 7-section template.
- [ ] **Step 2: Author en partial** at `docs/user-guide/content/en/pages/<group>/<slug>.html`.
- [ ] **Step 3: Commit** with message `feat(user-guide): add page chapter — <group>/<slug>`.

---

## Phase 4 — Walkthroughs (5 chapters × 2 langs = 10 files)

Standard walkthrough skeleton:

```html
<h1>{{中文标题}}</h1>
<p class="chapter-meta">情景手册 · {{NN}} / 5 · {{分钟}} 分钟</p>
<blockquote class="lede">{{一句话: 这个场景要解决什么}}</blockquote>

<h2>开始之前 · 检查清单</h2>
<ul>
  <li>☐ 已登录 AlphaLoop</li>
  <li>☐ Freqtrade 干跑模式 OK (见 <a href="#/pages/system/service-management">服务管理</a>)</li>
</ul>

<h2>Step 1 · …</h2>
<p>去 <a href="#/pages/...">{{页面}}</a>,点 …</p>
<svg class="diagram" viewBox="0 0 600 200"></svg>

<h2>Step 2 · …</h2>
<p>…</p>

<h2>完成 · 自检</h2>
<ul>
  <li>☐ {{可观察到的成功标志}}</li>
</ul>
```

### Task 4.1 – 4.5

| # | Slug | 主线 |
|---|---|---|
| 4.1 | `first-strategy` | AI Research → Canvas → Backtest → Dry-run 一周 → Live small |
| 4.2 | `daily-trading-loop` | Dashboard → Market Structure → Structure Matrix → Signal Center → Execution |
| 4.3 | `htf-tribunal-flow` | LTF break → Shadow Window → HTF close → Verdict → Apply to Order Form |
| 4.4 | `risk-incident` | Circuit Breaker 触发 → Risk Center → 暂停策略 → 复盘 |
| 4.5 | `improve-strategy` | Growth Review → Failure Clustering → 参数调整 → 重回测 |

For each:

- [ ] **Step 1: zh partial** (skeleton above, fully fleshed prose).
- [ ] **Step 2: en partial** mirroring.
- [ ] **Step 3: Commit** `feat(user-guide): add walkthrough — <slug>`.

### Task 4.6: Final cross-link audit

- [ ] **Step 1: Verify** all `href="#/..."` resolve to existing partials in both languages.

Run:
```bash
python3 - <<'PY'
import json, os, re
root = "docs/user-guide"
nav = re.findall(r'path:\s*"(/[^"]+)"', open(f"{root}/assets/app.js").read())
paths = set(nav)
broken = []
for lang in ("zh","en"):
    for dp,_,fs in os.walk(f"{root}/content/{lang}"):
        for f in fs:
            if not f.endswith(".html"): continue
            text = open(os.path.join(dp,f)).read()
            for href in re.findall(r'href="#(/[^"]+)"', text):
                if href not in paths:
                    broken.append((lang, os.path.join(dp,f), href))
print("OK" if not broken else broken)
PY
```
Expected: `OK`.

- [ ] **Step 2: Commit** if anything was patched.

```bash
git add docs/user-guide/content/
git commit -m "fix(user-guide): repair cross-chapter deep-links"
```

---

## Phase 5 — macOS App Integration

### Task 5.1: Add L10n keys

**Files:**
- Create: `macos-app/AlphaLoop/Localization/L10n+Guide.swift`

- [ ] **Step 1: Author the file**

```swift
// L10n+Guide.swift — 用户指南文案
import Foundation

extension L10n {
    enum Guide {
        static var title: String          { zh("用户指南", en: "User Guide") }
        static var sidebarLabel: String   { zh("用户指南", en: "Guide") }
        static var dashboardTitle: String { zh("学习 AlphaLoop", en: "Learn AlphaLoop") }
        static var dashboardSubtitle: String { zh("5 分钟读完每个页面", en: "Understand every page in 5 minutes") }
        static var chipWelcome: String    { zh("欢迎", en: "Welcome") }
        static var chipConcepts: String   { zh("核心概念", en: "Core Concepts") }
        static var chipFirstStrategy: String { zh("第一个策略 →", en: "First Strategy →") }
        static var openFailed: String     { zh("无法打开用户指南", en: "Couldn't open the user guide") }
        static var restoreCard: String    { zh("显示 Dashboard 学习卡", en: "Show Dashboard learn card") }
        static var dismiss: String        { zh("收起", en: "Dismiss") }
    }
}
```

- [ ] **Step 2: Verify build**

Run: `cd macos-app && swift build`
Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add macos-app/AlphaLoop/Localization/L10n+Guide.swift
git commit -m "feat(macos): add L10n+Guide localization keys"
```

### Task 5.2: Add `Services/UserGuide.swift` opener

**Files:**
- Create: `macos-app/AlphaLoop/Services/UserGuide.swift`

- [ ] **Step 1: Author the helper**

```swift
// UserGuide.swift — 解析用户指南 HTML 路径并通过 NSWorkspace 打开
import AppKit
import Foundation

enum UserGuide {
    /// Open the user guide. Optional `anchor` is a hash route like "/concepts/" or "/walkthroughs/first-strategy".
    static func open(anchor: String? = nil) {
        guard let url = resolveURL(anchor: anchor) else {
            NSLog("[UserGuide] resolveURL returned nil")
            return
        }
        NSWorkspace.shared.open(url)
    }

    static func resolveURL(anchor: String? = nil) -> URL? {
        let base = locateIndex()
        guard var components = base.flatMap({ URLComponents(url: $0, resolvingAgainstBaseURL: false) }) else {
            return fallbackRemote(anchor: anchor)
        }
        if let anchor, !anchor.isEmpty {
            components.fragment = anchor.hasPrefix("/") ? anchor : "/\(anchor)"
        }
        return components.url
    }

    private static func locateIndex() -> URL? {
        // 1. Bundled inside the app (release builds with a Copy Files build phase).
        if let bundled = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "user-guide") {
            return bundled
        }
        // 2. Repo-relative for dev builds: walk up from the binary until we find docs/user-guide/index.html.
        var dir = Bundle.main.bundleURL
        for _ in 0..<8 {
            let candidate = dir.appendingPathComponent("docs/user-guide/index.html")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            dir.deleteLastPathComponent()
        }
        return nil
    }

    private static func fallbackRemote(anchor: String?) -> URL? {
        // Last-resort fallback so the button is never dead. Point to the in-repo HTML on GitHub.
        var s = "https://github.com/anthropics/phosphor-terminal/blob/main/docs/user-guide/index.html"
        if let anchor, !anchor.isEmpty {
            s += anchor.hasPrefix("#") ? anchor : "#\(anchor.hasPrefix("/") ? anchor : "/" + anchor)"
        }
        return URL(string: s)
    }
}
```

- [ ] **Step 2: Verify build**

Run: `cd macos-app && swift build`
Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add macos-app/AlphaLoop/Services/UserGuide.swift
git commit -m "feat(macos): add UserGuide service to open local guide HTML"
```

### Task 5.3: Add sidebar entry component

**Files:**
- Create: `macos-app/AlphaLoop/Views/AppShell/SidebarUserGuideLink.swift`
- Modify: `macos-app/AlphaLoop/Views/AppShell/SidebarView.swift` (insert `SidebarUserGuideLink()` between `Spacer(minLength: 0)` and `sidebarFooter`)

- [ ] **Step 1: Author the link view**

```swift
// SidebarUserGuideLink.swift — 侧边栏底部"用户指南"入口
import SwiftUI

struct SidebarUserGuideLink: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Button {
            UserGuide.open()
        } label: {
            HStack(spacing: PulseSpacing.sm) {
                Image(systemName: "book.closed")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 18)
                if !appState.sidebarCollapsed {
                    Text(L10n.Guide.sidebarLabel)
                        .font(PulseFonts.body)
                    Spacer(minLength: 0)
                }
            }
            .foregroundStyle(PulseColors.textSecondary)
            .padding(.horizontal, PulseSpacing.sm)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(L10n.Guide.title)
    }
}
```

- [ ] **Step 2: Read SidebarView.swift around line 40-50 to confirm exact context**

Run: open the file and locate the `Spacer(minLength: 0)` / `sidebarFooter` boundary.

- [ ] **Step 3: Insert the link**

In `SidebarView.swift`, change:

```swift
                Spacer(minLength: 0)
                sidebarFooter
```

to:

```swift
                Spacer(minLength: 0)
                SidebarUserGuideLink()
                    .padding(.horizontal, PulseSpacing.sm)
                sidebarFooter
```

- [ ] **Step 4: Verify build + manual click test**

Run: `cd macos-app && swift build && swift run`
Expected: app launches; bottom-of-sidebar shows "📖 用户指南"; clicking opens the HTML in default browser.

- [ ] **Step 5: Commit**

```bash
git add macos-app/AlphaLoop/Views/AppShell/SidebarUserGuideLink.swift macos-app/AlphaLoop/Views/AppShell/SidebarView.swift
git commit -m "feat(macos): wire user-guide link into sidebar"
```

### Task 5.4: Add Dashboard learn card

**Files:**
- Create: `macos-app/AlphaLoop/Views/Dashboard/LearnAlphaLoopCard.swift`
- Modify: `macos-app/AlphaLoop/Views/Dashboard/DashboardView.swift` (insert `LearnAlphaLoopCard()` at top of `mainContent` VStack)

- [ ] **Step 1: Author the card**

```swift
// LearnAlphaLoopCard.swift — Dashboard 顶部首次发现卡片
import SwiftUI

struct LearnAlphaLoopCard: View {
    @AppStorage("hideLearnAlphaLoopCard") private var hidden: Bool = false

    var body: some View {
        if hidden { EmptyView() } else { card }
    }

    @ViewBuilder private var card: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.md) {
            HStack(alignment: .top) {
                HStack(spacing: PulseSpacing.sm) {
                    Image(systemName: "sparkle")
                        .foregroundStyle(PulseColors.accent)
                    L10nText("学习 AlphaLoop", en: "Learn AlphaLoop")
                        .font(PulseFonts.displayHeading)
                        .foregroundStyle(PulseColors.textPrimary)
                }
                Spacer()
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { hidden = true }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(PulseColors.textMuted)
                }
                .buttonStyle(.plain)
                .help(L10n.Guide.dismiss)
            }

            L10nText("5 分钟读完每个页面 · understand every page in 5 minutes",
                     en: "5 minutes per page · catch up on every screen")
                .font(PulseFonts.body)
                .foregroundStyle(PulseColors.textSecondary)

            HStack(spacing: PulseSpacing.sm) {
                chip(L10n.Guide.chipWelcome,        anchor: "/welcome")
                chip(L10n.Guide.chipConcepts,       anchor: "/concepts/01-what-is-quant")
                chip(L10n.Guide.chipFirstStrategy,  anchor: "/walkthroughs/first-strategy",
                     emphasized: true)
            }
        }
        .padding(PulseSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PulseColors.cardBackground, in: RoundedRectangle(cornerRadius: PulseRadii.card))
        .overlay(
            RoundedRectangle(cornerRadius: PulseRadii.card)
                .stroke(PulseColors.border, lineWidth: 1)
        )
    }

    private func chip(_ text: String, anchor: String, emphasized: Bool = false) -> some View {
        Button { UserGuide.open(anchor: anchor) } label: {
            Text(text)
                .font(PulseFonts.monoLabel)
                .padding(.horizontal, PulseSpacing.md)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(emphasized
                                   ? PulseColors.accent.opacity(0.15)
                                   : Color.white.opacity(0.04))
                )
                .overlay(
                    Capsule().stroke(emphasized ? PulseColors.accent : PulseColors.border, lineWidth: 1)
                )
                .foregroundStyle(emphasized ? PulseColors.accent : PulseColors.textPrimary)
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 2: Insert into DashboardView.swift**

Find (around line 736-738):

```swift
    private var mainContent: some View {
        VStack(spacing: PulseSpacing.lg) {
            TradingWorkflowRailView(...)
```

Change to:

```swift
    private var mainContent: some View {
        VStack(spacing: PulseSpacing.lg) {
            LearnAlphaLoopCard()
            TradingWorkflowRailView(...)
```

- [ ] **Step 3: Verify build + manual visual check**

Run: `cd macos-app && swift build && swift run`
Expected: Dashboard shows the learn card at top; dismiss persists; chips open the guide at the right anchor.

- [ ] **Step 4: Commit**

```bash
git add macos-app/AlphaLoop/Views/Dashboard/LearnAlphaLoopCard.swift macos-app/AlphaLoop/Views/Dashboard/DashboardView.swift
git commit -m "feat(macos): add LearnAlphaLoopCard at top of Dashboard"
```

### Task 5.5: Settings restore toggle

**Files:**
- Modify: `macos-app/AlphaLoop/Views/Settings/SettingsView.swift` (or the Display tab)

- [ ] **Step 1: Locate the Display section**

Run: `grep -n "Display\|显示" macos-app/AlphaLoop/Views/Settings/*.swift`

- [ ] **Step 2: Add a Toggle bound to `UserDefaults["hideLearnAlphaLoopCard"]` inverted**

Inside the Display group, append:

```swift
Toggle(isOn: Binding(
    get: { !UserDefaults.standard.bool(forKey: "hideLearnAlphaLoopCard") },
    set: { UserDefaults.standard.set(!$0, forKey: "hideLearnAlphaLoopCard") }
)) {
    Text(L10n.Guide.restoreCard)
}
```

- [ ] **Step 3: Verify build**

Run: `cd macos-app && swift build`
Expected: success.

- [ ] **Step 4: Commit**

```bash
git add macos-app/AlphaLoop/Views/Settings/
git commit -m "feat(macos): expose 'show Dashboard learn card' toggle in Settings"
```

---

## Phase 6 — Polish & Final QA

### Task 6.1: Browser sanity sweep

- [ ] **Step 1: Open the guide and click every sidebar entry in both languages**

Run: `open docs/user-guide/index.html`
Expected: no 404, no console errors, lang toggle preserves selected chapter.

- [ ] **Step 2: ⌘K search**

Type "影子" → expect Multi-Timeframe + Shadow Window entries.
Type "structure matrix" → expect Structure Matrix entry.

- [ ] **Step 3: prefers-reduced-motion**

Toggle macOS "Reduce motion." Expected: fade-up animation disabled.

### Task 6.2: README pointer in `docs/README.md`

**Files:**
- Modify: `docs/README.md`

- [ ] **Step 1: Add a section "📘 user-guide/" under the existing top-level navigation**

```markdown
## 📘 user-guide/ — 用户指南（静态 HTML 站点）

`docs/user-guide/index.html` 双击即可打开，零依赖。包含 10 章概念、25 章页面手册、5 章情景手册。app 内通过侧边栏 "用户指南" 入口和 Dashboard 顶部 "Learn AlphaLoop" 卡片打开。设计稿见 `superpowers/specs/2026-06-10-user-guide-site-design.md`。
```

- [ ] **Step 2: Commit**

```bash
git add docs/README.md
git commit -m "docs: link user-guide HTML site from docs/README"
```

### Task 6.3: macOS test suite + final swift build

- [ ] **Step 1: Tests**

Run: `cd macos-app && swift test`
Expected: tests pass (no regression).

- [ ] **Step 2: Release-style build smoke**

Run: `cd macos-app && swift build -c release`
Expected: success.

- [ ] **Step 3: Final commit (if any nits)** then tag the feature complete.

---

## Verification Checklist

- [ ] All 40 chapter routes resolve in zh and en (Task 4.6 script returns OK)
- [ ] Sidebar entry visible in both expanded and collapsed sidebar states
- [ ] Dashboard card dismissible and persisted across app restart
- [ ] Settings toggle restores the card
- [ ] `open docs/user-guide/index.html` works from a fresh checkout (no build step)
- [ ] `swift build` succeeds (CI green)
- [ ] `docs/README.md` references the new site
