import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { ArrowRight, ArrowLeft, Mail } from 'lucide-react'
import { PulseDeskLogo } from '@/components/brand/PulseDeskLogo'

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
      <div className="min-h-dvh flex items-center justify-center px-6" style={{ background: '#070908' }}>
        <div className="terminal-backdrop" aria-hidden="true" />
        <div className="noise-overlay" aria-hidden="true" />
        <div className="w-full max-w-sm relative z-10 text-center">
          <div className="w-14 h-14 flex items-center justify-center mx-auto mb-6"
            style={{ background: 'rgba(140,255,184,0.08)', borderRadius: 8, border: '1px solid rgba(140,255,184,0.2)' }}>
            <Mail className="w-7 h-7" style={{ color: '#8cffb8' }} />
          </div>
          <h1 className="text-xl font-bold font-mono mb-3" style={{ color: '#e7f0ea' }}>邮件已发送</h1>
          <p className="text-[13px] font-mono mb-2" style={{ color: '#5e6a63' }}>
            重置密码链接已发送至
          </p>
          <p className="text-[13px] font-mono font-medium mb-8" style={{ color: '#9aa8a0' }}>{email}</p>
          <p className="text-[12px] font-mono mb-8" style={{ color: '#5e6a63' }}>
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
    <div className="min-h-dvh flex items-center justify-center px-6" style={{ background: '#070908' }}>
      <div className="terminal-backdrop" aria-hidden="true" />
      <div className="noise-overlay" aria-hidden="true" />

      <div className="w-full max-w-sm relative z-10 px-1 sm:px-0">
        <div className="text-center mb-8">
          <PulseDeskLogo size={42} className="mx-auto mb-4" />
          <h1 className="text-xl font-bold tracking-wider font-mono" style={{ color: '#e7f0ea' }}>忘记密码</h1>
          <p className="text-[12px] mt-2 font-mono" style={{ color: '#5e6a63' }}>输入注册邮箱，我们将发送重置链接</p>
        </div>

        <form onSubmit={handleSubmit} className="card p-5 sm:p-6 space-y-5">
          <div>
            <label className="text-[11px] font-mono font-medium block mb-2" style={{ color: '#9aa8a0' }}>注册邮箱</label>
            <input
              type="email"
              value={email}
              onChange={e => setEmail(e.target.value)}
              placeholder="trader@pulsedesk.local"
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
