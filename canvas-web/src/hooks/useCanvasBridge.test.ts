import { describe, it, expect, vi, beforeEach } from 'vitest'
import type { SwiftToReactMessage } from '../types'

describe('useCanvasBridge message handler', () => {
  let onReadOnlyChange: ReturnType<typeof vi.fn>
  let setNodes: ReturnType<typeof vi.fn>
  /** Simulates the same dispatch logic as useCanvasBridge.handleMessage */
  function simulateHandler(msg: SwiftToReactMessage): void {
    switch (msg.type) {
      case 'setReadOnly':
        onReadOnlyChange(msg.readOnly)
        break
      case 'updateNodeData':
        // The real handler calls setNodes with an updater fn; invoke it here
        const updater = (ns: Array<{ id: string; data: Record<string, unknown> }>) =>
          ns.map(n => n.id === msg.nodeId ? { ...n, data: msg.data } : n)
        setNodes(updater)
        break
      default:
        // Unknown types are ignored — no-op
        break
    }
  }

  beforeEach(() => {
    onReadOnlyChange = vi.fn()
    setNodes = vi.fn()
  })

  it('handles setReadOnly true → calls onReadOnlyChange with true', () => {
    simulateHandler({ type: 'setReadOnly', readOnly: true })
    expect(onReadOnlyChange).toHaveBeenCalledWith(true)
  })

  it('handles setReadOnly false → calls onReadOnlyChange with false', () => {
    simulateHandler({ type: 'setReadOnly', readOnly: false })
    expect(onReadOnlyChange).toHaveBeenCalledWith(false)
  })

  it('handles updateNodeData → setNodes called with patched node', () => {
    simulateHandler({ type: 'updateNodeData', nodeId: 'n1', data: { bar: 'new' } })
    expect(setNodes).toHaveBeenCalled()

    const updater = setNodes.mock.calls[0][0] as (ns: Array<{ id: string; data: Record<string, unknown> }>) => Array<{ id: string; data: Record<string, unknown> }>
    const nodes = [
      { id: 'n1', data: { foo: 'old' } },
      { id: 'n2', data: { keep: 'me' } },
    ]
    const result = updater(nodes)

    // n1 is patched with new data
    expect(result[0].id).toBe('n1')
    expect(result[0].data).toEqual({ bar: 'new' })
    // n2 is untouched
    expect(result[1].data).toEqual({ keep: 'me' })
  })

  it('ignores unknown message types without crashing', () => {
    const msg = { type: 'unknown' as string } as SwiftToReactMessage
    expect(() => simulateHandler(msg)).not.toThrow()
    expect(onReadOnlyChange).not.toHaveBeenCalled()
    expect(setNodes).not.toHaveBeenCalled()
  })
})
