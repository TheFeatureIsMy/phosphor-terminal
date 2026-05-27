import { useState } from 'react'
import { Upload, Sparkles, Code, BookOpen, Send, Copy, Check, FileText, Trash2 } from 'lucide-react'
import { PageHeader } from '@/components/ui/PageHeader'
import { cn } from '@/lib/utils'

const API_BASE = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000'

interface KnowledgeDoc {
  id: string
  filename: string
  concepts: number
  chunks: number
  created_at: string
}

interface GeneratedStrategy {
  strategy: {
    name: string
    type: string
    market: string
    source: string
  }
  code: string
  context_used: Array<{ content: string; relevance: number }>
  risk_level: string
  explanation: string
}

export function StrategyLabPage() {
  const [prompt, setPrompt] = useState('')
  const [riskLevel, setRiskLevel] = useState('medium')
  const [generating, setGenerating] = useState(false)
  const [result, setResult] = useState<GeneratedStrategy | null>(null)
  const [documents, setDocuments] = useState<KnowledgeDoc[]>([])
  const [uploading, setUploading] = useState(false)
  const [copied, setCopied] = useState(false)
  const [activeTab, setActiveTab] = useState<'generate' | 'knowledge'>('generate')

  const handleGenerate = async () => {
    if (!prompt.trim()) return
    setGenerating(true)
    try {
      const res = await fetch(`${API_BASE}/rag/generate`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ prompt, risk_level: riskLevel }),
      })
      if (res.ok) {
        const data = await res.json()
        setResult(data)
      }
    } catch {} finally {
      setGenerating(false)
    }
  }

  const handleUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return
    setUploading(true)
    try {
      const formData = new FormData()
      formData.append('file', file)
      const res = await fetch(`${API_BASE}/rag/upload`, { method: 'POST', body: formData })
      if (res.ok) {
        loadDocuments()
      }
    } catch {} finally {
      setUploading(false)
    }
  }

  const loadDocuments = async () => {
    try {
      const res = await fetch(`${API_BASE}/rag/knowledge`)
      if (res.ok) {
        const data = await res.json()
        setDocuments(data.documents || [])
      }
    } catch {}
  }

  const copyCode = () => {
    if (result?.code) {
      navigator.clipboard.writeText(result.code)
      setCopied(true)
      setTimeout(() => setCopied(false), 2000)
    }
  }

  return (
    <div className="space-y-5">
      <PageHeader title="RAG 策略实验室" />

      {/* Tab Bar */}
      <div className="flex gap-0" style={{ borderBottom: '1px solid rgba(255,255,255,0.06)' }}>
        {[
          { id: 'generate' as const, label: '策略生成', icon: Sparkles },
          { id: 'knowledge' as const, label: '知识库', icon: BookOpen },
        ].map(({ id, label, icon: Icon }) => (
          <button
            key={id}
            onClick={() => { setActiveTab(id); if (id === 'knowledge') loadDocuments() }}
            className={cn(
              'flex items-center gap-2 px-4 py-2.5 text-[12px] font-mono font-medium transition-all duration-150 relative',
              activeTab === id ? 'text-[#e0e0e0]' : 'text-[#555] hover:text-[#888]'
            )}
          >
            {activeTab === id && (
              <div className="absolute bottom-0 left-0 right-0 h-[2px]" style={{ background: '#00ff9d' }} />
            )}
            <Icon className="w-3.5 h-3.5" style={{ color: activeTab === id ? '#00ff9d' : undefined }} /> {label}
          </button>
        ))}
      </div>

      {activeTab === 'generate' && (
        <div className="grid grid-cols-1 lg:grid-cols-[1fr_1.2fr] gap-5">
          {/* Left: Input */}
          <div className="space-y-4">
            <div className="card p-5 space-y-4">
              <span className="terminal-label">描述你想要的策略</span>
              <textarea
                value={prompt}
                onChange={(e) => setPrompt(e.target.value)}
                placeholder="例如: 创建一个基于布林带和RSI的均值回归策略，当价格触及下轨且RSI低于30时买入..."
                className="w-full h-32 px-4 py-3 text-[13px] font-mono resize-none"
                style={{ background: 'rgba(255,255,255,0.02)', border: '1px solid rgba(255,255,255,0.06)' }}
              />

              <div className="flex items-center gap-3">
                <div className="flex-1">
                  <label className="text-[11px] font-mono text-text-muted block mb-1.5">风险等级</label>
                  <select
                    value={riskLevel}
                    onChange={(e) => setRiskLevel(e.target.value)}
                    className="w-full px-3 py-2 text-[12px] font-mono"
                    style={{ background: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.08)' }}
                  >
                    <option value="low">低风险</option>
                    <option value="medium">中等风险</option>
                    <option value="high">高风险</option>
                  </select>
                </div>
              </div>

              <button
                onClick={handleGenerate}
                disabled={!prompt.trim() || generating}
                className="btn-primary w-full py-2.5 text-[13px] flex items-center justify-center gap-2 disabled:opacity-40"
              >
                {generating ? (
                  <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                ) : (
                  <>
                    <Sparkles className="w-4 h-4" /> 生成策略
                  </>
                )}
              </button>
            </div>

            {/* Context Used */}
            {result?.context_used && result.context_used.length > 0 && (
              <div className="card p-5 space-y-3">
                <span className="terminal-label">参考知识</span>
                {result.context_used.map((ctx, i) => (
                  <div key={i} className="p-3 text-[12px] font-mono" style={{ background: 'rgba(255,255,255,0.02)', border: '1px solid rgba(255,255,255,0.04)' }}>
                    <div className="text-text-muted line-clamp-2">{ctx.content}</div>
                    <div className="text-[10px] mt-1" style={{ color: '#00ff9d' }}>相关度: {(ctx.relevance * 100).toFixed(0)}%</div>
                  </div>
                ))}
              </div>
            )}
          </div>

          {/* Right: Output */}
          <div className="space-y-4">
            {result ? (
              <>
                <div className="card p-5 space-y-3">
                  <div className="flex items-center justify-between">
                    <span className="terminal-label">{result.strategy.name}</span>
                    <span className="badge bg-success-dim text-success">{result.strategy.type}</span>
                  </div>
                  <p className="text-[12px] font-mono text-text-muted">{result.explanation}</p>
                </div>

                <div className="card p-5">
                  <div className="flex items-center justify-between mb-3">
                    <span className="terminal-label">生成的代码</span>
                    <button
                      onClick={copyCode}
                      className="flex items-center gap-1.5 px-3 py-1.5 text-[11px] font-mono transition-colors"
                      style={{ color: copied ? '#00ff9d' : '#555', background: 'rgba(255,255,255,0.04)', borderRadius: '2px' }}
                    >
                      {copied ? <Check className="w-3 h-3" /> : <Copy className="w-3 h-3" />}
                      {copied ? '已复制' : '复制'}
                    </button>
                  </div>
                  <pre className="p-4 overflow-x-auto text-[12px] font-mono leading-relaxed" style={{ background: 'rgba(0,0,0,0.3)', borderRadius: '2px' }}>
                    <code>{result.code}</code>
                  </pre>
                </div>
              </>
            ) : (
              <div className="card p-12 flex flex-col items-center justify-center text-center">
                <div className="w-12 h-12 flex items-center justify-center mb-4" style={{ background: 'rgba(0,255,157,0.06)', borderRadius: '4px' }}>
                  <Code className="w-6 h-6" style={{ color: '#00ff9d40' }} />
                </div>
                <p className="text-[13px] font-mono text-text-muted">描述你想要的策略，AI 将为你生成代码</p>
                <p className="text-[11px] font-mono mt-1" style={{ color: '#444' }}>支持中文和英文描述</p>
              </div>
            )}
          </div>
        </div>
      )}

      {activeTab === 'knowledge' && (
        <div className="space-y-4">
          {/* Upload */}
          <div className="card p-5">
            <div className="flex items-center justify-between">
              <span className="terminal-label">上传文档</span>
              <label className="btn-primary px-4 py-2 text-[12px] flex items-center gap-2 cursor-pointer">
                <Upload className="w-3.5 h-3.5" />
                {uploading ? '上传中...' : '选择文件'}
                <input type="file" accept=".txt,.pdf,.md" onChange={handleUpload} className="hidden" disabled={uploading} />
              </label>
            </div>
            <p className="text-[11px] font-mono text-text-muted mt-2">支持 TXT、PDF、Markdown 格式的交易策略文档</p>
          </div>

          {/* Document List */}
          <div className="card p-5">
            <span className="terminal-label block mb-4">知识库文档 ({documents.length})</span>
            {documents.length === 0 ? (
              <div className="py-8 text-center text-[12px] font-mono text-text-muted">
                知识库为空，上传文档开始构建
              </div>
            ) : (
              <div className="space-y-2">
                {documents.map((doc) => (
                  <div key={doc.id} className="flex items-center justify-between p-3 surface-subtle">
                    <div className="flex items-center gap-3">
                      <FileText className="w-4 h-4" style={{ color: '#555' }} />
                      <div>
                        <div className="text-[13px] font-mono text-text-primary">{doc.filename}</div>
                        <div className="text-[10px] font-mono text-text-muted">
                          {doc.concepts} 概念 · {doc.chunks} 分块
                        </div>
                      </div>
                    </div>
                    <div className="text-[10px] font-mono text-text-muted">
                      {new Date(doc.created_at).toLocaleDateString('zh-CN')}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  )
}
