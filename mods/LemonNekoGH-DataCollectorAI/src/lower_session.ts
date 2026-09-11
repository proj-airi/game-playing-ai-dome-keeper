/* eslint-disable object-shorthand -- tstogd requires explicit dictionary values. */
// ADR-0005: capture precedes the decision; one recorder follows all child tasks.
export class _LowerSession extends Node {
  actions = ['ui_up', 'ui_down', 'ui_left', 'ui_right', 'ui_select', 'keeper1_pickup', 'keeper1_drop', 'dome1_fire', 'none']
  held = 'none'
  private directory = ''
  private session: Dictionary<string, unknown> = {}
  private steps: Dictionary<string, unknown>[] = []
  private events: Dictionary<string, unknown>[] = []
  private capture: Dictionary<string, unknown> = {}
  private order = 0
  private lastDecision = -1

  _ready(): void {
    RenderingServer.frame_post_draw.connect(this._record_frame)
  }

  begin(output: string, task: string, target: string, scenario: Dictionary<string, unknown>): string {
    const key = JSON.stringify(scenario).sha256_text()
    const id = `${task}-${target}-${Time.get_unix_time_from_system()}-${Time.get_ticks_usec()}`
    this.directory = output.path_join('.incomplete').path_join(id)
    if (DirAccess.make_dir_recursive_absolute(this.directory.path_join('frames')) !== 0)
      return 'Cannot create temporary Session'
    const bindings: Dictionary<string, unknown>[] = []
    for (const action of this.actions) {
      if (action === 'none')
        continue
      let found = false
      for (const event of InputMap.action_get_events(action)) {
        if (!(event instanceof InputEventKey))
          continue
        bindings.append({ action: action, keycode: event.keycode, physical_keycode: event.physical_keycode })
        found = true
        break
      }
      if (!found)
        return `Missing configured keyboard binding: ${action}`
    }
    this.session = {
      schema_version: 1,
      id: id,
      scenario_id: key,
      scenario: scenario,
      instruction: { task: task, target: target },
      versions: { game: OS.get_environment('DOMEKEEPER_VERSION'), collector: '0.0.2' },
      movie: OS.get_environment('VIDOT_MOVIE'),
      bindings: bindings,
      input_source: 'InputMap/Input.parse_input_event',
      steps: this.steps,
      events: this.events,
    }
    this.event('start', 'none')
    return ''
  }

  event(kind: string, action: string): void {
    const entry = this._stamp()
    entry.kind = kind
    entry.action = action
    this.events.append(entry)
    if (kind === 'input')
      this.held = action
  }

  decision(action: string): string {
    const physics = Engine.get_physics_frames()
    if (physics === this.lastDecision)
      return ''
    if (this.capture.is_empty() || physics - (this.capture.physics_frame as number) > 6)
      return 'No valid completed RGB frame before decision'
    const frameId = str(this.steps.size())
    const step = this.capture.duplicate()
    const stamp = this._stamp()
    step.capture_order = step.order
    step.order = stamp.order
    step.decision_time_us = stamp.time_us
    step.decision_physics_frame = stamp.physics_frame
    step.decision_video_frame = Engine.get_process_frames()
    step.frame_id = frameId
    step.next_action = action
    this.steps.append(step)
    this.lastDecision = physics
    return ''
  }

  finish(success: boolean): string {
    this.event(success ? 'success' : 'cancel', this.held)
    if (!success)
      return ''
    if (this.steps.is_empty() || this.held !== 'none'
      || this.steps.back().next_action !== 'none') {
      return 'Incomplete Session cannot be promoted'
    }
    const outcome = this._stamp()
    outcome.status = 'success'
    outcome.final_held_action = this.held
    this.session.outcome = outcome
    const file = FileAccess.open(this.directory.path_join('session.json'), FileAccess.WRITE)
    if (file === null)
      return 'Cannot write Session metadata'
    file.store_string(JSON.stringify(this.session))
    file.close()
    return ''
  }

  private _record_frame(): void {
    this.capture = this._stamp()
    // Movie Maker writes this zero-based frame after frame_post_draw.
    this.capture.video_frame = Engine.get_process_frames()
    this.capture.held_action = this.held
  }

  private _stamp(): Dictionary<string, unknown> {
    this.order += 1
    return { order: this.order, time_us: Time.get_ticks_usec(), physics_frame: Engine.get_physics_frames() }
  }
}
