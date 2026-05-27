import { useState, useEffect } from 'react'
import { Save, Shield, Bell, Key, Server } from 'lucide-react'
import { PageHeader } from '@/components/ui/PageHeader'
import { Field, NumberField, PasswordField, Toggle } from '@/components/ui/FormControls'
import { useToast } from '@/components/ui/Toast'
import { useSettingsStore } from '@/stores/settings-store'
import { useSettingsSync } from '@/hooks/use-settings-sync'
import { cn } from '@/lib/utils'

type Section = 'exchange' | 'risk' | 'notifications' | 'api'

const sections: { id: Section; label: string; desc: string; icon: React.ElementType }[] = [
  { id: 'exchange', label: '交易所配置', desc: 'API连接与交易模式', icon: Server },
  { id: 'risk', label: '风控参数', desc: '止损、回撤与仓位限制', icon: Shield },
  { id: 'notifications', label: '通知设置', desc: 'Telegram通知渠道与类型', icon: Bell },
  { id: 'api', label: 'API密钥', desc: '第三方服务密钥管理', icon: Key },
]

export function SettingsPage() {
  const [activeSection, setActiveSection] = useState<Section>('exchange')
  const { loadSettings } = useSettingsSync()
  const { loadFromBackend } = useSettingsStore()

  useEffect(() => {
    loadSettings().then((settings) => {
      if (settings) loadFromBackend(settings)
    })
  }, [])

  return (
    <div className="space-y-5">
      <PageHeader title="系统设置" />

      <div className="flex gap-5 items-start">
        {/* Side Navigation - wider with descriptions */}
        <div className="hidden md:block w-60 shrink-0">
          <div className="card p-2 space-y-0.5 sticky top-20" style={{ borderRadius: '2px' }}>
            {sections.map(({ id, label, desc, icon: Icon }) => (
              <button
                key={id}
                onClick={() => setActiveSection(id)}
                className={cn(
                  'w-full text-left px-4 py-3 transition-all duration-200',
                  activeSection === id ? 'text-white' : 'text-text-muted hover:text-text-secondary hover:bg-white/[0.04]'
                )}
                style={activeSection === id ? {
                  background: 'rgba(0, 255, 157, 0.06)',
                  borderLeft: '2px solid #00ff9d',
                } : { borderLeft: '2px solid transparent' }}
              >
                <div className="flex items-center gap-2.5">
                  <Icon className="w-3.5 h-3.5 shrink-0" style={{ color: activeSection === id ? '#00ff9d' : '#555' }} />
                  <span className="text-[12px] font-mono font-medium">{label}</span>
                </div>
                <div className="text-[10px] font-mono mt-0.5 ml-[26px]" style={{ color: '#444' }}>{desc}</div>
              </button>
            ))}
          </div>
        </div>

        {/* Mobile: horizontal tab bar */}
        <div className="md:hidden w-full">
          <div className="flex gap-0 mb-4" style={{ borderBottom: '1px solid rgba(255,255,255,0.06)' }}>
            {sections.map(({ id, label, icon: Icon }) => (
              <button
                key={id}
                onClick={() => setActiveSection(id)}
                className={cn(
                  'flex-1 flex items-center justify-center gap-1.5 px-2 py-2.5 text-[11px] font-mono font-medium transition-all duration-150 relative',
                  activeSection === id ? 'text-[#e0e0e0]' : 'text-[#555]'
                )}
              >
                {activeSection === id && (
                  <div className="absolute bottom-0 left-0 right-0 h-[2px]" style={{ background: '#00ff9d' }} />
                )}
                <Icon className="w-3.5 h-3.5" /> <span className="truncate">{label}</span>
              </button>
            ))}
          </div>
        </div>

        {/* Content */}
        <div className="flex-1 min-w-0 card p-6">
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
  const { toast } = useToast()
  const { exchange, updateExchange } = useSettingsStore()
  const { saveSettings } = useSettingsSync()

  return (
    <div className="space-y-6">
      <SectionHeader title="交易所配置" desc="配置交易所API连接和交易模式" />

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div>
          <label className="text-[12px] text-text-muted block mb-2">交易所</label>
          <select defaultValue="binance" className="w-full px-4 py-2.5 text-[14px]">
            <option value="binance">Binance</option>
            <option value="okx">OKX</option>
            <option value="bybit">Bybit</option>
            <option value="gate">Gate.io</option>
          </select>
        </div>
        <div>
          <label className="text-[12px] text-text-muted block mb-2">交易模式</label>
          <select defaultValue="spot" className="w-full px-4 py-2.5 text-[14px]">
            <option value="spot">现货</option>
            <option value="futures">合约</option>
            <option value="margin">杠杆</option>
          </select>
        </div>
        <PasswordField label="API Key" placeholder="输入 Binance API Key" />
        <PasswordField label="API Secret" placeholder="输入 Binance API Secret" />
      </div>

      <div className="divider" />

      <div className="space-y-1">
        <Toggle label="启用合约交易" defaultChecked={exchange.futuresEnabled} />
        <Toggle label="模拟模式 (Dry-run)" description="开启后不会实际下单，仅模拟运行" defaultChecked={exchange.dryRun} />
      </div>

      <SaveButton onClick={async () => {
        const ok = await saveSettings({ default_exchange: exchange.exchange })
        toast(ok ? 'success' : 'error', ok ? '交易所配置已保存' : '保存失败')
      }} />
    </div>
  )
}

function RiskSettings() {
  const { toast } = useToast()
  return (
    <div className="space-y-6">
      <SectionHeader title="风控参数" desc="设置止损、回撤和仓位限制，保护资金安全" />

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <NumberField label="最大单笔亏损 (%)" defaultValue="2" />
        <NumberField label="策略最大回撤 (%)" defaultValue="15" />
        <NumberField label="单日总回撤 (%)" defaultValue="5" />
        <NumberField label="单品种最大仓位占比 (%)" defaultValue="30" />
        <NumberField label="高相关品种组总仓位上限 (%)" defaultValue="50" />
        <NumberField label="相关性预警阈值" defaultValue="0.8" step="0.1" />
      </div>

      <div className="divider" />

      <Toggle label="触发风控时自动暂停策略" defaultChecked description="当风控规则被触发时，自动暂停所有运行中的策略" />

      <SaveButton onClick={() => toast('success', '风控参数已保存')} />
    </div>
  )
}

function NotificationSettings() {
  const { toast } = useToast()
  return (
    <div className="space-y-6">
      <SectionHeader title="通知渠道" desc="配置Telegram Bot接收交易和风控通知" />

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <PasswordField label="Telegram Bot Token" placeholder="输入 Bot Token" />
        <Field label="Telegram Chat ID" placeholder="输入 Chat ID" />
      </div>

      <div className="divider" />

      <span className="terminal-label block">通知类型</span>
      <div className="space-y-1">
        <Toggle label="交易执行通知" defaultChecked description="策略下单、成交、撤单时通知" />
        <Toggle label="风控预警通知" defaultChecked description="触发止损、熔断、异常检测时通知" />
        <Toggle label="每日盈亏日报" defaultChecked description="每天 00:00 推送当日盈亏总结" />
        <Toggle label="相关性预警通知" description="品种间相关性超过阈值时通知" />
      </div>

      <SaveButton onClick={() => toast('success', '通知设置已保存')} />
    </div>
  )
}

function APISettings() {
  const { toast } = useToast()
  const [keys, setKeys] = useState([
    { id: 'binance', name: 'Binance API', key: '', secret: '', configured: true, date: '2026-04-28' },
    { id: 'telegram', name: 'Telegram Bot', key: '', secret: '', configured: false, date: '' },
    { id: 'openai', name: 'OpenAI API', key: '', secret: '', configured: false, date: '' },
  ])

  const updateKey = (id: string, field: 'key' | 'secret', value: string) => {
    setKeys(prev => prev.map(k => k.id === id ? { ...k, [field]: value } : k))
  }

  return (
    <div className="space-y-6">
      <SectionHeader title="API 密钥管理" desc="所有 API 密钥均加密存储。建议使用环境变量或外部 Secret Vault 管理敏感信息。" />

      <div className="space-y-4">
        {keys.map(api => (
          <div key={api.id} className="p-5" style={{ background: 'rgba(255,255,255,0.02)', borderRadius: '2px', border: '1px solid rgba(255,255,255,0.06)' }}>
            <div className="flex items-center justify-between mb-4">
              <div className="min-w-0">
                <div className="text-[14px] font-medium">{api.name}</div>
                <div className="text-[12px] text-text-muted">
                  {api.date ? `最后更新: ${api.date}` : '未配置'}
                </div>
              </div>
              <span className={cn('badge shrink-0 ml-3', api.configured ? 'bg-success-dim text-success' : 'bg-surface-active text-text-muted')}>
                {api.configured ? '已配置' : '未配置'}
              </span>
            </div>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
              <PasswordField
                label="API Key"
                placeholder={`输入 ${api.name} Key`}
                value={api.key}
                onChange={v => updateKey(api.id, 'key', v)}
              />
              <PasswordField
                label="API Secret"
                placeholder={`输入 ${api.name} Secret`}
                value={api.secret}
                onChange={v => updateKey(api.id, 'secret', v)}
              />
            </div>
          </div>
        ))}
      </div>

      <SaveButton onClick={() => toast('success', 'API密钥配置已保存')} />
    </div>
  )
}

// ==================== Shared Components ====================

function SectionHeader({ title, desc }: { title: string; desc?: string }) {
  return (
    <div>
      <span className="terminal-label block">{title}</span>
      {desc && <p className="text-[12px] font-mono mt-1" style={{ color: '#555' }}>{desc}</p>}
    </div>
  )
}

function SaveButton({ onClick }: { onClick?: () => void }) {
  return (
    <div className="flex justify-end pt-2 border-b-divider">
      <button onClick={onClick} className="btn-primary flex items-center gap-1.5 px-5 py-2.5 text-[12px]">
        <Save className="w-3.5 h-3.5" /> 保存设置
      </button>
    </div>
  )
}
