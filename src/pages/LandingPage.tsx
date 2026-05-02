import { useRef, useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { motion, useInView } from 'framer-motion'
import {
  Brain, Cpu, Eye, Bug, ArrowRight,
  Workflow, FileSearch, TrendingUp, BarChart3, Shield, Zap
} from 'lucide-react'

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
      initial={reducedMotion ? false : { opacity: 0, y: 24 }}
      animate={reducedMotion ? { opacity: 1, y: 0 } : (isInView ? { opacity: 1, y: 0 } : { opacity: 0, y: 24 })}
      transition={{ duration: 0.5, delay, ease: [0.25, 0.46, 0.45, 0.94] }}
      className={className}
    >
      {children}
    </motion.section>
  )
}

/* ==================== Boot Sequence ==================== */
function BootSequence({ onComplete }: { onComplete: () => void }) {
  const [lines, setLines] = useState<string[]>([])
  const reducedMotion = useReducedMotion()

  const bootLines = [
    '> CYBERQUANT OS v2.0',
    '> Initializing neural core...',
    '> Loading strategy engine... OK',
    '> Connecting market feeds... OK',
    '> SHAP attribution module... READY',
    '> FinBERT sentiment engine... ONLINE',
    '> System ready. ▊',
  ]

  useEffect(() => {
    if (reducedMotion) { onComplete(); return }
    let i = 0
    const id = setInterval(() => {
      if (i < bootLines.length) {
        setLines(prev => [...prev, bootLines[i]])
        i++
      } else {
        clearInterval(id)
        setTimeout(onComplete, 400)
      }
    }, 180)
    return () => clearInterval(id)
  }, [])

  return (
    <motion.div
      className="fixed inset-0 z-[100] flex items-center justify-center"
      style={{ background: '#0a0a0a' }}
      exit={{ opacity: 0 }}
      transition={{ duration: 0.3 }}
    >
      <div className="w-full max-w-lg px-8">
        <div className="font-mono text-[13px] leading-relaxed" style={{ color: '#00ff9d' }}>
          {lines.map((line, i) => (
            <motion.div
              key={i}
              initial={{ opacity: 0, x: -8 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ duration: 0.15 }}
              style={{ color: i === lines.length - 1 ? '#00ff9d' : 'rgba(0,255,157,0.6)' }}
            >
              {line}
            </motion.div>
          ))}
        </div>
        <div className="mt-4 h-[2px] overflow-hidden" style={{ background: 'rgba(0,255,157,0.1)', borderRadius: '1px' }}>
          <motion.div
            className="h-full"
            style={{ background: '#00ff9d', borderRadius: '1px' }}
            initial={{ width: '0%' }}
            animate={{ width: '100%' }}
            transition={{ duration: 1.4, ease: 'linear' }}
          />
        </div>
      </div>
    </motion.div>
  )
}

/* ==================== Data ==================== */
const features = [
  {
    icon: Workflow,
    title: '可视化策略画布',
    desc: '拖拽式节点编辑器，零代码构建交易逻辑。支持数据源、指标、逻辑门、执行器四种节点类型。',
    color: '#00ff9d',
  },
  {
    icon: FileSearch,
    title: 'RAG策略实验室',
    desc: '上传PDF研报或交易书籍，AI自动提取策略逻辑并生成可执行Python代码。',
    color: '#00c2ff',
  },
  {
    icon: Eye,
    title: 'SHAP深度归因',
    desc: '每笔亏损交易自动生成"尸检报告"，用自然语言解释亏损原因。',
    color: '#ffb800',
  },
  {
    icon: Bug,
    title: '微观结构审计',
    desc: 'L3订单簿分析，实时检测洗盘交易和幌骗行为，保护交易安全。',
    color: '#ff3b3b',
  },
  {
    icon: Brain,
    title: 'FinBERT情绪感知',
    desc: '社交媒体与新闻情绪评分，识别市场操纵模式，感知市场脉搏。',
    color: '#ffb800',
  },
  {
    icon: Cpu,
    title: 'FreqAI动态进化',
    desc: '增量学习引擎，策略自适应市场regime切换，延长策略寿命。',
    color: '#00c2ff',
  },
]

const popularStrategies = [
  { name: 'BTC趋势猎手', type: '均线交叉', market: 'BTC/USDT', sharpe: 2.34, pnl: '+42.8%', winRate: 68, color: '#00ff9d', icon: TrendingUp },
  { name: 'ETH均值回归', type: '均值回归', market: 'ETH/USDT', sharpe: 1.89, pnl: '+28.5%', winRate: 72, color: '#00c2ff', icon: BarChart3 },
  { name: 'SOL突破引擎', type: '突破策略', market: 'SOL/USDT', sharpe: 2.12, pnl: '+35.2%', winRate: 64, color: '#ffb800', icon: Zap },
  { name: 'BNB网格大师', type: '网格交易', market: 'BNB/USDT', sharpe: 1.67, pnl: '+19.4%', winRate: 78, color: '#00ff9d', icon: Shield },
  { name: 'XRP动量捕手', type: '均线交叉', market: 'XRP/USDT', sharpe: 1.95, pnl: '+31.7%', winRate: 66, color: '#00c2ff', icon: TrendingUp },
  { name: 'AVAX波段王', type: '均值回归', market: 'AVAX/USDT', sharpe: 2.01, pnl: '+38.1%', winRate: 70, color: '#ffb800', icon: BarChart3 },
  { name: 'DOT趋势追踪', type: '突破策略', market: 'DOT/USDT', sharpe: 1.78, pnl: '+24.6%', winRate: 62, color: '#00ff9d', icon: Zap },
  { name: 'MATIC量化套利', type: '网格交易', market: 'MATIC/USDT', sharpe: 1.56, pnl: '+16.9%', winRate: 80, color: '#ff3b3b', icon: Shield },
]

const stats = [
  { value: '6', suffix: '+', label: '核心AI模块' },
  { value: '4', suffix: '层', label: '系统架构' },
  { value: '10', suffix: '+', label: '支持策略类型' },
  { value: '99.9', suffix: '%', label: '系统可用性' },
]

/* ==================== Main ==================== */
export function LandingPage() {
  const navigate = useNavigate()
  const reducedMotion = useReducedMotion()
  const [booted, setBooted] = useState(reducedMotion)

  return (
    <>
      {!booted && <BootSequence onComplete={() => setBooted(true)} />}

      <div className="min-h-dvh text-text-primary overflow-x-hidden relative" style={{ background: '#0a0a0a' }}>
        {/* Background */}
        <div className="fixed inset-0 pointer-events-none" style={{
          background: `
            radial-gradient(ellipse 70% 50% at 20% 10%, rgba(0,255,157,0.04) 0%, transparent 50%),
            radial-gradient(ellipse 50% 40% at 80% 60%, rgba(255,184,0,0.03) 0%, transparent 50%)
          `,
        }} />
        <div className="grid-overlay" aria-hidden="true" />
        <div className="noise-overlay" aria-hidden="true" />

        <a href="#features" className="skip-link">跳转到核心功能</a>

        {/* ==================== Hero ==================== */}
        <section className="relative min-h-[85vh] flex flex-col items-center justify-center text-center px-6 md:px-10">
          <motion.div
            initial={reducedMotion ? false : { opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6, delay: booted ? 0 : 1.6, ease: [0.25, 0.46, 0.45, 0.94] }}
            className="max-w-3xl mx-auto"
          >
            <div className="inline-flex items-center gap-2 px-3 py-1.5 mb-8 text-[11px] font-mono font-medium tracking-wider uppercase"
              style={{ color: '#00ff9d', background: 'rgba(0,255,157,0.05)', border: '1px solid rgba(0,255,157,0.12)', borderRadius: '2px' }}>
              <span className="w-1.5 h-1.5 rounded-full" style={{ background: '#00ff9d', boxShadow: '0 0 6px rgba(0,255,157,0.5)' }} />
              AI-Powered Quantitative Trading
            </div>

            <h1 className="text-4xl md:text-5xl lg:text-6xl font-extrabold tracking-tight mb-6 leading-[1.1]" style={{ fontFamily: 'Instrument Sans, sans-serif' }}>
              <span className="block" style={{ color: '#e0e0e0' }}>AI智脑</span>
              <span className="glow-text">量化交易系统</span>
            </h1>

            <p className="text-[15px] mb-3 leading-relaxed max-w-xl mx-auto font-mono" style={{ color: '#888' }}>
              感知-决策-归因-进化 — 闭环自优化的下一代量化平台
            </p>
            <p className="text-[13px] mb-12 max-w-lg mx-auto font-mono" style={{ color: '#555' }}>
              让每一笔交易都有迹可循，让每一个策略都持续进化
            </p>

            <button onClick={() => navigate('/login')} className="btn-primary px-10 py-4 text-[13px] flex items-center gap-2 mx-auto">
              登录控制台 <ArrowRight className="w-4 h-4" />
            </button>
          </motion.div>

          {/* Scroll indicator */}
          <motion.div
            className="absolute bottom-10 left-1/2 -translate-x-1/2"
            initial={reducedMotion ? false : { opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 1.5, duration: 0.5 }}
          >
            <motion.div
              animate={reducedMotion ? {} : { y: [0, 6, 0] }}
              transition={{ duration: 2, repeat: Infinity, ease: 'easeInOut' }}
              className="w-4 h-7 flex items-start justify-center pt-1.5"
              style={{ border: '1.5px solid rgba(255,255,255,0.1)', borderRadius: '2px' }}
            >
              <div className="w-0.5 h-1.5" style={{ background: 'rgba(0,255,157,0.4)', borderRadius: '1px' }} />
            </motion.div>
          </motion.div>
        </section>

        {/* ==================== Stats Bar ==================== */}
        <FadeInSection className="py-16">
          <div style={{ maxWidth: '1024px', margin: '0 auto', padding: '0 32px' }}>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-8">
              {stats.map((stat, i) => (
                <motion.div
                  key={stat.label}
                  initial={reducedMotion ? false : { opacity: 0, y: 12 }}
                  whileInView={{ opacity: 1, y: 0 }}
                  viewport={{ once: true }}
                  transition={{ duration: 0.3, delay: i * 0.06 }}
                  className="text-center"
                >
                  <div className="text-3xl md:text-4xl font-extrabold font-mono mb-1" style={{ color: '#00ff9d', textShadow: '0 0 20px rgba(0,255,157,0.2)' }}>
                    {stat.value}<span className="text-xl">{stat.suffix}</span>
                  </div>
                  <div className="text-[12px] font-mono" style={{ color: '#555' }}>{stat.label}</div>
                </motion.div>
              ))}
            </div>
          </div>
        </FadeInSection>

        {/* ==================== Features ==================== */}
        <FadeInSection id="features" className="py-20 md:py-28">
          <div style={{ maxWidth: '1152px', margin: '0 auto', padding: '0 32px' }}>
            <div className="text-center mb-14">
              <span className="terminal-label block mb-3">Core Features</span>
              <h2 className="heading-xl mb-4">核心功能</h2>
              <p className="font-mono" style={{ color: '#555', maxWidth: '28rem', margin: '0 auto', fontSize: '13px' }}>从策略创建到执行归因，AI贯穿全链路</p>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {features.map((f, i) => (
                <motion.div
                  key={f.title}
                  initial={reducedMotion ? false : { opacity: 0, y: 16 }}
                  whileInView={{ opacity: 1, y: 0 }}
                  viewport={{ once: true, margin: '-40px' }}
                  transition={{ duration: 0.4, delay: i * 0.05, ease: [0.25, 0.46, 0.45, 0.94] }}
                  className="group cursor-default"
                >
                  <div className="card p-6 h-full">
                    <div className="w-9 h-9 flex items-center justify-center mb-4"
                      style={{ background: `${f.color}0a`, border: `1px solid ${f.color}1a`, borderRadius: '2px' }}>
                      <f.icon className="w-4 h-4" style={{ color: f.color }} />
                    </div>
                    <h3 className="text-[14px] font-semibold font-mono mb-2" style={{ color: '#e0e0e0' }}>{f.title}</h3>
                    <p className="font-mono" style={{ fontSize: '12px', color: '#555', lineHeight: '1.7' }}>{f.desc}</p>
                  </div>
                </motion.div>
              ))}
            </div>
          </div>
        </FadeInSection>

        {/* ==================== Popular Strategies ==================== */}
        <FadeInSection className="py-20 md:py-28 overflow-hidden">
          <div style={{ maxWidth: '1152px', margin: '0 auto', padding: '0 32px' }}>
            <div className="text-center mb-12">
              <span className="terminal-label block mb-3">Popular Strategies</span>
              <h2 className="heading-xl mb-4">热门策略</h2>
              <p className="font-mono" style={{ color: '#555', maxWidth: '28rem', margin: '0 auto', fontSize: '13px' }}>社区最受欢迎的量化策略，持续跑赢市场</p>
            </div>
          </div>

          {/* Scrolling rows */}
          <div className="space-y-4" style={{ maskImage: 'linear-gradient(to right, transparent 0%, black 8%, black 92%, transparent 100%)', WebkitMaskImage: 'linear-gradient(to right, transparent 0%, black 8%, black 92%, transparent 100%)' }}>
            {/* Row 1: scroll left */}
            <div className="flex gap-4" style={{ animation: reducedMotion ? 'none' : 'scroll-left 35s linear infinite', width: 'max-content' }}>
              {[...popularStrategies, ...popularStrategies].map((s, i) => (
                <StrategyCard key={`r1-${i}`} strategy={s} />
              ))}
            </div>
            {/* Row 2: scroll right */}
            <div className="flex gap-4" style={{ animation: reducedMotion ? 'none' : 'scroll-right 40s linear infinite', width: 'max-content' }}>
              {[...popularStrategies.slice(4), ...popularStrategies.slice(0, 4), ...popularStrategies.slice(4), ...popularStrategies.slice(0, 4)].map((s, i) => (
                <StrategyCard key={`r2-${i}`} strategy={s} />
              ))}
            </div>
          </div>

          <style>{`
            @keyframes scroll-left {
              0% { transform: translateX(0); }
              100% { transform: translateX(-50%); }
            }
            @keyframes scroll-right {
              0% { transform: translateX(-50%); }
              100% { transform: translateX(0); }
            }
          `}</style>
        </FadeInSection>

        {/* ==================== CTA ==================== */}
        <FadeInSection className="px-6 md:px-10 py-24 md:py-32 max-w-3xl mx-auto text-center">
          <motion.div
            initial={reducedMotion ? false : { opacity: 0, scale: 0.98 }}
            whileInView={{ opacity: 1, scale: 1 }}
            viewport={{ once: true }}
            transition={{ duration: 0.4 }}
          >
            <h2 className="heading-lg mb-4">准备好开始了吗？</h2>
            <p className="font-mono mb-10" style={{ color: '#555', maxWidth: '28rem', margin: '0 auto 40px' }}>登录控制台，体验AI驱动的量化交易闭环</p>
            <button onClick={() => navigate('/login')} className="btn-primary px-10 py-4 text-[13px] flex items-center gap-2 mx-auto">
              登录控制台 <ArrowRight className="w-4 h-4" />
            </button>
          </motion.div>
        </FadeInSection>

        {/* ==================== Footer ==================== */}
        <footer className="py-10 px-6 md:px-10 text-center" style={{ borderTop: '1px solid rgba(255,255,255,0.04)' }}>
          <div className="flex flex-wrap items-center justify-center gap-2 mb-4">
            {['React', 'Freqtrade', 'SHAP', 'FinBERT', 'LangChain', 'CCXT'].map(tech => (
              <span key={tech} className="badge font-mono" style={{ background: 'rgba(0,255,157,0.04)', color: 'rgba(0,255,157,0.5)', border: '1px solid rgba(0,255,157,0.08)' }}>
                {tech}
              </span>
            ))}
          </div>
          <p className="font-mono" style={{ fontSize: '11px', color: '#444' }}>&copy; {new Date().getFullYear()} CyberQuant OS &middot; AI-Powered Quantitative Trading</p>
        </footer>
      </div>
    </>
  )
}

function StrategyCard({ strategy }: { strategy: typeof popularStrategies[0] }) {
  const Icon = strategy.icon
  return (
    <div className="card p-4 shrink-0" style={{ width: '280px' }}>
      <div className="flex items-center justify-between mb-3">
        <div className="flex items-center gap-2">
          <div className="w-7 h-7 flex items-center justify-center" style={{ background: `${strategy.color}10`, border: `1px solid ${strategy.color}20`, borderRadius: '2px' }}>
            <Icon className="w-3.5 h-3.5" style={{ color: strategy.color }} />
          </div>
          <div>
            <div className="text-[13px] font-semibold font-mono" style={{ color: '#e0e0e0' }}>{strategy.name}</div>
            <div className="text-[10px] font-mono" style={{ color: '#555' }}>{strategy.type} · {strategy.market}</div>
          </div>
        </div>
        <div className="text-right">
          <div className="text-[14px] font-bold font-tabular" style={{ color: '#00ff9d' }}>{strategy.pnl}</div>
          <div className="text-[10px] font-mono" style={{ color: '#555' }}>总收益</div>
        </div>
      </div>
      <div className="flex items-center gap-4">
        <div className="flex-1">
          <div className="text-[9px] font-mono uppercase tracking-wider mb-0.5" style={{ color: '#444' }}>夏普</div>
          <div className="text-[13px] font-bold font-tabular">{strategy.sharpe}</div>
        </div>
        <div className="flex-1">
          <div className="text-[9px] font-mono uppercase tracking-wider mb-0.5" style={{ color: '#444' }}>胜率</div>
          <div className="text-[13px] font-bold font-tabular">{strategy.winRate}%</div>
        </div>
        <div className="flex-1 h-1 overflow-hidden" style={{ background: 'rgba(255,255,255,0.04)', borderRadius: '1px' }}>
          <div className="h-full" style={{ width: `${strategy.winRate}%`, background: strategy.color, borderRadius: '1px' }} />
        </div>
      </div>
    </div>
  )
}
