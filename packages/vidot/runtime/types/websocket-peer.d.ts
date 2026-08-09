declare class WebSocketPeer extends PacketPeer {
  accept_stream(stream: StreamPeer): int
  close(code?: int, reason?: string): void
  get_ready_state(): int
  poll(): void
  send_text(message: string): int
  was_string_packet(): boolean

  static readonly STATE_CONNECTING: int
  static readonly STATE_OPEN: int
  static readonly STATE_CLOSING: int
  static readonly STATE_CLOSED: int
}
