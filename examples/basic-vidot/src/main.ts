export class _Example extends Node {
  completed = gd.signal<[value: int]>()
  value: int = 0

  increment(amount: int): int {
    this.value += amount

    return this.value
  }

  async set_later(nextValue: int): Promise<void> {
    await this.get_tree().create_timer(0.05).timeout
    this.value = nextValue
    this.completed.emit(this.value)
  }
}
