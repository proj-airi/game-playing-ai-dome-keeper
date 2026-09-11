import type { CompoundTask, PrimitiveTask, Task } from './tasks/task.ts'
// eslint-disable-next-line ts/consistent-type-imports -- GDScript needs the class preload for this property type.
import { _LowerSession } from './lower_session.ts'
import { _CompoundTask } from './tasks/task.ts'

export class _TaskExecutor extends Node {
  recorder: _LowerSession | null = null
  task_completed = gd.signal()
  task_failed = gd.signal<[reason: string]>()

  private binding: InputEventKey | null = null
  private child: Node | null = null
  private heldAction = ''
  private keeper: Keeper | null = null
  private method: Task[] = []
  private methodStep = 0
  private physicsFrames = 0
  private task: Task | null = null

  _ready(): void {
    this.process_mode = Node.PROCESS_MODE_ALWAYS
    this.set_physics_process(false)
  }

  _physics_process(_delta: float): void {
    // ADR-0005: Check tasks every six physics frames (10 Hz at 60 physics FPS).
    this.physicsFrames += 1
    if (this.physicsFrames < 6)
      return

    this.physicsFrames = 0
    const error = this._step()
    if (error !== '')
      this._finish_failed(error)
  }

  _exit_tree(): void {
    this.cancel()
  }

  start(keeper: Keeper, task: Task): string {
    if (this.task !== null)
      return 'TaskExecutor already has an active task'
    if (!is_instance_valid(keeper))
      return 'TaskExecutor requires an active Keeper'
    if (Level.map === null)
      return 'TaskExecutor requires a loaded level map'

    this.task = task
    this.keeper = keeper
    if (this.recorder !== null)
      this.recorder.event('task_start', this.recorder.held)
    let error = ''
    if (task instanceof _CompoundTask) {
      const current: Vector2i = Level.map.getTileCoord(keeper.global_position)
      error = task.begin(keeper, current)
      if (error === '')
        error = this._start_compound(task, current)
    }
    else if (this.recorder === null) {
      error = this._step()
    }
    if (error !== '') {
      this.cancel()

      return error
    }

    this.set_physics_process(
      this.task !== null
      && (!(this.task instanceof _CompoundTask) || (this.child === null && this.methodStep >= this.method.size())),
    )

    return ''
  }

  cancel(): void {
    this.set_physics_process(false)
    this._dispose_child()
    this.method.clear()
    this.methodStep = 0
    this.physicsFrames = 0
    this.task = null
    this.keeper = null
    this._release()
  }

  private _step(): string {
    const keeper = this.keeper
    const task = this.task
    if (keeper === null || !is_instance_valid(keeper))
      return 'Keeper was freed during task execution'
    if (task === null)
      return 'TaskExecutor has no active task'
    if (Level.map === null)
      return 'TaskExecutor requires a loaded level map'

    const current: Vector2i = Level.map.getTileCoord(keeper.global_position)
    if (task.is_complete(keeper, current)) {
      if (this.recorder !== null) {
        const error = this.recorder.decision('none')
        if (error !== '')
          return error
      }
      this._finish_completed()

      return ''
    }

    const failure = task.failure(keeper)
    if (failure !== '')
      return failure

    if (task instanceof _CompoundTask)
      return ''

    const action = (task as PrimitiveTask).resolve_action(keeper, current)
    if (this.recorder !== null) {
      const error = this.recorder.decision(action === '' ? 'none' : action)
      if (error !== '')
        return error
    }
    return this._apply(action)
  }

  private _start_compound(task: CompoundTask, current: Vector2i): string {
    const keeper = this.keeper
    if (keeper === null || !is_instance_valid(keeper))
      return 'Keeper was freed during task execution'

    this.method = task.resolve_method(keeper, current)
    if (this.method.is_empty())
      return 'Compound task resolved an empty method'

    return this._start_next_child()
  }

  private _start_next_child(): string {
    const keeper = this.keeper
    if (keeper === null || !is_instance_valid(keeper))
      return 'Keeper was freed during task execution'
    if (this.methodStep >= this.method.size()) {
      const task = this.task
      if (!(task instanceof _CompoundTask))
        return 'TaskExecutor has no active compound task'

      this.set_physics_process(true)

      return this._step()
    }

    const script = this.get_script() as GDScript
    const child = script.new() as _TaskExecutor
    child.recorder = this.recorder
    this.child = child
    this.add_child(child)
    child.task_completed.connect(this._child_completed)
    child.task_failed.connect(this._child_failed)
    const error = child.start(keeper, this.method[this.methodStep])
    if (error === '')
      return ''

    this._dispose_child()

    return error
  }

  private _child_completed(): void {
    this._dispose_child()
    this.methodStep += 1
    const error = this._start_next_child()
    if (error !== '')
      this._finish_failed(error)
  }

  private _child_failed(reason: string): void {
    this._dispose_child()
    this._finish_failed(reason)
  }

  private _dispose_child(): void {
    const child = this.child as _TaskExecutor | null
    this.child = null
    if (child === null)
      return

    if (child.task_completed.is_connected(this._child_completed))
      child.task_completed.disconnect(this._child_completed)
    if (child.task_failed.is_connected(this._child_failed))
      child.task_failed.disconnect(this._child_failed)
    child.cancel()
    child.queue_free()
  }

  private _finish_completed(): void {
    if (this.recorder !== null)
      this.recorder.event('task_complete', this.recorder.held)
    this.cancel()
    this.task_completed.emit()
  }

  private _finish_failed(reason: string): void {
    this.cancel()
    this.task_failed.emit(reason)
  }

  private _apply(action: string): string {
    if (action === this.heldAction)
      return ''

    this._release()
    if (action === '')
      return ''

    const binding = this._binding(action)
    if (binding === null)
      return `Missing keyboard binding for action: ${action}`

    this.binding = binding
    this.heldAction = action
    this._dispatch(binding, true)
    if (this.recorder !== null)
      this.recorder.event('input', action)

    return ''
  }

  private _release(): void {
    const binding = this.binding
    this.binding = null
    this.heldAction = ''
    if (binding === null)
      return

    this._dispatch(binding, false)
    if (this.recorder !== null)
      this.recorder.event('input', 'none')
  }

  private _dispatch(binding: InputEventKey, pressed: boolean): void {
    const event = gd.as(binding.duplicate(), InputEventKey)
    event.pressed = pressed
    InputSystem.game_not_in_focus = false
    Input.parse_input_event(event)
    Input.flush_buffered_events()
    InputSystem.game_not_in_focus = !DisplayServer.window_is_focused()
  }

  private _binding(action: string): InputEventKey | null {
    for (const event of InputMap.action_get_events(action)) {
      if (!(event instanceof InputEventKey))
        continue

      const binding = gd.as(event.duplicate(), InputEventKey)
      binding.device = 0
      binding.echo = false

      return binding
    }

    return null
  }
}
