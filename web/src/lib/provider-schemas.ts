/**
 * Provider Schema 映射(与后端 ProviderConfigSchema 对齐):
 * 每个 provider 的 config/credentials 字段、默认值、标签。
 * 用于连接页动态渲染表单。字段名与后端 adapter 的 config / credentials 对齐。
 */

export interface FieldDef {
  key: string;
  label: string;
  type: "text" | "password" | "number" | "url" | "boolean";
  defaultValue?: string;
  placeholder?: string;
  required?: boolean;
  hint?: string;
}

export interface ProviderSchema {
  category: string;
  name: string;
  label: string;
  configFields: FieldDef[];
  credentialFields: FieldDef[];
}

/* ---------- LLM ---------- */

const LLM_PROVIDERS: ProviderSchema[] = [
  {
    category: "llm", name: "openai", label: "OpenAI",
    configFields: [
      { key: "base_url", label: "Base URL", type: "url", defaultValue: "https://api.openai.com/v1", hint: "API 端点地址" },
      { key: "model", label: "模型", type: "text", defaultValue: "gpt-4o", placeholder: "gpt-4o / gpt-4o-mini / o1", hint: "默认使用的模型" },
    ],
    credentialFields: [
      { key: "api_key", label: "API Key", type: "password", required: true, placeholder: "sk-..." },
    ],
  },
  {
    category: "llm", name: "anthropic", label: "Anthropic",
    configFields: [
      { key: "model", label: "模型", type: "text", defaultValue: "claude-sonnet-4-20250514", placeholder: "claude-sonnet-4-20250514", hint: "默认使用的模型" },
    ],
    credentialFields: [
      { key: "api_key", label: "API Key", type: "password", required: true, placeholder: "sk-ant-..." },
    ],
  },
  {
    category: "llm", name: "deepseek", label: "DeepSeek",
    configFields: [
      { key: "base_url", label: "Base URL", type: "url", defaultValue: "https://api.deepseek.com/v1", hint: "API 端点地址" },
      { key: "model", label: "模型", type: "text", defaultValue: "deepseek-chat", placeholder: "deepseek-chat / deepseek-reasoner" },
    ],
    credentialFields: [
      { key: "api_key", label: "API Key", type: "password", required: true, placeholder: "sk-..." },
    ],
  },
  {
    category: "llm", name: "ollama", label: "Ollama (本地)",
    configFields: [
      { key: "base_url", label: "Base URL", type: "url", defaultValue: "http://localhost:11434", hint: "Ollama 服务地址" },
      { key: "model", label: "模型", type: "text", defaultValue: "qwen2.5:7b", placeholder: "qwen2.5:7b / llama3:8b" },
    ],
    credentialFields: [],
  },
  {
    category: "llm", name: "qwen", label: "通义千问",
    configFields: [
      { key: "base_url", label: "Base URL", type: "url", defaultValue: "https://dashscope.aliyuncs.com/compatible-mode/v1", hint: "阿里云 DashScope 端点" },
      { key: "model", label: "模型", type: "text", defaultValue: "qwen-plus", placeholder: "qwen-plus / qwen-max" },
    ],
    credentialFields: [
      { key: "api_key", label: "API Key", type: "password", required: true, placeholder: "sk-..." },
    ],
  },
  {
    category: "llm", name: "zhipu", label: "智谱 GLM",
    configFields: [
      { key: "base_url", label: "Base URL", type: "url", defaultValue: "https://open.bigmodel.cn/api/paas/v4", hint: "智谱开放平台端点" },
      { key: "model", label: "模型", type: "text", defaultValue: "glm-4", placeholder: "glm-4 / glm-4-flash" },
    ],
    credentialFields: [
      { key: "api_key", label: "API Key", type: "password", required: true },
    ],
  },
  {
    category: "llm", name: "moonshot", label: "Moonshot (Kimi)",
    configFields: [
      { key: "base_url", label: "Base URL", type: "url", defaultValue: "https://api.moonshot.cn/v1", hint: "Moonshot 端点" },
      { key: "model", label: "模型", type: "text", defaultValue: "moonshot-v1-8k", placeholder: "moonshot-v1-8k / moonshot-v1-32k" },
    ],
    credentialFields: [
      { key: "api_key", label: "API Key", type: "password", required: true, placeholder: "sk-..." },
    ],
  },
  {
    category: "llm", name: "gemini", label: "Google Gemini",
    configFields: [
      { key: "model", label: "模型", type: "text", defaultValue: "gemini-2.0-flash", placeholder: "gemini-2.0-flash / gemini-2.5-pro" },
    ],
    credentialFields: [
      { key: "api_key", label: "API Key", type: "password", required: true },
    ],
  },
  {
    category: "llm", name: "groq", label: "Groq",
    configFields: [
      { key: "base_url", label: "Base URL", type: "url", defaultValue: "https://api.groq.com/openai/v1", hint: "Groq 端点" },
      { key: "model", label: "模型", type: "text", defaultValue: "llama-3.3-70b-versatile", placeholder: "llama-3.3-70b-versatile" },
    ],
    credentialFields: [
      { key: "api_key", label: "API Key", type: "password", required: true, placeholder: "gsk_..." },
    ],
  },
  {
    category: "llm", name: "azure_openai", label: "Azure OpenAI",
    configFields: [
      { key: "endpoint", label: "Endpoint", type: "url", placeholder: "https://your-resource.openai.azure.com", required: true, hint: "Azure 资源端点" },
      { key: "deployment", label: "部署名", type: "text", placeholder: "gpt-4o", required: true, hint: "Azure 部署名称" },
      { key: "model", label: "模型", type: "text", defaultValue: "gpt-4o", placeholder: "gpt-4o" },
    ],
    credentialFields: [
      { key: "api_key", label: "API Key", type: "password", required: true },
    ],
  },
];

/* ---------- CEX ---------- */

const CEX_PROVIDERS: ProviderSchema[] = [
  {
    category: "cex", name: "binance", label: "Binance",
    configFields: [
      { key: "base_url", label: "Base URL", type: "url", defaultValue: "https://api.binance.com" },
    ],
    credentialFields: [
      { key: "api_key", label: "API Key", type: "password", required: true },
      { key: "api_secret", label: "API Secret", type: "password", required: true },
    ],
  },
  {
    category: "cex", name: "okx", label: "OKX",
    configFields: [
      { key: "base_url", label: "Base URL", type: "url", defaultValue: "https://www.okx.com" },
    ],
    credentialFields: [
      { key: "api_key", label: "API Key", type: "password", required: true },
      { key: "api_secret", label: "API Secret", type: "password", required: true },
      { key: "passphrase", label: "Passphrase", type: "password", required: true, hint: "创建 API 时设置的密码" },
    ],
  },
  {
    category: "cex", name: "bybit", label: "Bybit",
    configFields: [
      { key: "base_url", label: "Base URL", type: "url", defaultValue: "https://api.bybit.com" },
    ],
    credentialFields: [
      { key: "api_key", label: "API Key", type: "password", required: true },
      { key: "api_secret", label: "API Secret", type: "password", required: true },
    ],
  },
  {
    category: "cex", name: "bitget", label: "Bitget",
    configFields: [
      { key: "base_url", label: "Base URL", type: "url", defaultValue: "https://api.bitget.com" },
    ],
    credentialFields: [
      { key: "api_key", label: "API Key", type: "password", required: true },
      { key: "api_secret", label: "API Secret", type: "password", required: true },
      { key: "passphrase", label: "Passphrase", type: "password", required: true },
    ],
  },
];

/* ---------- Notification ---------- */

const NOTIFICATION_PROVIDERS: ProviderSchema[] = [
  {
    category: "notification", name: "telegram", label: "Telegram",
    configFields: [
      { key: "dry_run", label: "只记录不发送", type: "boolean", defaultValue: "true", hint: "打开时不向 Telegram 发消息" },
    ],
    credentialFields: [
      { key: "bot_token", label: "Bot Token", type: "password", required: true, placeholder: "123456:ABC-DEF..." },
      { key: "chat_id", label: "Chat ID", type: "text", required: true, placeholder: "-1001234567890" },
    ],
  },
  {
    category: "notification", name: "discord", label: "Discord",
    configFields: [],
    credentialFields: [
      { key: "webhook_url", label: "Webhook URL", type: "url", required: true, placeholder: "https://discord.com/api/webhooks/..." },
    ],
  },
  {
    category: "notification", name: "webhook", label: "自定义 Webhook",
    configFields: [
      { key: "url", label: "Webhook URL", type: "url", required: true, placeholder: "https://example.com/hook" },
    ],
    credentialFields: [
      { key: "auth_header", label: "Authorization（可选）", type: "password", placeholder: "Bearer ..." },
    ],
  },
  {
    category: "notification", name: "email", label: "邮件",
    configFields: [
      { key: "host", label: "SMTP 服务器", type: "text", required: true, placeholder: "smtp.gmail.com" },
      { key: "port", label: "SMTP 端口", type: "number", defaultValue: "587" },
    ],
    credentialFields: [
      { key: "username", label: "用户名", type: "text", required: true },
      { key: "password", label: "密码", type: "password", required: true },
    ],
  },
];

/* ---------- Market Data ---------- */

const MARKET_DATA_PROVIDERS: ProviderSchema[] = [
  {
    category: "market_data", name: "kline", label: "K线数据",
    configFields: [
      { key: "symbols", label: "标的", type: "text", defaultValue: "BTC/USDT,ETH/USDT", hint: "逗号分隔" },
    ],
    credentialFields: [],
  },
  {
    category: "market_data", name: "orderbook", label: "订单簿",
    configFields: [
      { key: "symbols", label: "标的", type: "text", defaultValue: "BTC/USDT,ETH/USDT", hint: "逗号分隔" },
    ],
    credentialFields: [],
  },
  {
    category: "market_data", name: "funding", label: "资金费率",
    configFields: [
      { key: "symbols", label: "标的", type: "text", defaultValue: "BTC/USDT,ETH/USDT", hint: "逗号分隔" },
    ],
    credentialFields: [],
  },
  {
    category: "market_data", name: "oi", label: "持仓量",
    configFields: [
      { key: "symbols", label: "标的", type: "text", defaultValue: "BTC/USDT,ETH/USDT", hint: "逗号分隔" },
    ],
    credentialFields: [],
  },
];

/* ---------- Onchain ---------- */

const ONCHAIN_PROVIDERS: ProviderSchema[] = [
  {
    category: "onchain", name: "cryptoquant", label: "CryptoQuant",
    configFields: [],
    credentialFields: [
      { key: "api_key", label: "API Key", type: "password", required: true },
    ],
  },
  {
    category: "onchain", name: "glassnode", label: "Glassnode",
    configFields: [],
    credentialFields: [
      { key: "api_key", label: "API Key", type: "password", required: true },
    ],
  },
  {
    category: "onchain", name: "whale_alert", label: "Whale Alert",
    configFields: [],
    credentialFields: [
      { key: "api_key", label: "API Key", type: "password", required: true },
    ],
  },
];

/* ---------- News ---------- */

const NEWS_PROVIDERS: ProviderSchema[] = [
  {
    category: "news", name: "cryptocompare_news", label: "CryptoCompare News",
    configFields: [],
    credentialFields: [
      { key: "api_key", label: "API Key", type: "password", required: true },
    ],
  },
  {
    category: "news", name: "cryptopanic", label: "CryptoPanic",
    configFields: [],
    credentialFields: [
      { key: "api_key", label: "API Key", type: "password", required: true },
    ],
  },
];

/* ---------- Social ---------- */

const SOCIAL_PROVIDERS: ProviderSchema[] = [
  {
    category: "social", name: "x", label: "X",
    configFields: [],
    credentialFields: [
      { key: "api_key", label: "Bearer Token", type: "password", required: true, placeholder: "AAAA..." },
    ],
  },
  {
    category: "social", name: "cryptocompare_social", label: "CryptoCompare Social",
    configFields: [],
    credentialFields: [
      { key: "api_key", label: "API Key", type: "password", required: true },
    ],
  },
  {
    category: "social", name: "lunarcrush", label: "LunarCrush",
    configFields: [],
    credentialFields: [
      { key: "api_key", label: "API Key", type: "password", required: true },
    ],
  },
];

/* ---------- DEX ---------- */

const DEX_PROVIDERS: ProviderSchema[] = [
  {
    category: "dex", name: "hyperliquid", label: "Hyperliquid",
    configFields: [],
    credentialFields: [
      { key: "private_key", label: "Private Key", type: "password", required: true },
    ],
  },
  {
    category: "dex", name: "dydx", label: "dYdX",
    configFields: [],
    credentialFields: [
      { key: "private_key", label: "Private Key", type: "password", required: true },
    ],
  },
  {
    category: "dex", name: "gmx", label: "GMX",
    configFields: [],
    credentialFields: [
      { key: "private_key", label: "Private Key", type: "password", required: true },
    ],
  },
];

/* ---------- 汇总 ---------- */

export const ALL_PROVIDER_SCHEMAS: ProviderSchema[] = [
  ...LLM_PROVIDERS,
  ...CEX_PROVIDERS,
  ...NOTIFICATION_PROVIDERS,
  ...MARKET_DATA_PROVIDERS,
  ...ONCHAIN_PROVIDERS,
  ...NEWS_PROVIDERS,
  ...SOCIAL_PROVIDERS,
  ...DEX_PROVIDERS,
];

/** 按 category 分组 */
export function providersByCategory(category: string): ProviderSchema[] {
  return ALL_PROVIDER_SCHEMAS.filter((s) => s.category === category);
}

/** 按 category + name 查找 */
export function findProviderSchema(category: string, name: string): ProviderSchema | undefined {
  return ALL_PROVIDER_SCHEMAS.find((s) => s.category === category && s.name === name);
}

/** 分类中文名 */
export const CATEGORY_LABELS: Record<string, string> = {
  llm: "模型",
  cex: "交易所",
  dex: "DEX",
  notification: "通知",
  market_data: "行情",
  onchain: "链上",
  news: "新闻",
  social: "社交",
};

/** 连接页分组。外部账号只从这里进入。 */
export const CONNECTION_GROUPS: { id: string; label: string; categories: string[] }[] = [
  { id: "trade", label: "交易", categories: ["cex", "dex"] },
  { id: "market", label: "行情", categories: ["market_data"] },
  { id: "feed", label: "消息", categories: ["social", "news"] },
  { id: "chain", label: "链上", categories: ["onchain"] },
  { id: "notify", label: "通知", categories: ["notification"] },
  { id: "model", label: "模型", categories: ["llm"] },
];

export interface ConnectionMeta {
  purpose: string;
  href?: string;
  hrefLabel?: string;
}

/** 需要跳到对方平台、或一句话说明用途的连接。其余用分组默认说明。 */
export const CONNECTION_META: Record<string, ConnectionMeta> = {
  "cex/binance": {
    purpose: "按币安现货模拟盘文档：登录主站后进 Demo Trading，在 API Key Management 创建密钥。请求把 https://api.binance.com/api 换成 https://demo-api.binance.com/api。两套密钥不能混用。只开交易，不要开提现。",
    href: "https://demo.binance.com/en/my/settings/api-management",
    hrefLabel: "去模拟盘 API 管理",
  },
  "cex/okx": {
    purpose: "OKX 账户。创建密钥时记下 Passphrase。",
    href: "https://www.okx.com/account/my-api",
    hrefLabel: "去 OKX 创建密钥",
  },
  "cex/bybit": {
    purpose: "Bybit 账户。只开交易权限。",
    href: "https://www.bybit.com/app/user/api-management",
    hrefLabel: "去 Bybit 创建密钥",
  },
  "cex/bitget": {
    purpose: "Bitget 账户。创建密钥时记下 Passphrase。",
    href: "https://www.bitget.com/account/newapi",
    hrefLabel: "去 Bitget 创建密钥",
  },
  "dex/hyperliquid": {
    purpose: "Hyperliquid 钱包私钥。拿到私钥就能动这笔钱。",
    href: "https://app.hyperliquid.xyz/API",
    hrefLabel: "打开 Hyperliquid",
  },
  "dex/dydx": {
    purpose: "dYdX 钱包私钥。拿到私钥就能动这笔钱。",
    href: "https://dydx.trade/",
    hrefLabel: "打开 dYdX",
  },
  "dex/gmx": {
    purpose: "GMX 钱包私钥。拿到私钥就能动这笔钱。",
    href: "https://app.gmx.io/",
    hrefLabel: "打开 GMX",
  },
  "social/x": {
    purpose: "读取帖子。在开发者平台申请只读的 Bearer Token。",
    href: "https://developer.x.com/",
    hrefLabel: "去 X 开发者平台",
  },
  "social/lunarcrush": {
    purpose: "币种社交热度。没有 X 密钥时可以先用这一路。",
    href: "https://lunarcrush.com/developers",
    hrefLabel: "去 LunarCrush 取 Key",
  },
  "social/cryptocompare_social": {
    purpose: "CryptoCompare 社交统计。",
    href: "https://www.cryptocompare.com/cryptopian/api-keys",
    hrefLabel: "去 CryptoCompare 取 Key",
  },
  "news/cryptocompare_news": {
    purpose: "CryptoCompare 新闻。",
    href: "https://www.cryptocompare.com/cryptopian/api-keys",
    hrefLabel: "去 CryptoCompare 取 Key",
  },
  "news/cryptopanic": {
    purpose: "CryptoPanic 新闻流。",
    href: "https://cryptopanic.com/developers/api/",
    hrefLabel: "去 CryptoPanic 取 Key",
  },
  "onchain/whale_alert": {
    purpose: "大额转账。三个链上来源至少配一个。",
    href: "https://whale-alert.io/",
    hrefLabel: "去 Whale Alert",
  },
  "onchain/glassnode": {
    purpose: "链上指标，例如 SOPR。",
    href: "https://studio.glassnode.com/settings/api",
    hrefLabel: "去 Glassnode",
  },
  "onchain/cryptoquant": {
    purpose: "交易所流入流出等链上数据。",
    href: "https://cryptoquant.com/mypage/api",
    hrefLabel: "去 CryptoQuant",
  },
  "notification/telegram": {
    purpose: "把告警发到一个群。默认只记录，不真正发送。",
    href: "https://t.me/BotFather",
    hrefLabel: "去 BotFather",
  },
  "notification/discord": {
    purpose: "把告警发到一个 Discord 频道。",
    href: "https://discord.com/developers/applications",
    hrefLabel: "去 Discord 开发者平台",
  },
  "notification/webhook": {
    purpose: "把告警 POST 到你自己的地址。",
  },
  "notification/email": {
    purpose: "用 SMTP 发告警邮件。",
  },
  "llm/openai": {
    purpose: "研究用的模型。",
    href: "https://platform.openai.com/api-keys",
    hrefLabel: "去 OpenAI 取 Key",
  },
  "llm/anthropic": {
    purpose: "研究用的模型。",
    href: "https://console.anthropic.com/settings/keys",
    hrefLabel: "去 Anthropic 取 Key",
  },
  "llm/deepseek": {
    purpose: "研究用的模型。",
    href: "https://platform.deepseek.com/api_keys",
    hrefLabel: "去 DeepSeek 取 Key",
  },
  "llm/ollama": {
    purpose: "本机模型，不需要密钥。先在这台机器上启动 Ollama。",
    href: "https://ollama.com/download",
    hrefLabel: "下载 Ollama",
  },
  "llm/qwen": {
    purpose: "通义千问。",
    href: "https://bailian.console.aliyun.com/",
    hrefLabel: "去阿里云取 Key",
  },
  "llm/zhipu": {
    purpose: "智谱 GLM。",
    href: "https://open.bigmodel.cn/usercenter/apikeys",
    hrefLabel: "去智谱取 Key",
  },
  "llm/moonshot": {
    purpose: "Kimi / Moonshot。",
    href: "https://platform.moonshot.cn/console/api-keys",
    hrefLabel: "去 Moonshot 取 Key",
  },
  "llm/gemini": {
    purpose: "Google Gemini。",
    href: "https://aistudio.google.com/apikey",
    hrefLabel: "去 Google AI Studio",
  },
  "llm/groq": {
    purpose: "Groq 上的开源模型。",
    href: "https://console.groq.com/keys",
    hrefLabel: "去 Groq 取 Key",
  },
  "llm/azure_openai": {
    purpose: "Azure 上的 OpenAI 部署。Endpoint 和部署名都要填。",
    href: "https://portal.azure.com/",
    hrefLabel: "打开 Azure 门户",
  },
  "market_data/kline": { purpose: "记下要看的 K 线标的。健康检查只探 Binance 公开接口。" },
  "market_data/orderbook": { purpose: "记下要看的订单簿标的。健康检查只探 Binance 公开接口。" },
  "market_data/funding": { purpose: "记下要看的资金费率标的。健康检查只探 Binance 公开接口。" },
  "market_data/oi": { purpose: "记下要看的持仓量标的。健康检查只探 Binance 公开接口。" },
};