import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Activity, ArrowRight, ArrowLeft, Mail } from 'lucide-react'

export function ForgotPasswordPage() {
  const navigate = useNavigate()
  const [email, setEmail] = useState('')
  const [loading, setLoading] = useState(false)
  const [sent, setSent] = useState(false)

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (!email) return
    setLoading(true)
    setTimeout(() => {
      setLoading(false)
      setSent(true)
    }, 1000)
  }

  if (sent) {
    return (
      <div className="min-h-dvh flex items-center justify-center px-6" style={{ background: '#0a0a0a' }}>
        <div className="fixed inset-0 pointer-events-none" style={{
          background: 'radial-gradient(ellipse 60% 50% at 30% 20%, rgba(0,255,157,0.04) 0%, transparent 50%)',
        }} />
        <div className="w-full max-w-sm relative z-10 text-center">
          <div className="w-14 h-14 flex items-center justify-center mx-auto mb-6"
            style={{ background: 'rgba(0,255,157,0.08)', borderRadius: '2px', border: '1px solid rgba(0,255,157,0.2)' }}>
            <Mail className="w-7 h-7" style={{ color: '#00ff9d' }} />
          </div>
          <h1 className="text-xl font-bold font-mono mb-3" style={{ color: '#e0e0e0' }}>邮件已发送</h1>
          <p className="text-[13px] font-mono mb-2" style={{ color: '#555' }}>
            重置密码链接已发送至
          </p>
          <p className="text-[13px] font-mono font-medium mb-8" style={{ color: '#888' }}>{email}</p>
          <p className="text-[12px] font-mono mb-8" style={{ color: '#444' }}>
            没有收到？请检查垃圾邮件文件夹，或
            <button onClick={() => setSent(false)} className="text-primary hover:text-primary-hover transition-colors ml-1">重新发送</button>
          </p>
          <button onClick={() => navigate('/login')} className="btn-primary px-8 py-3 text-[14px] flex items-center gap-2 mx-auto">
            返回登录 <ArrowRight className="w-4 h-4" />
          </button>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-dvh flex items-center justify-center px-6" style={{ background: '#0a0a0a' }}>
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
          <h1 className="text-xl font-bold tracking-wider font-mono" style={{ color: '#e0e0e0' }}>忘记密码</h1>
          <p className="text-[12px] mt-2 font-mono" style={{ color: '#555' }}>输入注册邮箱，我们将发送重置链接</p>
        </div>

        <form onSubmit={handleSubmit} className="card p-6 space-y-5">
          <div>
            <label className="text-[11px] font-mono font-medium block mb-2" style={{ color: '#888' }}>注册邮箱</label>
            <input
              type="email"
              value={email}
              onChange={e => setEmail(e.target.value)}
              placeholder="trader@cyberquant.io"
              className="w-full px-4 py-3 text-[14px]"
              required
            />
          </div>

          <button
            type="submit"
            disabled={!email || loading}
            className="btn-primary w-full py-3 text-[14px] flex items-center justify-center gap-2 disabled:opacity-40"
          >
            {loading ? (
              <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
            ) : (
              <>发送重置链接 <ArrowRight className="w-4 h-4" /></>
            )}
          </button>
        </form>

        <button
          onClick={() => navigate('/login')}
          className="flex items-center gap-2 mx-auto mt-6 text-[12px] font-mono text-text-muted hover:text-text-secondary transition-colors cursor-pointer"
        >
          <ArrowLeft className="w-3.5 h-3.5" /> 返回登录
        </button>
      </div>
    </div>
  )
}
