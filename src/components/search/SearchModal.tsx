import { useState, useEffect, useRef } from 'react'
import { useNavigate } from 'react-router-dom'
import { Search, X, GitBranch, ArrowRight } from 'lucide-react'

interface SearchResult {
  type: string
  id: number
  title: string
  subtitle: string
  url: string
}

interface Props {
  open: boolean
  onClose: () => void
}

const API_BASE = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000'

export function SearchModal({ open, onClose }: Props) {
  const [query, setQuery] = useState('')
  const [results, setResults] = useState<SearchResult[]>([])
  const [loading, setLoading] = useState(false)
  const inputRef = useRef<HTMLInputElement>(null)
  const navigate = useNavigate()

  useEffect(() => {
    if (open) {
      setQuery('')
      setResults([])
      setTimeout(() => inputRef.current?.focus(), 50)
    }
  }, [open])

  useEffect(() => {
    if (!query.trim()) {
      setResults([])
      return
    }
    const timer = setTimeout(async () => {
      setLoading(true)
      try {
        const res = await fetch(`${API_BASE}/search?q=${encodeURIComponent(query)}`)
        if (res.ok) {
          const data = await res.json()
          setResults(data.results || [])
        }
      } catch {
        setResults([])
      } finally {
        setLoading(false)
      }
    }, 300)
    return () => clearTimeout(timer)
  }, [query])

  useEffect(() => {
    const handleKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose()
      if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
        e.preventDefault()
        if (open) onClose()
      }
    }
    document.addEventListener('keydown', handleKey)
    return () => document.removeEventListener('keydown', handleKey)
  }, [open, onClose])

  if (!open) return null

  const handleSelect = (url: string) => {
    navigate(url)
    onClose()
  }

  return (
    <div className="fixed inset-0 z-[100] flex items-start justify-center pt-[15vh]">
      <div className="fixed inset-0 bg-black/60 backdrop-blur-sm" onClick={onClose} />
      <div
        className="relative w-full max-w-lg mx-4"
        style={{
          background: '#111111',
          border: '1px solid rgba(255,255,255,0.1)',
          borderRadius: '4px',
          boxShadow: '0 24px 64px rgba(0,0,0,0.8)',
        }}
      >
        <div className="flex items-center gap-3 px-4 py-3 border-b border-white/6">
          <Search className="w-4 h-4 shrink-0" style={{ color: '#555' }} />
          <input
            ref={inputRef}
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="搜索策略、交易、设置..."
            className="flex-1 bg-transparent text-[14px] font-mono outline-none"
            style={{ color: '#e0e0e0' }}
          />
          <button onClick={onClose} className="p-1 hover:bg-white/5 rounded">
            <X className="w-4 h-4" style={{ color: '#555' }} />
          </button>
        </div>

        <div className="max-h-80 overflow-y-auto py-2">
          {loading && (
            <div className="px-4 py-6 text-center text-[12px] font-mono" style={{ color: '#555' }}>
              搜索中...
            </div>
          )}

          {!loading && query && results.length === 0 && (
            <div className="px-4 py-6 text-center text-[12px] font-mono" style={{ color: '#555' }}>
              未找到结果
            </div>
          )}

          {!loading && results.map((r, i) => (
            <button
              key={`${r.type}-${r.id}`}
              onClick={() => handleSelect(r.url)}
              className="w-full flex items-center gap-3 px-4 py-2.5 text-left hover:bg-white/5 transition-colors"
            >
              <div className="w-7 h-7 flex items-center justify-center shrink-0"
                style={{ background: 'rgba(0,255,157,0.08)', borderRadius: '2px' }}>
                <GitBranch className="w-3.5 h-3.5" style={{ color: '#00ff9d' }} />
              </div>
              <div className="flex-1 min-w-0">
                <div className="text-[13px] font-mono text-text-primary truncate">{r.title}</div>
                <div className="text-[11px] font-mono text-text-muted truncate">{r.subtitle}</div>
              </div>
              <ArrowRight className="w-3.5 h-3.5 shrink-0" style={{ color: '#333' }} />
            </button>
          ))}

          {!query && (
            <div className="px-4 py-6 text-center text-[12px] font-mono" style={{ color: '#444' }}>
              输入关键词开始搜索
            </div>
          )}
        </div>

        <div className="flex items-center justify-between px-4 py-2 border-t border-white/6">
          <span className="text-[10px] font-mono" style={{ color: '#333' }}>
            <kbd className="px-1.5 py-0.5 rounded text-[10px]" style={{ background: 'rgba(255,255,255,0.06)', color: '#555' }}>↑↓</kbd> 导航
            <kbd className="px-1.5 py-0.5 rounded text-[10px] ml-2" style={{ background: 'rgba(255,255,255,0.06)', color: '#555' }}>↵</kbd> 选择
          </span>
          <span className="text-[10px] font-mono" style={{ color: '#333' }}>
            <kbd className="px-1.5 py-0.5 rounded text-[10px]" style={{ background: 'rgba(255,255,255,0.06)', color: '#555' }}>esc</kbd> 关闭
          </span>
        </div>
      </div>
    </div>
  )
}
