export enum DashboardMode { Live = 'live', Replay = 'replay' }
export interface Resources { iron: number, cobalt: number, water: number }
export interface MonsterGroup { kind: string, count: number, health: number, max_health: number }
export interface LeveledValue { value: number, level: number }
export type StatusSnapshot = { available: false, run_time_seconds: 0 } | {
  available: true
  run_time_seconds: number
  teacher: { state: string, nav_mode: string | null }
  keeper: {
    carried_resources: Resources
    stats: {
      movement_speed: { base: number, current: number, level: number }
      carry_strength: { speed_loss_per_carry: number, current_slowdown_percent: number, level: number }
      drill_strength: LeveledValue
    }
  }
  dome: {
    health: { current: number, maximum: number, level: number }
    laser: {
      attack_strength: LeveledValue
      movement_speed: { value: number, while_firing: number, level: number }
    }
    stored_resources: Resources
  }
  wave: { number: number, seconds_until_next: number | null, active_monsters: MonsterGroup[] }
  upgrades: { pending_intents: string[], resolved_next: { id: string, cost: Resources } | null }
}
export interface ReplayRecording {
  fixed_fps: number
  events: Array<{
    movie_frame: number
    type: string
    reason: string
    transition: { from: string, to: string } | null
    state: StatusSnapshot
  }>
}
