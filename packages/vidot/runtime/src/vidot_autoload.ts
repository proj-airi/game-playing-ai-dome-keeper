interface Request {
  args: unknown[] | null
  command: string
  expected: unknown
  id: string
  method: string | null
  path: string | null
  property: string | null
  protocolVersion: int | null
  session: string | null
  signal: string | null
  timeoutMs: int | null
  value: unknown
}

interface PropertyWait {
  deadline: int
  expected: unknown
  id: string
  property: string
  target: Node
}

interface SignalWait {
  callback: Callable
  deadline: int
  id: string
  signal: string
  target: Node
}

export class _VidotAutoload extends Node {
  private initialized = false
  private peer: WebSocketPeer | null = null
  private propertyWaits: PropertyWait[] = []
  private server = new TCPServer()
  private session = ''
  private signalWaits: SignalWait[] = []
  private startupDeadline: int = 0

  _ready() {
    for (const argument of OS.get_cmdline_user_args()) {
      if (argument.begins_with('--vidot-session='))
        this.session = argument.substr(16)
    }

    if (this.session === '') {
      this.set_process(false)

      return
    }

    this.process_mode = Node.PROCESS_MODE_ALWAYS
    this.startupDeadline = Time.get_ticks_msec() + 30_000
    if (this.server.listen(0, '127.0.0.1') !== Error.OK) {
      push_error('ViDot could not listen on 127.0.0.1')
      this.get_tree().quit(1)

      return
    }

    print(`VIDOT_READY ${this.session} ${this.server.get_local_port()}`)
  }

  _process(_delta: float) {
    this._accept_peer()
    if (this.peer !== null) {
      this.peer.poll()
      if (this.peer.get_ready_state() === WebSocketPeer.STATE_OPEN)
        this._read_requests()

      if (this.peer.get_ready_state() === WebSocketPeer.STATE_CLOSED)
        this._reset_peer()
    }

    this._check_property_waits()
    this._check_signal_timeouts()
    if (!this.initialized && Time.get_ticks_msec() >= this.startupDeadline)
      this.get_tree().quit(1)
  }

  private _accept_peer() {
    if (this.peer !== null || !this.server.is_connection_available())
      return

    const stream = this.server.take_connection()
    if (stream === null)
      return

    this.peer = new WebSocketPeer()
    if (this.peer.accept_stream(stream) !== Error.OK)
      this._reset_peer()
  }

  private _read_requests() {
    if (this.peer === null)
      return

    while (this.peer.get_available_packet_count() > 0) {
      const packet = this.peer.get_packet()
      if (!this.peer.was_string_packet()) {
        this.peer.close(1003, 'ViDot accepts JSON text frames only')

        return
      }

      const parsed = JSON.parse_string(packet.get_string_from_utf8())
      const parsedIsDictionary = gd.eval<boolean>('typeof(parsed) == TYPE_DICTIONARY')
      if (!parsedIsDictionary) {
        this.peer.close(1007, 'Invalid request')

        return
      }

      const request = parsed as Request
      const hasEnvelope = gd.eval<boolean>('typeof(request.get("id")) == TYPE_STRING and typeof(request.get("command")) == TYPE_STRING')
      if (!hasEnvelope) {
        this.peer.close(1007, 'A string id and command are required')

        return
      }

      this._dispatch(request)
    }
  }

  private _dispatch(request: Request) {
    if (!this.initialized) {
      this._initialize(request)

      return
    }

    switch (request.command) {
      case 'get':
        this._handle_get(request)

        return
      case 'set':
        this._handle_set(request)

        return
      case 'call':
        this._call(request)

        return
      case 'waitForProperty':
        this._wait_for_property(request)

        return
      case 'waitForSignal':
        this._wait_for_signal(request)

        return
      default:
        this._send_error(request.id, `Unknown command: ${request.command}`)
    }
  }

  private _initialize(request: Request) {
    if (request.command !== 'initialize' || request.protocolVersion !== 1 || request.session !== this.session) {
      this._send_error(request.id, 'ViDot session initialization failed')
      if (this.peer !== null)
        this.peer.close(1008, 'Initialization failed')

      return
    }

    this.initialized = true
    this.server.stop()
    this._send_result(request.id, { protocolVersion: 1 })
  }

  private _handle_get(request: Request) {
    const target = this._target(request)
    if (target === null)
      return

    if (request.property === null) {
      this._send_error(request.id, 'A property is required')

      return
    }

    if (!this._has_property(target, request.property)) {
      this._send_error(request.id, `Unknown property: ${request.property}`)

      return
    }

    this._send_result(request.id, target.get(request.property))
  }

  private _handle_set(request: Request) {
    const target = this._target(request)
    if (target === null)
      return

    if (request.property === null) {
      this._send_error(request.id, 'A property is required')

      return
    }

    if (!this._has_property(target, request.property)) {
      this._send_error(request.id, `Unknown property: ${request.property}`)

      return
    }

    target.set(request.property, request.value)
    this._send_result(request.id, target.get(request.property))
  }

  private _call(request: Request) {
    const target = this._target(request)
    if (target === null)
      return

    if (request.method === null) {
      this._send_error(request.id, 'A method is required')

      return
    }

    if (!target.has_method(request.method)) {
      this._send_error(request.id, `Unknown method: ${request.method}`)

      return
    }

    const args = request.args === null ? [] : request.args

    this._send_result(request.id, target.callv(request.method, args))
  }

  private _wait_for_property(request: Request) {
    const target = this._target(request)
    if (target === null)
      return

    if (request.property === null) {
      this._send_error(request.id, 'A property is required')

      return
    }

    if (!this._has_property(target, request.property)) {
      this._send_error(request.id, `Unknown property: ${request.property}`)

      return
    }

    if (target.get(request.property) === request.expected) {
      this._send_result(request.id, target.get(request.property))

      return
    }

    const timeoutMs = request.timeoutMs === null ? 1000 : request.timeoutMs
    this.propertyWaits.push_back({
      deadline: Time.get_ticks_msec() + timeoutMs,
      expected: request.expected,
      id: request.id,
      property: request.property,
      target: target,
    })
  }

  private _wait_for_signal(request: Request) {
    const target = this._target(request)
    if (target === null)
      return

    if (request.signal === null) {
      this._send_error(request.id, 'A signal is required')

      return
    }

    if (!target.has_signal(request.signal)) {
      this._send_error(request.id, `Unknown signal: ${request.signal}`)

      return
    }

    const callback = Callable(this, '_complete_signal_wait')
      .bind(request.id)
      .unbind(this._signal_argument_count(target, request.signal))
    if (target.connect(request.signal, callback, 4) !== Error.OK) {
      this._send_error(request.id, `Could not connect signal: ${request.signal}`)

      return
    }

    const timeoutMs = request.timeoutMs === null ? 1000 : request.timeoutMs
    this.signalWaits.push_back({
      callback: callback,
      deadline: Time.get_ticks_msec() + timeoutMs,
      id: request.id,
      signal: request.signal,
      target: target,
    })
  }

  private _complete_signal_wait(id: string) {
    for (const index of range(this.signalWaits.size())) {
      if (this.signalWaits[index].id !== id)
        continue

      this.signalWaits.remove_at(index)
      this._send_result(id, null)

      return
    }
  }

  private _check_property_waits() {
    const now = Time.get_ticks_msec()
    for (const index of range(this.propertyWaits.size() - 1, -1, -1)) {
      const wait = this.propertyWaits[index]
      if (!is_instance_valid(wait.target)) {
        this.propertyWaits.remove_at(index)
        this._send_error(wait.id, 'Property target was freed')
        continue
      }

      const value = wait.target.get(wait.property)
      if (value === wait.expected) {
        this.propertyWaits.remove_at(index)
        this._send_result(wait.id, value)
        continue
      }

      if (now >= wait.deadline) {
        this.propertyWaits.remove_at(index)
        this._send_error(wait.id, `Timed out waiting for property: ${wait.property}`)
      }
    }
  }

  private _check_signal_timeouts() {
    const now = Time.get_ticks_msec()
    for (const index of range(this.signalWaits.size() - 1, -1, -1)) {
      const wait = this.signalWaits[index]
      if (now < wait.deadline)
        continue

      if (is_instance_valid(wait.target) && wait.target.is_connected(wait.signal, wait.callback))
        wait.target.disconnect(wait.signal, wait.callback)

      this.signalWaits.remove_at(index)
      this._send_error(wait.id, `Timed out waiting for signal: ${wait.signal}`)
    }
  }

  private _target(request: Request): Node | null {
    if (request.path === null) {
      this._send_error(request.id, 'A node path is required')

      return null
    }

    const target = this.get_node_or_null(request.path)
    if (target === null)
      this._send_error(request.id, `Unknown node: ${request.path}`)

    return target
  }

  private _has_property(target: Node, propertyName: string): boolean {
    for (const info of target.get_property_list()) {
      if (String(info.get('name')) === propertyName)
        return true
    }

    return false
  }

  private _signal_argument_count(target: Node, signalName: string): int {
    for (const info of target.get_signal_list()) {
      if (String(info.get('name')) !== signalName)
        continue

      return (info.get('args') as unknown[]).size()
    }

    return 0
  }

  private _send_result(id: string, result: unknown) {
    if (this.peer !== null && this.peer.get_ready_state() === WebSocketPeer.STATE_OPEN)
      this.peer.send_text(JSON.stringify({ id: id, result: result }))
  }

  private _send_error(id: string, error: string) {
    if (this.peer !== null && this.peer.get_ready_state() === WebSocketPeer.STATE_OPEN)
      this.peer.send_text(JSON.stringify({ error: error, id: id }))
  }

  private _reset_peer() {
    const wasInitialized = this.initialized
    for (const wait of this.signalWaits) {
      if (is_instance_valid(wait.target) && wait.target.is_connected(wait.signal, wait.callback))
        wait.target.disconnect(wait.signal, wait.callback)
    }
    this.signalWaits.clear()
    this.propertyWaits.clear()
    this.peer = null
    this.initialized = false
    if (wasInitialized)
      this.get_tree().quit()
  }
}
