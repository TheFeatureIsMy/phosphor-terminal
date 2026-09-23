/**
 * Provider Schema 映射(与后端 ProviderConfigSchema 对齐):
 * 每个 provider 的 config/credentials 字段、默认值、标签。
 * 用于 AddProviderDialog 动态渲染表单。
 */

export interface FieldDef {
  key: string;
  label: string;
  type: "text" | "password" | "number" | "url";
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
      { key: "base_url", label: "Endpoint", type: "url", placeholder: "https://your-resource.openai.azure.com", required: true, hint: "Azure 资源端点" },
      { key: "model", label: "部署名", type: "text", placeholder: "gpt-4o", required: true, hint: "Azure 部署名称" },
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
      { key: "dry_run", label: "Dry Run", type: "text", defaultValue: "true", hint: "true=只记录不发送" },
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
    configFields: [],
    credentialFields: [
      { key: "url", label: "Webhook URL", type: "url", required: true },
      { key: "secret", label: "Secret(可选)", type: "password" },
    ],
  },
  {
    category: "notification", name: "email", label: "邮件",
    configFields: [
      { key: "smtp_host", label: "SMTP 服务器", type: "text", required: true, placeholder: "smtp.gmail.com" },
      { key: "smtp_port", label: "SMTP 端口", type: "number", defaultValue: "587" },
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
  llm: "LLM",
  cex: "交易所",
  dex: "DEX",
  notification: "通知",
  market_data: "行情数据",
  onchain: "链上数据",
  news: "新闻",
  social: "社交舆情",
};

/** 服务管理页可见的分类 */
export const SERVICE_CATEGORIES = ["llm", "notification", "cex"];
/** 数据源页可见的分类 */
export const DATA_SOURCE_CATEGORIES = ["market_data", "onchain", "news", "social", "dex"];