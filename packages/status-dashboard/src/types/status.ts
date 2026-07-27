export enum DashboardMode { Live = 'live', Replay = 'replay' }
export interface Resources { iron: number, cobalt: number, water: number }
export interface MonsterGroup { kind: string, count: number, health: number, max_health: number }
export type StatusSnapshot = { available: false, run_time_seconds: 0 } | {
  available: true
  run_time_seconds: number
  teacher: { state: string, nav_mode: string | null }
  keeper: {
    carried_resources: Resources
    stats: {
      base_movement_speed: number
      attack_strength: number
      carry_slowdown_percent: number
      current_movement_speed: number
      drill_strength: number
    }
  }
  dome: { health: number, max_health: number, stored_resources: Resources }
  wave: { seconds_until_next: number | null, active_monsters: MonsterGroup[] }
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
