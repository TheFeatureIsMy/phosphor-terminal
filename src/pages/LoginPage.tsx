import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Eye, EyeOff, ArrowRight } from 'lucide-react'
import { login, getMe } from '@/api/auth'
import { useAuthStore } from '@/stores/auth-store'
import { PulseDeskLogo } from '@/components/brand/PulseDeskLogo'

export function LoginPage() {
  const navigate = useNavigate()
  const { setTokens, setUser } = useAuthStore()
  const [username, setUsername] = useState('')
  const [password, setPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')
    setLoading(true)
    try {
      const tokens = await login(username, password)
      setTokens(tokens.access_token, tokens.refresh_token)
      const user = await getMe(tokens.access_token)
      setUser(user)
      navigate('/dashboard')
    } catch (err) {
      setError(err instanceof Error ? err.message : '登录失败')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-dvh flex items-center justify-center px-6" style={{ background: '#070908' }}>
      <div className="terminal-backdrop" aria-hidden="true" />
      <div className="noise-overlay" aria-hidden="true" />

      <div className="w-full max-w-sm relative z-10 px-1 sm:px-0">
        <div className="text-center mb-10">
          <PulseDeskLogo size={42} className="mx-auto mb-4" />
          <h1 className="text-xl font-bold tracking-wider font-mono" style={{ color: '#e7f0ea' }}>PulseDesk</h1>
          <p className="text-[12px] mt-2 font-mono" style={{ color: '#5e6a63' }}>登录到 AI Trading Workbench</p>
        </div>

        <form onSubmit={handleLogin} className="card p-5 sm:p-6 space-y-5">
          {error && (
            <div className="p-3 text-[13px] font-mono rounded" style={{ background: 'rgba(255,107,107,0.1)', color: '#ff6b6b', border: '1px solid rgba(255,107,107,0.22)' }}>
              {error}
            </div>
          )}

          <div>
            <label className="text-[11px] font-mono font-medium block mb-2" style={{ color: '#9aa8a0' }}>用户名</label>
            <input
              type="text"
              value={username}
              onChange={e => setUsername(e.target.value)}
              placeholder="输入用户名"
              className="w-full px-4 py-3 text-[14px]"
              required
            />
          </div>

          <div>
            <label className="text-[11px] font-mono font-medium block mb-2" style={{ color: '#9aa8a0' }}>密码</label>
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
              <span className="text-[12px] font-mono" style={{ color: '#9aa8a0' }}>记住登录</span>
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

        <p className="text-center text-[12px] font-mono mt-6" style={{ color: '#5e6a63' }}>
          还没有账号？ <button onClick={() => navigate('/register')} className="text-primary hover:text-primary-hover transition-colors">申请注册</button>
        </p>
      </div>
    </div>
  )
}
