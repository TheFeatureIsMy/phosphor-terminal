import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Activity, Eye, EyeOff, ArrowRight, Check } from 'lucide-react'

export function RegisterPage() {
  const navigate = useNavigate()
  const [form, setForm] = useState({ username: '', email: '', password: '', confirm: '' })
  const [showPassword, setShowPassword] = useState(false)
  const [loading, setLoading] = useState(false)
  const [step, setStep] = useState<'form' | 'success'>('form')

  const update = (key: string, value: string) => setForm(prev => ({ ...prev, [key]: value }))

  const passwordRules = [
    { label: '至少8个字符', valid: form.password.length >= 8 },
    { label: '包含大写字母', valid: /[A-Z]/.test(form.password) },
    { label: '包含数字', valid: /\d/.test(form.password) },
  ]

  const canSubmit = form.username && form.email && form.password && form.confirm &&
    form.password === form.confirm && passwordRules.every(r => r.valid)

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (!canSubmit) return
    setLoading(true)
    setTimeout(() => {
      setLoading(false)
      setStep('success')
    }, 1000)
  }

  if (step === 'success') {
    return (
      <div className="min-h-dvh flex items-center justify-center px-6" style={{ background: '#0a0a0a' }}>
        <div className="fixed inset-0 pointer-events-none" style={{
          background: 'radial-gradient(ellipse 60% 50% at 30% 20%, rgba(0,255,157,0.04) 0%, transparent 50%)',
        }} />
        <div className="w-full max-w-sm relative z-10 text-center">
          <div className="w-14 h-14 flex items-center justify-center mx-auto mb-6"
            style={{ background: 'rgba(0,255,157,0.08)', borderRadius: '2px', border: '1px solid rgba(0,255,157,0.2)' }}>
            <Check className="w-7 h-7" style={{ color: '#00ff9d' }} />
          </div>
          <h1 className="text-xl font-bold font-mono mb-3" style={{ color: '#e0e0e0' }}>注册成功</h1>
          <p className="text-[13px] font-mono mb-8" style={{ color: '#555' }}>
            账号 <span style={{ color: '#888' }}>{form.email}</span> 已创建成功
          </p>
          <button onClick={() => navigate('/login')} className="btn-primary px-8 py-3 text-[14px] flex items-center gap-2 mx-auto">
            去登录 <ArrowRight className="w-4 h-4" />
          </button>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-dvh flex items-center justify-center px-6 py-12" style={{ background: '#0a0a0a' }}>
      <div className="fixed inset-0 pointer-events-none" style={{
        background: `
          radial-gradient(ellipse 60% 50% at 30% 20%, rgba(0,255,157,0.04) 0%, transparent 50%),
          radial-gradient(ellipse 40% 40% at 70% 70%, rgba(255,184,0,0.03) 0%, transparent 50%)
        `,
      }} />
      <div className="grid-overlay" aria-hidden="true" />

      <div className="w-full max-w-sm relative z-10">
        {/* Logo */}
        <div className="text-center mb-8">
          <div className="w-10 h-10 flex items-center justify-center mx-auto mb-4"
            style={{ background: 'rgba(0,255,157,0.08)', border: '1px solid rgba(0,255,157,0.15)', borderRadius: '2px' }}>
            <Activity className="w-5 h-5" style={{ color: '#00ff9d' }} />
          </div>
          <h1 className="text-xl font-bold tracking-wider font-mono" style={{ color: '#e0e0e0' }}>创建账号</h1>
          <p className="text-[12px] mt-2 font-mono" style={{ color: '#555' }}>注册 CyberQuant 量化交易账号</p>
        </div>

        <form onSubmit={handleSubmit} className="card p-6 space-y-4">
          <div>
            <label className="text-[11px] font-mono font-medium block mb-2" style={{ color: '#888' }}>用户名</label>
            <input
              type="text"
              value={form.username}
              onChange={e => update('username', e.target.value)}
              placeholder="输入用户名"
              className="w-full px-4 py-3 text-[14px]"
              required
            />
          </div>

          <div>
            <label className="text-[11px] font-mono font-medium block mb-2" style={{ color: '#888' }}>邮箱</label>
            <input
              type="email"
              value={form.email}
              onChange={e => update('email', e.target.value)}
              placeholder="trader@cyberquant.io"
              className="w-full px-4 py-3 text-[14px]"
              required
            />
          </div>

          <div>
            <label className="text-[11px] font-mono font-medium block mb-2" style={{ color: '#888' }}>密码</label>
            <div className="relative">
              <input
                type={showPassword ? 'text' : 'password'}
                value={form.password}
                onChange={e => update('password', e.target.value)}
                placeholder="设置登录密码"
                className="w-full px-4 py-3 pr-11 text-[14px]"
                required
              />
              <button type="button" onClick={() => setShowPassword(!showPassword)}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-text-muted hover:text-text-secondary transition-colors">
                {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
              </button>
            </div>
            {/* Password rules */}
            {form.password && (
              <div className="mt-2 space-y-1">
                {passwordRules.map(rule => (
                  <div key={rule.label} className="flex items-center gap-2">
                    <div className="w-3.5 h-3.5 flex items-center justify-center rounded-full"
                      style={{ background: rule.valid ? 'rgba(34,197,94,0.15)' : 'rgba(255,255,255,0.04)' }}>
                      {rule.valid && <Check className="w-2.5 h-2.5 text-success" />}
                    </div>
                    <span className="text-[12px]" style={{ color: rule.valid ? '#22c55e' : '#52525b' }}>{rule.label}</span>
                  </div>
                ))}
              </div>
            )}
          </div>

          <div>
            <label className="text-[11px] font-mono font-medium block mb-2" style={{ color: '#888' }}>确认密码</label>
            <input
              type="password"
              value={form.confirm}
              onChange={e => update('confirm', e.target.value)}
              placeholder="再次输入密码"
              className="w-full px-4 py-3 text-[14px]"
              required
            />
            {form.confirm && form.password !== form.confirm && (
              <p className="text-[12px] text-danger mt-1.5">两次密码不一致</p>
            )}
          </div>

          <button
            type="submit"
            disabled={!canSubmit || loading}
            className="btn-primary w-full py-3 text-[14px] flex items-center justify-center gap-2 disabled:opacity-40"
          >
            {loading ? (
              <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
            ) : (
              <>注册 <ArrowRight className="w-4 h-4" /></>
            )}
          </button>
        </form>

        <p className="text-center text-[12px] font-mono mt-6" style={{ color: '#444' }}>
          已有账号？ <button onClick={() => navigate('/login')} className="text-primary hover:text-primary-hover transition-colors">去登录</button>
        </p>
      </div>
    </div>
  )
}
