import { useState } from 'react'
import { Save, Shield, Bell, Key, Server } from 'lucide-react'

interface SettingsSection {
  id: string
  label: string
  icon: React.ElementType
}

const sections: SettingsSection[] = [
  { id: 'exchange', label: '交易所配置', icon: Server },
  { id: 'risk', label: '风控参数', icon: Shield },
  { id: 'notifications', label: '通知设置', icon: Bell },
  { id: 'api', label: 'API密钥', icon: Key },
]

export function SettingsPage() {
  const [activeSection, setActiveSection] = useState('exchange')

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold">系统设置</h1>

      <div className="flex gap-6">
        {/* Sidebar */}
        <div className="w-48 shrink-0 space-y-1">
          {sections.map(({ id, label, icon: Icon }) => (
            <button
              key={id}
              onClick={() => setActiveSection(id)}
              className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm transition-colors ${
                activeSection === id
                  ? 'bg-primary/15 text-primary'
                  : 'text-text-secondary hover:text-text-primary hover:bg-surface-hover'
              }`}
            >
              <Icon className="w-4 h-4" />
              {label}
            </button>
          ))}
        </div>

        {/* Content */}
        <div className="flex-1 bg-surface rounded-xl p-6 border border-border">
          {activeSection === 'exchange' && <ExchangeSettings />}
          {activeSection === 'risk' && <RiskSettings />}
          {activeSection === 'notifications' && <NotificationSettings />}
          {activeSection === 'api' && <APISettings />}
        </div>
      </div>
    </div>
  )
}

function ExchangeSettings() {
  return (
    <div className="space-y-6">
      <h2 className="text-lg font-medium">交易所配置</h2>
      <div className="space-y-4">
        <Field label="交易所" defaultValue="Binance" />
        <Field label="API Key" type="password" placeholder="输入 Binance API Key" />
        <Field label="API Secret" type="password" placeholder="输入 Binance API Secret" />
        <Field label="交易模式" defaultValue="现货" />
        <div className="flex items-center gap-3 pt-2">
          <label className="flex items-center gap-2 text-sm text-text-secondary">
            <input type="checkbox" className="rounded" defaultChecked /> 启用合约交易
          </label>
          <label className="flex items-center gap-2 text-sm text-text-secondary">
            <input type="checkbox" className="rounded" /> 模拟模式 (Dry-run)
          </label>
        </div>
      </div>
      <SaveButton />
    </div>
  )
}

function RiskSettings() {
  return (
    <div className="space-y-6">
      <h2 className="text-lg font-medium">风控参数</h2>
      <div className="space-y-4">
        <Field label="最大单笔亏损 (%)" type="number" defaultValue="2" />
        <Field label="策略最大回撤 (%)" type="number" defaultValue="15" />
        <Field label="单日总回撤 (%)" type="number" defaultValue="5" />
        <Field label="单品种最大仓位占比 (%)" type="number" defaultValue="30" />
        <Field label="高相关品种组总仓位上限 (%)" type="number" defaultValue="50" />
        <Field label="相关性预警阈值" type="number" defaultValue="0.8" />
        <div className="flex items-center gap-3 pt-2">
          <label className="flex items-center gap-2 text-sm text-text-secondary">
            <input type="checkbox" className="rounded" defaultChecked /> 触发风控时自动暂停策略
          </label>
        </div>
      </div>
      <SaveButton />
    </div>
  )
}

function NotificationSettings() {
  return (
    <div className="space-y-6">
      <h2 className="text-lg font-medium">通知设置</h2>
      <div className="space-y-4">
        <Field label="Telegram Bot Token" type="password" placeholder="输入 Bot Token" />
        <Field label="Telegram Chat ID" placeholder="输入 Chat ID" />
        <div className="space-y-2 pt-2">
          <label className="flex items-center gap-2 text-sm text-text-secondary">
            <input type="checkbox" className="rounded" defaultChecked /> 交易执行通知
          </label>
          <label className="flex items-center gap-2 text-sm text-text-secondary">
            <input type="checkbox" className="rounded" defaultChecked /> 风控预警通知
          </label>
          <label className="flex items-center gap-2 text-sm text-text-secondary">
            <input type="checkbox" className="rounded" defaultChecked /> 每日盈亏日报
          </label>
          <label className="flex items-center gap-2 text-sm text-text-secondary">
            <input type="checkbox" className="rounded" /> 相关性预警通知
          </label>
        </div>
      </div>
      <SaveButton />
    </div>
  )
}

function APISettings() {
  return (
    <div className="space-y-6">
      <h2 className="text-lg font-medium">API 密钥管理</h2>
      <div className="bg-background rounded-lg p-4 border border-border">
        <p className="text-sm text-text-secondary mb-3">
          所有 API 密钥均加密存储。建议使用环境变量或外部 Secret Vault 管理敏感信息。
        </p>
        <div className="space-y-3">
          <div className="flex items-center justify-between p-3 bg-surface rounded-lg">
            <div>
              <div className="text-sm font-medium">Binance API</div>
              <div className="text-xs text-text-muted">最后更新: 2026-04-28</div>
            </div>
            <span className="px-2 py-0.5 rounded text-xs bg-success/15 text-success">已配置</span>
          </div>
          <div className="flex items-center justify-between p-3 bg-surface rounded-lg">
            <div>
              <div className="text-sm font-medium">Telegram Bot</div>
              <div className="text-xs text-text-muted">未配置</div>
            </div>
            <span className="px-2 py-0.5 rounded text-xs bg-text-muted/15 text-text-muted">未配置</span>
          </div>
        </div>
      </div>
    </div>
  )
}

function Field({ label, type = 'text', defaultValue, placeholder }: {
  label: string; type?: string; defaultValue?: string; placeholder?: string
}) {
  return (
    <div>
      <label className="text-sm text-text-secondary block mb-1">{label}</label>
      <input
        type={type}
        defaultValue={defaultValue}
        placeholder={placeholder}
        className="w-full px-3 py-2 bg-background border border-border rounded-lg text-text-primary placeholder:text-text-muted focus:outline-none focus:border-primary text-sm"
      />
    </div>
  )
}

function SaveButton() {
  return (
    <button className="flex items-center gap-2 px-4 py-2 bg-primary text-white rounded-lg hover:bg-primary-hover transition-colors">
      <Save className="w-4 h-4" /> 保存设置
    </button>
  )
}
