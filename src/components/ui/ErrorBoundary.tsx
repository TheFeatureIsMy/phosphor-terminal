import { Component, type ErrorInfo, type ReactNode } from 'react'
import { AlertTriangle, RotateCcw } from 'lucide-react'

interface Props {
  children: ReactNode
}

interface State {
  hasError: boolean
  error: Error | null
}

export class ErrorBoundary extends Component<Props, State> {
  constructor(props: Props) {
    super(props)
    this.state = { hasError: false, error: null }
  }

  static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error }
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    console.error('[ErrorBoundary]', error, info.componentStack)
  }

  handleReset = () => {
    this.setState({ hasError: false, error: null })
  }

  render() {
    if (this.state.hasError) {
      return (
        <div className="min-h-dvh flex items-center justify-center px-6" style={{ background: '#070908' }}>
          <div className="card p-8 max-w-md w-full text-center">
            <div className="w-12 h-12 flex items-center justify-center mx-auto mb-4"
              style={{ background: 'rgba(255,107,107,0.1)', border: '1px solid rgba(255,107,107,0.2)', borderRadius: '2px' }}>
              <AlertTriangle className="w-6 h-6" style={{ color: '#ff6b6b' }} />
            </div>
            <h2 className="text-lg font-bold mb-2" style={{ color: '#e7f0ea' }}>系统异常</h2>
            <p className="text-[13px] font-mono mb-1" style={{ color: '#9aa8a0' }}>
              页面渲染过程中发生错误
            </p>
            <p className="text-[11px] font-mono mb-6 p-3 text-left" style={{ color: '#ff6b6b', background: 'rgba(255,107,107,0.06)', borderRadius: '2px', border: '1px solid rgba(255,107,107,0.12)' }}>
              {this.state.error?.message || 'Unknown error'}
            </p>
            <button onClick={this.handleReset} className="btn-primary flex items-center gap-2 mx-auto px-5 py-2.5 text-[12px]">
              <RotateCcw className="w-3.5 h-3.5" /> 重新加载
            </button>
          </div>
        </div>
      )
    }

    return this.props.children
  }
}
