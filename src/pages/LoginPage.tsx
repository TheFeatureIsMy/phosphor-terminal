import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Activity, Eye, EyeOff, ArrowRight } from 'lucide-react'

export function LoginPage() {
  const navigate = useNavigate()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [loading, setLoading] = useState(false)

  const handleLogin = (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)
    // Mock login - just navigate to dashboard
    setTimeout(() => {
      navigate('/dashboard')
    }, 800)
  }

  return (
    <div className="min-h-dvh flex items-center justify-center px-6" style={{ background: '#0a0a0a' }}>
      {/* Background */}
      <div className="fixed inset-0 pointer-events-none" style={{
        background: `
          radial-gradient(ellipse 60% 50% at 30% 20%, rgba(0,255,157,0.04) 0%, transparent 50%),
          radial-gradient(ellipse 40% 40% at 70% 70%, rgba(255,184,0,0.03) 0%, transparent 50%)
        `,
      }} />
      <div className="grid-overlay" aria-hidden="true" />

      <div className="w-full max-w-sm relative z-10">
        {/* Logo */}
        <div className="text-center mb-10">
          <div className="w-10 h-10 flex items-center justify-center mx-auto mb-4"
            style={{
              background: 'rgba(0,255,157,0.08)',
              border: '1px solid rgba(0,255,157,0.15)',
              borderRadius: '2px',
            }}>
            <Activity className="w-5 h-5" style={{ color: '#00ff9d' }} />
          </div>
          <h1 className="text-xl font-bold tracking-wider font-mono" style={{ color: '#e0e0e0' }}>CYBERQUANT</h1>
          <p className="text-[12px] mt-2 font-mono" style={{ color: '#555' }}>登录到量化交易控制台</p>
        </div>

        {/* Form */}
        <form onSubmit={handleLogin} className="card p-6 space-y-5">
          <div>
            <label className="text-[11px] font-mono font-medium block mb-2" style={{ color: '#888' }}>邮箱</label>
            <input
              type="email"
              value={email}
              onChange={e => setEmail(e.target.value)}
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
                value={password}
                onChange={e => setPassword(e.target.value)}
                placeholder="输入密码"
                className="w-full px-4 py-3 pr-11 text-[14px]"
                required
              />
              <button
                type="button"
                onClick={() => setShowPassword(!showPassword)}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-text-muted hover:text-text-secondary transition-colors"
              >
                {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
              </button>
            </div>
          </div>

          <div className="flex items-center justify-between">
            <label className="flex items-center gap-2 cursor-pointer">
              <input type="checkbox" className="w-4 h-4" />
              <span className="text-[12px] font-mono" style={{ color: '#888' }}>记住登录</span>
            </label>
            <button type="button" onClick={() => navigate('/forgot-password')} className="text-[13px] text-primary hover:text-primary-hover transition-colors">
              忘记密码？
            </button>
          </div>

          <button
            type="submit"
            disabled={loading}
            className="btn-primary w-full py-3 text-[14px] flex items-center justify-center gap-2 disabled:opacity-60"
          >
            {loading ? (
              <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
            ) : (
              <>登录 <ArrowRight className="w-4 h-4" /></>
            )}
          </button>
        </form>

        <p className="text-center text-[12px] font-mono mt-6" style={{ color: '#444' }}>
          还没有账号？ <button onClick={() => navigate('/register')} className="text-primary hover:text-primary-hover transition-colors">申请注册</button>
        </p>
      </div>
    </div>
  )
}
