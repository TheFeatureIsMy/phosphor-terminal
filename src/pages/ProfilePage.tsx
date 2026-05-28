import { useState } from 'react'
import { Save, Camera, Shield, User, Key } from 'lucide-react'
import { PageHeader } from '@/components/ui/PageHeader'
import { Field, PasswordField, Toggle } from '@/components/ui/FormControls'
import { useToast } from '@/components/ui/Toast'
import { cn } from '@/lib/utils'

export function ProfilePage() {
  const [activeTab, setActiveTab] = useState<'profile' | 'security'>('profile')

  return (
    <div className="space-y-6">
      <PageHeader title="个人中心" />

      {/* Profile Header - horizontal layout */}
      <div className="card p-6">
        <div className="flex items-center gap-6">
          <div className="relative group shrink-0">
            <div className="w-20 h-20 flex items-center justify-center text-2xl font-bold font-mono"
              style={{ background: 'rgba(140,255,184,0.08)', border: '2px solid rgba(140,255,184,0.2)', color: '#8cffb8', borderRadius: '2px' }}>
              Q
            </div>
            <button className="absolute inset-0 bg-black/50 opacity-0 group-hover:opacity-100 flex items-center justify-center transition-opacity" style={{ borderRadius: '2px' }}>
              <Camera className="w-5 h-5 text-white" />
            </button>
          </div>
          <div className="flex-1 min-w-0">
            <div className="flex items-center gap-3 mb-1">
              <h2 className="text-xl font-bold">QuantTrader</h2>
              <span className="badge font-mono" style={{ background: 'rgba(140,255,184,0.06)', color: 'rgba(140,255,184,0.6)', border: '1px solid rgba(140,255,184,0.12)' }}>Admin</span>
              <span className="badge bg-success-dim text-success">在线</span>
            </div>
            <p className="text-[14px] text-text-muted">trader@pulsedesk.local</p>
            <p className="text-[13px] text-text-secondary mt-1">加密货币量化交易员，专注趋势跟踪和均值回归策略</p>
          </div>
          <div className="hidden lg:flex items-center gap-6 shrink-0">
            <div className="text-center">
              <div className="text-[10px] text-text-muted uppercase tracking-wider mb-0.5">策略数</div>
              <div className="text-xl font-bold font-tabular">8</div>
            </div>
            <div className="text-center">
              <div className="text-[10px] text-text-muted uppercase tracking-wider mb-0.5">交易数</div>
              <div className="text-xl font-bold font-tabular">342</div>
            </div>
            <div className="text-center">
              <div className="text-[10px] text-text-muted uppercase tracking-wider mb-0.5">胜率</div>
              <div className="text-xl font-bold font-tabular text-success">68%</div>
            </div>
          </div>
        </div>
      </div>

      {/* Tab Navigation */}
      <div className="flex gap-0" style={{ borderBottom: '1px solid rgba(255,255,255,0.06)' }}>
        {([
          { id: 'profile' as const, label: '个人信息', icon: User },
          { id: 'security' as const, label: '安全设置', icon: Shield },
        ]).map(({ id, label, icon: Icon }) => (
          <button
            key={id}
            onClick={() => setActiveTab(id)}
            className={cn(
              'flex items-center gap-2 px-5 py-2.5 text-[12px] font-mono font-medium transition-all duration-150 relative',
              activeTab === id ? 'text-[#e7f0ea]' : 'text-[#5e6a63] hover:text-[#9aa8a0]'
            )}
          >
            {activeTab === id && (
              <div className="absolute bottom-0 left-0 right-0 h-[2px]" style={{ background: '#8cffb8', boxShadow: '0 0 8px rgba(140,255,184,0.3)' }} />
            )}
            <Icon className="w-3.5 h-3.5" /> {label}
          </button>
        ))}
      </div>

      {/* Tab Content */}
      <div className="card p-6">
        {activeTab === 'profile' && <ProfileTab />}
        {activeTab === 'security' && <SecurityTab />}
      </div>
    </div>
  )
}

function ProfileTab() {
  const { toast } = useToast()
  return (
    <div className="space-y-6">
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
        {/* Left: Basic Info */}
        <div>
          <span className="terminal-label block mb-4">基本信息</span>
          <div className="space-y-4">
            <Field label="用户名" defaultValue="QuantTrader" />
            <Field label="邮箱" type="email" defaultValue="trader@pulsedesk.local" />
            <Field label="Telegram ID" placeholder="输入 Telegram ID" />
            <Field label="手机号" placeholder="输入手机号" />
          </div>
        </div>

        {/* Right: Bio + Preferences */}
        <div>
          <span className="terminal-label block mb-4">个人简介</span>
          <textarea
            rows={5}
            defaultValue="加密货币量化交易员，专注趋势跟踪和均值回归策略"
            className="w-full px-4 py-3 text-[14px] resize-none"
            style={{ borderRadius: '12px' }}
          />
          <div className="mt-4">
            <span className="terminal-label block mb-3">偏好设置</span>
            <div className="space-y-1">
              <Toggle label="深色模式" defaultChecked />
              <Toggle label="邮件通知" defaultChecked />
              <Toggle label="自动刷新数据" defaultChecked />
            </div>
          </div>
        </div>
      </div>

      <div className="flex justify-end pt-2 border-b-divider">
        <button onClick={() => toast('success', '个人信息已保存')} className="btn-primary flex items-center gap-1.5 px-5 py-2.5 text-[13px]">
          <Save className="w-4 h-4" /> 保存修改
        </button>
      </div>
    </div>
  )
}

function SecurityTab() {
  const { toast } = useToast()
  return (
    <div className="space-y-8">
      {/* Password */}
      <div>
        <span className="terminal-label block mb-4">修改密码</span>
        <div className="max-w-md space-y-3">
          <PasswordField label="当前密码" placeholder="输入当前密码" />
          <PasswordField label="新密码" placeholder="输入新密码" />
          <PasswordField label="确认新密码" placeholder="再次输入新密码" />
        </div>
        <div className="mt-4">
          <button onClick={() => toast('success', '密码已更新')} className="btn-primary flex items-center gap-1.5 px-5 py-2.5 text-[13px]">
            <Key className="w-4 h-4" /> 更新密码
          </button>
        </div>
      </div>

      <div className="divider" />

      {/* 2FA */}
      <div>
        <span className="terminal-label block mb-4">两步验证</span>
        <div className="flex items-center justify-between p-4" style={{ background: 'rgba(255,255,255,0.02)', borderRadius: '2px', border: '1px solid rgba(255,255,255,0.06)' }}>
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 flex items-center justify-center" style={{ background: 'rgba(140,255,184,0.06)', border: '1px solid rgba(140,255,184,0.12)', borderRadius: '2px' }}>
              <Shield className="w-5 h-5 text-success" />
            </div>
            <div>
              <div className="text-[14px] font-medium">Google Authenticator</div>
              <div className="text-[12px] text-text-muted">使用 TOTP 应用进行二次验证</div>
            </div>
          </div>
          <span className="badge bg-success-dim text-success">已启用</span>
        </div>
      </div>

      <div className="divider" />

      {/* Danger Zone */}
      <div>
        <span className="terminal-label block mb-4" style={{ color: '#ff6b6b' }}>危险操作</span>
        <div className="flex gap-3">
          <button className="btn-ghost px-5 py-2.5 text-[13px]">导出数据</button>
          <button className="px-5 py-2.5 text-[12px] font-mono bg-danger-dim text-danger transition-opacity hover:opacity-90" style={{ borderRadius: '2px' }}>注销账号</button>
        </div>
      </div>
    </div>
  )
}

