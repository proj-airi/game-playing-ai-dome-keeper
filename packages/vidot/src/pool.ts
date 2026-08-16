import type { WorkerGlobalState } from 'vitest'
import type {
  PoolWorker,
  WorkerRequest,
} from 'vitest/node'

import type { ResolvedViDotOptions } from './types.ts'
import { EventEmitter } from 'node:events'

import { init } from 'vitest/worker'
import { runViDot } from './worker.ts'

type MessageListener = (message: unknown) => void

export class ViDotPoolWorker implements PoolWorker {
  readonly name = 'vidot'

  private readonly events = new EventEmitter()
  private readonly requestListeners = new Set<MessageListener>()

  constructor(options: ResolvedViDotOptions) {
    init({
      on: (listener) => {
        this.requestListeners.add(listener)
      },
      off: (listener) => {
        this.requestListeners.delete(listener)
      },
      post: message => this.events.emit('message', message),
      runTests: (state: WorkerGlobalState) => runViDot('run', state, options),
      collectTests: (state: WorkerGlobalState) => runViDot('collect', state, options),
    })
  }

  on(event: string, callback: MessageListener): void {
    this.events.on(event, callback)
  }

  off(event: string, callback: MessageListener): void {
    this.events.off(event, callback)
  }

  send(message: WorkerRequest): void {
    for (const listener of this.requestListeners)
      listener(message)
  }

  deserialize(data: unknown): unknown {
    return data
  }

  start(): Promise<void> {
    return Promise.resolve()
  }

  stop(): Promise<void> {
    return Promise.resolve()
  }

  canReuse(): boolean {
    return true
  }
}
