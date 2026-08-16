interface TestContext {
  tree: SceneTree
}

interface TaskBase {
  id: string
  name: string
  type: 'suite' | 'test'
}

interface TestTask extends TaskBase {
  type: 'test'
  callback: Callable
}

interface SuiteTask extends TaskBase {
  type: 'suite'
  children: Array<Task>
  before_all: Array<Callable>
  before_each: Array<Callable>
  after_each: Array<Callable>
  after_all: Array<Callable>
}

type Task = SuiteTask | TestTask
type EventData = Dictionary<string, unknown>

interface LoadedScript {
  script: GDScript | null
  error: string
}

export class _Runner extends SceneTree {
  private _collect_only = false
  private _files: Array<string> = []
  private _current_file = ''
  private _current_module: RefCounted | null = null
  private _root_task!: SuiteTask
  private _suite_stack: Array<SuiteTask> = []
  private _next_task_id: int = 1
  private _active_errors: Array<EventData> = []
  private _file_errors: Array<EventData> = []
  private _baseline_nodes: Dictionary<int, bool> = {}

  _initialize(): void {
    this.process_frame.connect(this._run)
  }

  private async _run(): Promise<void> {
    this.process_frame.disconnect(this._run)
    this._read_arguments()
    this._remember_baseline_nodes()

    for (const file of this._files) {
      const started_at = Time.get_ticks_msec()
      if (!this._collect(file)) {
        this._emit_file_finish(started_at)

        continue
      }

      if (!this._collect_only) {
        await this._run_suite(this._root_task, [])
        await this._cleanup_test_nodes()
        this._emit_file_finish(started_at)
      }

      this._current_module = null
      this._root_task.clear()
    }

    this._emit({ type: 'run_finish' })
    this.quit()
  }

  private _read_arguments(): void {
    for (const argument of OS.get_cmdline_user_args()) {
      if (argument === '--vidot-collect') {
        this._collect_only = true
      }
      else if (argument.begins_with('--vidot-test=')) {
        this._files.append(argument.trim_prefix('--vidot-test='))
      }
    }
  }

  private _collect(file: string): bool {
    this._current_file = file
    this._file_errors = []
    this._next_task_id = 1
    this._suite_stack.clear()
    this._root_task = this._new_suite(file.get_file())
    this._suite_stack = [this._root_task]

    const loaded = this._load_test_script(file)
    if (loaded.script === null) {
      this._file_errors.append(this._error(loaded.error))
      this._emit_collected()

      return false
    }

    this._current_module = gd.as(loaded.script.new(), RefCounted)
    if (this._current_module === null || !this._current_module.has_method('vidot_collect')) {
      this._file_errors.append(this._error('generated test module must define vidot_collect(api)'))
      this._emit_collected()

      return false
    }

    this._current_module.call('vidot_collect', this)
    this._emit_collected()

    return true
  }

  private _load_test_script(file: string): LoadedScript {
    if (file.begins_with('res://') || file.begins_with('user://')) {
      const resource = load(file)
      if (resource instanceof GDScript)
        return { script: resource, error: '' }

      return { script: null, error: `could not load test script ${file}` }
    }

    if (!FileAccess.file_exists(file))
      return { script: null, error: `test script does not exist: ${file}` }

    const script = new GDScript()
    script.source_code = FileAccess.get_file_as_string(file)
    const reload_error = script.reload()
    if (reload_error !== Error.OK) {
      return {
        script: null,
        error: `could not compile test script ${file} (error ${reload_error})`,
      }
    }

    return { script: script, error: '' }
  }

  describe(name: string, callback: Callable): void {
    const suite = this._new_suite(name)
    this._suite_stack.back().children.append(suite)
    this._suite_stack.append(suite)
    callback.call()
    this._suite_stack.pop_back()
  }

  test(name: string, callback: Callable): void {
    this._suite_stack.back().children.append({
      id: this._take_task_id(),
      name: name,
      type: 'test',
      callback: callback,
    })
  }

  beforeAll(callback: Callable): void {
    this._suite_stack.back().before_all.append(callback)
  }

  beforeEach(callback: Callable): void {
    this._suite_stack.back().before_each.append(callback)
  }

  afterEach(callback: Callable): void {
    this._suite_stack.back().after_each.append(callback)
  }

  afterAll(callback: Callable): void {
    this._suite_stack.back().after_all.append(callback)
  }

  expect(actual: unknown): _Runner.Expectation {
    return _Runner.Expectation.create(this, actual)
  }

  record_assertion(message: string): void {
    this._active_errors.append(this._error(message, 'AssertionError'))
  }

  private async _run_suite(
    suite: SuiteTask,
    parents: Array<SuiteTask>,
  ): Promise<void> {
    const lineage = parents.duplicate()
    lineage.append(suite)

    await this._run_file_hooks(suite.before_all)

    for (const child of suite.children) {
      if (child.type === 'suite')
        await this._run_suite(child, lineage)
      else
        await this._run_test(child, lineage)
    }

    await this._run_file_hooks(suite.after_all)
  }

  private async _run_test(
    task: TestTask,
    lineage: Array<SuiteTask>,
  ): Promise<void> {
    const started_at = Time.get_ticks_msec()
    this._active_errors = []
    this._emit({ type: 'test_start', file: this._current_file, id: task.id })
    const context: TestContext = { tree: this }

    for (const suite of lineage)
      await this._run_callbacks(suite.before_each, context)

    if (this._active_errors.is_empty())
      await this._run_callback(task.callback, context)

    for (const index of range(lineage.size() - 1, -1, -1))
      await this._run_callbacks(lineage[index].after_each, context)

    await this._cleanup_test_nodes()
    const event: EventData = {
      type: 'test_finish',
      file: this._current_file,
      id: task.id,
      state: this._active_errors.is_empty() ? 'pass' : 'fail',
      duration: Time.get_ticks_msec() - started_at,
    }
    if (!this._active_errors.is_empty())
      event.errors = this._active_errors

    this._emit(event)
  }

  private async _run_callbacks(callbacks: Array<Callable>, context: TestContext): Promise<void> {
    for (const callback of callbacks)
      await this._run_callback(callback, context)
  }

  private async _run_callback(callback: Callable, context: TestContext): Promise<void> {
    if (callback.get_argument_count() === 0) {
      await callback.call()

      return
    }

    await callback.call(context)
  }

  private async _run_file_hooks(callbacks: Array<Callable>): Promise<void> {
    this._active_errors = []
    await this._run_callbacks(callbacks, { tree: this })
    this._file_errors.append_array(this._active_errors)
  }

  private async _cleanup_test_nodes(): Promise<void> {
    let queued = false
    for (const child of this.root.get_children()) {
      if (!this._baseline_nodes.has(child.get_instance_id())) {
        child.queue_free()
        queued = true
      }
    }

    if (queued)
      await this.process_frame
  }

  private _remember_baseline_nodes(): void {
    for (const child of this.root.get_children())
      this._baseline_nodes[child.get_instance_id()] = true
  }

  private _new_suite(name: string): SuiteTask {
    return {
      id: this._suite_stack.is_empty() ? '0' : this._take_task_id(),
      name: name,
      type: 'suite',
      children: [],
      before_all: [],
      before_each: [],
      after_each: [],
      after_all: [],
    }
  }

  private _take_task_id(): string {
    const id = str(this._next_task_id)
    this._next_task_id += 1

    return id
  }

  private _emit_collected(): void {
    this._emit({
      type: 'file_collected',
      file: this._current_file,
      tree: this._public_task(this._root_task),
    })
  }

  private _public_task(task: Task): EventData {
    const public_task: EventData = {
      id: task.id,
      name: task.name,
      type: task.type,
    }
    if (task.type === 'suite') {
      const children: Array<EventData> = []
      public_task.children = children
      for (const child of task.children)
        children.append(this._public_task(child))
    }

    return public_task
  }

  private _emit_file_finish(started_at: int): void {
    const event: EventData = {
      type: 'file_finish',
      file: this._current_file,
      duration: Time.get_ticks_msec() - started_at,
    }
    if (!this._file_errors.is_empty())
      event.errors = this._file_errors

    this._emit(event)
  }

  private _error(message: string, name: string = 'Error'): EventData {
    return { name: name, message: message }
  }

  private _emit(event: EventData): void {
    print(_Runner.EVENT_PREFIX + JSON.stringify(event))
  }
}

// tstogd represents GDScript inner classes through a namespace merged with the outer class.
// eslint-disable-next-line ts/no-namespace
export namespace _Runner {
  export const EVENT_PREFIX = 'VIDOT '

  export class Expectation extends RefCounted {
    private _runner!: TSOnly<_Runner>
    private _actual: unknown

    static create(
      runner: TSOnly<_Runner>,
      actual: unknown,
    ): Expectation {
      const expectation = new Expectation()
      expectation._runner = runner
      expectation._actual = actual

      return expectation
    }

    toBe(expected: unknown): bool {
      return this._finish(is_same(this._actual, expected), 'to be', expected)
    }

    toEqual(expected: unknown): bool {
      return this._finish(this._actual === expected, 'to equal', expected)
    }

    private _finish(matched: bool, matcher: string, expected: unknown): bool {
      if (matched)
        return true

      const message = `expected ${var_to_str(this._actual)} ${matcher} ${var_to_str(expected)}`
      this._runner.record_assertion(message)

      return false
    }
  }
}
