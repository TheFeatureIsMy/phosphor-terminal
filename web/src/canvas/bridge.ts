import type { ReactToSwiftMessage, SwiftToReactMessage } from './types'

type MessageHandler = (msg: SwiftToReactMessage) => void

let handler: MessageHandler | null = null

export function setBridgeHandler(h: MessageHandler) {
  handler = h
}

export function sendToSwift(msg: ReactToSwiftMessage) {
  try {
    const w = window as unknown as {
      webkit?: { messageHandlers?: { canvas?: { postMessage: (m: unknown) => void } } }
    }
    if (w.webkit?.messageHandlers?.canvas) {
      w.webkit.messageHandlers.canvas.postMessage(msg)
    } else {
      console.log('[bridge:dev] →Swift', JSON.stringify(msg).slice(0, 200))
    }
  } catch (e) {
    console.warn('[bridge] sendToSwift error', e)
  }
}

function onReceive(msg: SwiftToReactMessage) {
  if (handler) handler(msg)
}

;(window as unknown as { bridge: { receive: typeof onReceive } }).bridge = {
  receive: onReceive,
}
