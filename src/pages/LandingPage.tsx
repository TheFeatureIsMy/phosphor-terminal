import { useRef, Suspense, lazy } from 'react'
import { useNavigate } from 'react-router-dom'
import { motion, useInView } from 'framer-motion'
import {
  Brain, Cpu, Eye, Bug, ArrowRight,
  Workflow, FileSearch, TrendingUp, BarChart3, Shield, Zap
} from 'lucide-react'
import BlurText from '@/components/ui/blur-text'
import { PulseDeskLogo } from '@/components/brand/PulseDeskLogo'

const Particles = lazy(() => import('@/components/ui/particles'))

function useReducedMotion() {
  if (typeof window === 'undefined') return false
  return window.matchMedia('(prefers-reduced-motion: reduce)').matches
}

function FadeInSection({ children, className = '', id, delay = 0 }: { children: React.ReactNode; className?: string; id?: string; delay?: number }) {
  const ref = useRef(null)
  const isInView = useInView(ref, { once: true, margin: '-60px' })
  const reducedMotion = useReducedMotion()

  return (
    <motion.section
      ref={ref}
      id={id}
      initial={reducedMotion ? false : { opacity: 0, y: 20 }}
      animate={reducedMotion ? { opacity: 1, y: 0 } : (isInView ? { opacity: 1, y: 0 } : { opacity: 0, y: 20 })}
      transition={{ duration: 0.45, delay, ease: [0.25, 0.46, 0.45, 0.94] }}
      className={className}
    >
      {children}
    </motion.section>
  )
}

const PHOSPHOR = '#8cffb8'
const INFO = '#7db7ff'
const WARNING = '#e8b86d'
const DANGER = '#ff6b6b'

const features = [
  { icon: Workflow, title: '可视化策略画布', desc: '拖拽式节点编辑器，零代码构建交易逻辑。支持数据源、指标、逻辑门、执行器四种节点类型。', color: PHOSPHOR },
  { icon: FileSearch, title: 'RAG 策略实验室', desc: '上传 PDF 研报或交易书籍，AI 自动提取策略逻辑并生成可执行 Python 代码。', color: INFO },
  { icon: Eye, title: 'SHAP 深度归因', desc: '每笔亏损交易自动生成复盘报告，用自然语言解释亏损原因。', color: WARNING },
  { icon: Bug, title: '微观结构审计', desc: 'L3 订单簿分析，实时检测洗盘交易和幌骗行为，保护交易安全。', color: DANGER },
  { icon: Brain, title: 'FinBERT 情绪感知', desc: '社交媒体与新闻情绪评分，识别市场操纵模式，感知市场脉搏。', color: WARNING },
  { icon: Cpu, title: 'FreqAI 动态进化', desc: '增量学习引擎，策略自适应市场 regime 切换，延长策略寿命。', color: INFO },
]

const popularStrategies = [
  { name: 'BTC 趋势猎手', type: '均线交叉', market: 'BTC/USDT', sharpe: 2.34, pnl: '+42.8%', winRate: 68, color: PHOSPHOR, icon: TrendingUp },
  { name: 'ETH 均值回归', type: '均值回归', market: 'ETH/USDT', sharpe: 1.89, pnl: '+28.5%', winRate: 72, color: INFO, icon: BarChart3 },
  { name: 'SOL 突破引擎', type: '突破策略', market: 'SOL/USDT', sharpe: 2.12, pnl: '+35.2%', winRate: 64, color: WARNING, icon: Zap },
  { name: 'BNB 网格大师', type: '网格交易', market: 'BNB/USDT', sharpe: 1.67, pnl: '+19.4%', winRate: 78, color: PHOSPHOR, icon: Shield },
  { name: 'XRP 动量捕手', type: '均线交叉', market: 'XRP/USDT', sharpe: 1.95, pnl: '+31.7%', winRate: 66, color: INFO, icon: TrendingUp },
  { name: 'AVAX 波段王', type: '均值回归', market: 'AVAX/USDT', sharpe: 2.01, pnl: '+38.1%', winRate: 70, color: WARNING, icon: BarChart3 },
]

export function LandingPage() {
  const navigate = useNavigate()
  const reducedMotion = useReducedMotion()

  const stats = [
    { value: '6', suffix: '+', label: '核心 AI 模块' },
    { value: '4', suffix: '', label: '系统架构层' },
    { value: '10', suffix: '+', label: '支持策略类型' },
    { value: '99.9', suffix: '%', label: '系统可用性' },
  ]

  return (
    <div className="min-h-dvh text-text overflow-x-hidden relative" style={{ background: '#070908' }}>
      <div className="terminal-backdrop" aria-hidden="true" />
      <div className="noise-overlay" aria-hidden="true" />
      <div className="terminal-scanline" aria-hidden="true" />

      {!reducedMotion && (
        <div className="fixed inset-0 pointer-events-none z-0 opacity-45" aria-hidden="true">
          <Suspense fallback={null}>
            <Particles
              particleCount={36}
              particleColors={[PHOSPHOR, INFO]}
              speed={0.025}
              alphaParticles
              particleBaseSize={42}
              moveParticlesOnHover={false}
            />
          </Suspense>
        </div>
      )}

      <a href="#features" className="skip-link">跳转到核心功能</a>

      <section className="relative min-h-[78vh] flex flex-col items-center justify-center px-6 md:px-10">
        <motion.div
          initial={reducedMotion ? false : { opacity: 0, y: 18 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.55, ease: [0.25, 0.46, 0.45, 0.94] }}
          className="w-full max-w-5xl mx-auto grid gap-8 lg:grid-cols-[1fr_380px] items-center"
        >
          <div>
            <div className="inline-flex items-center gap-2 px-3 py-1.5 mb-8 text-[11px] font-mono font-medium tracking-[0.08em] uppercase"
              style={{ color: PHOSPHOR, background: 'rgba(140,255,184,0.075)', border: '1px solid rgba(140,255,184,0.18)', borderRadius: 8 }}>
              <span className="w-1.5 h-1.5 rounded-full" style={{ background: PHOSPHOR, boxShadow: '0 0 8px rgba(140,255,184,0.42)' }} />
              AI Trading Workbench
            </div>

            <div className="mb-6 flex items-center gap-2.5">
              <PulseDeskLogo size={42} className="shrink-0" />
              <div>
                <div className="font-mono text-[14px] font-bold leading-tight tracking-[0.04em]" style={{ color: '#e7f0ea' }}>PulseDesk</div>
                <div className="text-[9px] leading-tight tracking-[0.08em] uppercase" style={{ color: '#5e6a63' }}>Professional Quant Console</div>
              </div>
            </div>

            <h1 className="text-[2.55rem] sm:text-5xl lg:text-6xl font-extrabold tracking-tight mb-6 leading-[1.04] break-words" style={{ fontFamily: 'Instrument Sans, sans-serif' }}>
              <BlurText text="PulseDesk" delay={90} animateBy="words" direction="bottom" className="block" style={{ color: '#f2fff6' }} />
              <BlurText text="AI 量化工作台" delay={130} animateBy="words" direction="bottom" className="glow-text" />
            </h1>

            <p className="text-[15px] mb-3 leading-relaxed max-w-xl font-mono" style={{ color: '#9aa8a0' }}>
              感知、决策、归因、进化统一在一个低干扰桌面终端里。
            </p>
            <p className="text-[13px] mb-10 max-w-lg font-mono" style={{ color: '#5e6a63' }}>
              为策略研究、回测、执行和复盘打造的专业 AI Trading Workbench。
            </p>

            <div className="flex flex-wrap gap-3">
              <button onClick={() => navigate('/login')} className="btn-primary px-6 sm:px-8 py-3 text-[13px] inline-flex items-center justify-center gap-2">
                打开控制台 <ArrowRight className="w-4 h-4" />
              </button>
              <button onClick={() => navigate('/register')} className="btn-ghost px-6 sm:px-8 py-3 text-[13px] inline-flex items-center justify-center gap-2">
                创建工作区 <ArrowRight className="w-4 h-4" />
              </button>
            </div>
          </div>

          <div className="card p-4 hidden lg:block">
            <div className="flex items-center gap-2 pb-3 mb-4" style={{ borderBottom: '1px solid rgba(189,255,215,0.08)' }}>
              <span className="w-2.5 h-2.5 rounded-full" style={{ background: '#ff6b6b' }} />
              <span className="w-2.5 h-2.5 rounded-full" style={{ background: '#e8b86d' }} />
              <span className="w-2.5 h-2.5 rounded-full" style={{ background: PHOSPHOR }} />
              <span className="ml-auto text-[10px] font-mono" style={{ color: '#5e6a63' }}>pulsedesk://mission-control</span>
            </div>
            <div className="space-y-3 font-mono text-[12px]">
              {[
                ['market.feed', 'online', PHOSPHOR],
                ['strategy.engine', 'ready', PHOSPHOR],
                ['risk.guard', 'armed', WARNING],
                ['attribution.shap', 'listening', INFO],
              ].map(([name, state, color]) => (
                <div key={name} className="flex items-center justify-between rounded-md px-3 py-2" style={{ background: 'rgba(189,255,215,0.035)', border: '1px solid rgba(189,255,215,0.06)' }}>
                  <span style={{ color: '#9aa8a0' }}>{name}</span>
                  <span style={{ color }}>{state}</span>
                </div>
              ))}
            </div>
          </div>
        </motion.div>
      </section>

      <FadeInSection className="py-14">
        <div style={{ maxWidth: '1024px', margin: '0 auto', padding: '0 32px' }}>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            {stats.map((stat, i) => (
              <motion.div
                key={stat.label}
                initial={reducedMotion ? false : { opacity: 0, y: 12 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                transition={{ duration: 0.3, delay: i * 0.05 }}
                className="card p-5 text-center"
              >
                <div className="text-3xl md:text-4xl font-extrabold font-mono mb-1" style={{ color: PHOSPHOR }}>
                  {stat.value}<span className="text-xl">{stat.suffix}</span>
                </div>
                <div className="text-[12px] font-mono" style={{ color: '#5e6a63' }}>{stat.label}</div>
              </motion.div>
            ))}
          </div>
        </div>
      </FadeInSection>

      <FadeInSection id="features" className="py-20 md:py-24">
        <div style={{ maxWidth: '1152px', margin: '0 auto', padding: '0 32px' }}>
          <div className="text-center mb-12">
            <span className="terminal-label block mb-3">Core Features</span>
            <h2 className="heading-xl mb-4">核心功能</h2>
            <p className="font-mono" style={{ color: '#5e6a63', maxWidth: '28rem', margin: '0 auto', fontSize: '13px' }}>从策略创建到执行归因，AI 贯穿全链路。</p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {features.map((f, i) => (
              <motion.div
                key={f.title}
                initial={reducedMotion ? false : { opacity: 0, y: 14 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true, margin: '-40px' }}
                transition={{ duration: 0.35, delay: i * 0.04, ease: [0.25, 0.46, 0.45, 0.94] }}
              >
                <div className="card p-6 h-full relative overflow-hidden">
                  <div className="w-9 h-9 flex items-center justify-center mb-4"
                    style={{ background: `${f.color}12`, border: `1px solid ${f.color}26`, borderRadius: 8 }}>
                    <f.icon className="w-4 h-4" style={{ color: f.color }} />
                  </div>
                  <h3 className="text-[14px] font-semibold font-mono mb-2" style={{ color: '#e7f0ea' }}>{f.title}</h3>
                  <p className="font-mono" style={{ fontSize: '12px', color: '#5e6a63', lineHeight: '1.7' }}>{f.desc}</p>
                </div>
              </motion.div>
            ))}
          </div>
        </div>
      </FadeInSection>

      <FadeInSection className="py-20 md:py-24 overflow-hidden">
        <div style={{ maxWidth: '1152px', margin: '0 auto', padding: '0 32px' }}>
          <div className="text-center mb-12">
            <span className="terminal-label block mb-3">Strategy Deck</span>
            <h2 className="heading-xl mb-4">热门策略</h2>
            <p className="font-mono" style={{ color: '#5e6a63', maxWidth: '28rem', margin: '0 auto', fontSize: '13px' }}>桌面工作台内置策略库、回测与执行状态。</p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {popularStrategies.map((s) => (
              <StrategyCard key={s.name} strategy={s} />
            ))}
          </div>
        </div>
      </FadeInSection>

      <FadeInSection className="px-6 md:px-10 py-20 md:py-24 text-center">
        <div className="w-full max-w-3xl mx-auto flex flex-col items-center">
          <h2 className="heading-lg mb-4 text-center w-full">进入 PulseDesk</h2>
          <p className="font-mono text-center w-full max-w-md mx-auto mb-8" style={{ color: '#5e6a63', fontSize: '13px' }}>
            打开控制台，开始管理策略、回测、订单和归因分析。
          </p>
          <button onClick={() => navigate('/login')} className="btn-primary px-8 py-3 text-[13px] inline-flex items-center justify-center gap-2">
            登录控制台 <ArrowRight className="w-4 h-4" />
          </button>
        </div>
      </FadeInSection>

      <footer className="py-10 px-6 md:px-10 text-center" style={{ borderTop: '1px solid rgba(189,255,215,0.08)' }}>
        <div className="flex flex-wrap items-center justify-center gap-2 mb-4">
          {['React', 'Tauri', 'Freqtrade', 'SHAP', 'FinBERT', 'LangChain'].map(tech => (
            <span key={tech} className="badge font-mono" style={{ background: 'rgba(140,255,184,0.06)', color: 'rgba(140,255,184,0.7)', border: '1px solid rgba(140,255,184,0.12)' }}>
              {tech}
            </span>
          ))}
        </div>
        <p className="font-mono" style={{ fontSize: '11px', color: '#5e6a63' }}>&copy; {new Date().getFullYear()} PulseDesk &middot; AI Trading Workbench</p>
      </footer>
    </div>
  )
}

function StrategyCard({ strategy }: { strategy: typeof popularStrategies[0] }) {
  const Icon = strategy.icon
  return (
    <div className="card p-4">
      <div className="flex items-center justify-between mb-3">
        <div className="flex items-center gap-2">
          <div className="w-7 h-7 flex items-center justify-center" style={{ background: `${strategy.color}12`, border: `1px solid ${strategy.color}26`, borderRadius: 8 }}>
            <Icon className="w-3.5 h-3.5" style={{ color: strategy.color }} />
          </div>
          <div>
            <div className="text-[13px] font-semibold font-mono" style={{ color: '#e7f0ea' }}>{strategy.name}</div>
            <div className="text-[10px] font-mono" style={{ color: '#5e6a63' }}>{strategy.type} · {strategy.market}</div>
          </div>
        </div>
        <div className="text-right">
          <div className="text-[14px] font-bold font-tabular" style={{ color: PHOSPHOR }}>{strategy.pnl}</div>
          <div className="text-[10px] font-mono" style={{ color: '#5e6a63' }}>总收益</div>
        </div>
      </div>
      <div className="flex items-center gap-4">
        <div className="flex-1">
          <div className="text-[9px] font-mono uppercase tracking-wider mb-0.5" style={{ color: '#5e6a63' }}>夏普</div>
          <div className="text-[13px] font-bold font-tabular">{strategy.sharpe}</div>
        </div>
        <div className="flex-1">
          <div className="text-[9px] font-mono uppercase tracking-wider mb-0.5" style={{ color: '#5e6a63' }}>胜率</div>
          <div className="text-[13px] font-bold font-tabular">{strategy.winRate}%</div>
        </div>
        <div className="flex-1 h-1 overflow-hidden" style={{ background: 'rgba(189,255,215,0.08)', borderRadius: 2 }}>
          <div className="h-full" style={{ width: `${strategy.winRate}%`, background: strategy.color, borderRadius: 2 }} />
        </div>
      </div>
    </div>
  )
}
