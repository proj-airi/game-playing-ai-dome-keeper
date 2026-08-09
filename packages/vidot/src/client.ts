export type JsonValue = boolean | number | string | null | JsonValue[] | { [key: string]: JsonValue }

interface Response {
  error?: string
  id: string
  result?: JsonValue
}

interface PendingRequest {
  reject: (error: Error) => void
  resolve: (value: JsonValue) => void
}

export class VidotClient {
  private nextId = 0
  private pending = new Map<string, PendingRequest>()

  private constructor(private socket: WebSocket) {
    socket.addEventListener('message', event => this.receive(String(event.data)))
    socket.addEventListener('close', () => this.rejectPending(new Error('ViDot connection closed')))
  }

  static async connect(url: string, timeoutMs: number): Promise<VidotClient> {
    const socket = new WebSocket(url)
    await new Promise<void>((resolve, reject) => {
      const timeout = setTimeout(() => {
        socket.close()
        reject(new Error(`Timed out connecting to ${url}`))
      }, timeoutMs)
      socket.addEventListener('open', () => {
        clearTimeout(timeout)
        resolve()
      }, { once: true })
      socket.addEventListener('error', () => {
        clearTimeout(timeout)
        reject(new Error(`Could not connect to ${url}`))
      }, { once: true })
    })

    return new VidotClient(socket)
  }

  initialize(session: string): Promise<JsonValue> {
    return this.request({ command: 'initialize', protocolVersion: 1, session })
  }

  get(path: string, property: string): Promise<JsonValue> {
    return this.request({ command: 'get', path, property })
  }

  set(path: string, property: string, value: JsonValue): Promise<JsonValue> {
    return this.request({ command: 'set', path, property, value })
  }

  call(path: string, method: string, args: JsonValue[] = []): Promise<JsonValue> {
    return this.request({ args, command: 'call', method, path })
  }

  waitForProperty(path: string, property: string, expected: JsonValue, timeoutMs = 1000): Promise<JsonValue> {
    return this.request({ command: 'waitForProperty', expected, path, property, timeoutMs })
  }

  waitForSignal(path: string, signal: string, timeoutMs = 1000): Promise<JsonValue> {
    return this.request({ command: 'waitForSignal', path, signal, timeoutMs })
  }

  close(): void {
    this.socket.close()
    this.rejectPending(new Error('ViDot client closed'))
  }

  private request(payload: Record<string, JsonValue>): Promise<JsonValue> {
    const id = String(this.nextId += 1)

    return new Promise((resolve, reject) => {
      this.pending.set(id, { reject, resolve })
      try {
        this.socket.send(JSON.stringify({ ...payload, id }))
      }
      catch (error) {
        this.pending.delete(id)
        reject(error)
      }
    })
  }

  private receive(message: string): void {
    let response: Response
    try {
      response = JSON.parse(message)
    }
    catch {
      this.rejectPending(new Error('ViDot returned invalid JSON'))
      this.socket.close()

      return
    }
    const pending = this.pending.get(response.id)
    if (!pending)
      return

    this.pending.delete(response.id)
    if (response.error) {
      pending.reject(new Error(response.error))

      return
    }

    pending.resolve(response.result ?? null)
  }

  private rejectPending(error: Error): void {
    for (const pending of this.pending.values())
      pending.reject(error)
    this.pending.clear()
  }
}
