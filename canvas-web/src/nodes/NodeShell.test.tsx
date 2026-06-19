import { describe, it, expect } from 'vitest'
import { render, screen } from '@testing-library/react'
import { ReactFlowProvider, Position } from '@xyflow/react'
import { NodeShell } from './NodeShell'

function renderShell(props: Partial<Parameters<typeof NodeShell>[0]> = {}) {
  return render(
    <ReactFlowProvider>
      <NodeShell
        type="signalInput"
        title="信号输入"
        dotColor="#00C2FF"
        rows={[
          { k: '周期', v: '1h' },
          { k: '标的', v: 'BTC/USDT' },
        ]}
        ports={[{ type: 'source', position: Position.Right, id: 'out' }]}
        {...props}
      />
    </ReactFlowProvider>
  )
}

describe('NodeShell', () => {
  it('renders title and rows', () => {
    renderShell()
    expect(screen.getByText('信号输入')).toBeTruthy()
    expect(screen.getByText('周期')).toBeTruthy()
    expect(screen.getByText('1h')).toBeTruthy()
    expect(screen.getByText('标的')).toBeTruthy()
    expect(screen.getByText('BTC/USDT')).toBeTruthy()
  })

  it('does not render emoji icons (anti-AI rule)', () => {
    const { container } = renderShell()
    const text = container.textContent ?? ''
    // Common emoji from old node icons must be absent
    expect(text).not.toMatch(/[📡📊🔍📐🛡🚀🔥🔀]/u)
  })

  it('applies is-selected class when selected', () => {
    const { container } = renderShell({ selected: true })
    const node = container.querySelector('.pa-node')
    expect(node?.classList.contains('is-selected')).toBe(true)
  })

  it('applies is-invalid class and renders error message when invalid', () => {
    const { container } = renderShell({ invalid: true, errMessage: 'E_TIMEFRAME_REQUIRED' })
    const node = container.querySelector('.pa-node')
    expect(node?.classList.contains('is-invalid')).toBe(true)
    expect(screen.getByRole('alert').textContent).toBe('E_TIMEFRAME_REQUIRED')
  })

  it('renders ports as React Flow Handle elements', () => {
    const { container } = renderShell({
      ports: [
        { type: 'target', position: Position.Left, id: 'in' },
        { type: 'source', position: Position.Right, id: 'out' },
      ],
    })
    const handles = container.querySelectorAll('.pa-handle')
    expect(handles.length).toBe(2)
  })

  it('shows the type slug as a small label', () => {
    renderShell({ type: 'positionSizing' })
    expect(screen.getByText('positionSizing')).toBeTruthy()
  })
})
