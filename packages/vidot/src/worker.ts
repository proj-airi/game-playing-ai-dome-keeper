import type {
  RunnerTestFile as File,
  RunnerTestSuite as Suite,
  RunnerTask as Task,
  RunnerTaskResult as TaskResult,
  RunnerTestCase as Test,
  WorkerGlobalState,
} from 'vitest'

import type {
  ResolvedViDotOptions,
  ViDotError,
  ViDotEvent,
  ViDotSuiteNode,
  ViDotTaskNode,
} from './types.ts'
import { mkdtemp, rm } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join, resolve } from 'node:path'
import { createInterface } from 'node:readline'
import { createFileTask } from '@vitest/runner/utils'

import { execa } from 'execa'
import { compileTestFile } from './compiler.ts'

const EVENT_PREFIX = 'VIDOT '
const activeCancellations = new Set<() => void>()
let cancellationHandlerRegistered = false

interface RunFile {
  specification: WorkerGlobalState['ctx']['files'][number]
  scriptPath: string
  file: File
  tasks: Map<string, Task>
  collected: boolean
  finished: boolean
}

export async function runViDot(
  method: 'run' | 'collect',
  state: WorkerGlobalState,
  options: ResolvedViDotOptions,
): Promise<void> {
  const outputRoot = await mkdtemp(join(tmpdir(), 'vidot-'))

  try {
    const files = await compileFiles(state, outputRoot)
    const filesByPath = indexFiles(files)
    let finished = false
    const launch = options.launch({ method })

    const args = [
      ...launch.args,
      '--path',
      options.projectPath,
      '--script',
      options.runnerPath,
      '--',
      ...(method === 'collect' ? ['--vidot-collect'] : []),
      ...files.map(file => `--vidot-test=${file.scriptPath}`),
    ]
    await launch.before?.()
    const child = execa(options.godotPath, args, {
      env: launch.env,
      reject: false,
      stderr: 'inherit',
      stdout: 'pipe',
    })
    const cancel = () => child.kill()

    activeCancellations.add(cancel)
    if (!cancellationHandlerRegistered) {
      state.onCancel(() => {
        for (const cancelActiveRun of activeCancellations)
          cancelActiveRun()
      })
      cancellationHandlerRegistered = true
    }

    try {
      const lines = createInterface({ input: child.stdout })
      for await (const line of lines) {
        if (!line.startsWith(EVENT_PREFIX)) {
          await state.rpc.onUserConsoleLog({
            type: 'stdout',
            content: `${line}\n`,
            time: Date.now(),
            size: 1,
          })
          continue
        }

        const event = JSON.parse(line.slice(EVENT_PREFIX.length)) as ViDotEvent
        if (event.type === 'run_finish') {
          finished = true
          continue
        }

        const file = filesByPath.get(resolve(event.file))
        if (!file)
          throw new Error(`Godot reported an unknown test file: ${event.file}`)

        await applyEvent(method, state, file, event)
      }

      const result = await child
      if (result.exitCode !== 0)
        throw new Error(`Godot exited with code ${result.exitCode ?? 'unknown'}`)
      if (!finished)
        throw new Error('Godot exited without a run_finish event')

      const incomplete = files.filter(file => (
        method === 'collect' ? !file.collected : !file.finished
      ))
      if (incomplete.length > 0) {
        throw new Error(
          `Godot did not finish: ${incomplete.map(file => file.specification.filepath).join(', ')}`,
        )
      }

      await launch.after?.()
    }
    finally {
      activeCancellations.delete(cancel)
      child.kill()
      await child
    }
  }
  finally {
    await rm(outputRoot, { force: true, recursive: true })
  }
}

async function compileFiles(
  state: WorkerGlobalState,
  outputRoot: string,
): Promise<RunFile[]> {
  const files: RunFile[] = []

  for (const [index, specification] of state.ctx.files.entries()) {
    const outputDirectory = join(outputRoot, String(index))

    const { scriptPath } = await compileTestFile({
      sourcePath: specification.filepath,
      outputDirectory,
    })
    const file = createFile(
      specification.filepath,
      state.config.root,
      state.config.name,
    )
    // Worker messages normally deserialize into distinct task objects. The in-process
    // transport must preserve that boundary so Vitest indexes collected children.
    // `state.rpc` is Vitest's official worker/reporting channel. Godot itself
    // communicates with ViDot only through the structured stdout events above.
    await state.rpc.onQueued(createFile(
      specification.filepath,
      state.config.root,
      state.config.name,
    ))
    files.push({
      specification,
      scriptPath: resolve(scriptPath),
      file,
      tasks: new Map(),
      collected: false,
      finished: false,
    })
  }

  return files
}

function createFile(filepath: string, root: string, projectName?: string): File {
  return createFileTask(filepath, root, projectName, 'vidot', 'ssr') as File
}

function indexFiles(files: RunFile[]): Map<string, RunFile> {
  const index = new Map<string, RunFile>()

  for (const file of files) {
    index.set(resolve(file.scriptPath), file)
  }

  return index
}

async function applyEvent(
  method: 'run' | 'collect',
  state: WorkerGlobalState,
  runFile: RunFile,
  event: Exclude<ViDotEvent, { type: 'run_finish' }>,
): Promise<void> {
  switch (event.type) {
    case 'file_collected':
      await reportCollection(method, state, runFile, event.tree)
      return
    case 'test_start':
      await reportTestStart(state, runFile, event.id)
      return
    case 'test_finish':
      await reportTestFinish(state, runFile, event)
      return
    case 'file_finish':
      await reportFileFinish(state, runFile, event.duration, event.errors)
  }
}

async function reportCollection(
  method: 'run' | 'collect',
  state: WorkerGlobalState,
  runFile: RunFile,
  tree: ViDotSuiteNode,
): Promise<void> {
  const file = runFile.file
  file.mode = 'run'
  file.tasks = tree.children.map((node, index) => createTask(
    state,
    runFile,
    file,
    node,
    index,
  ))
  file.collectDuration = 0
  runFile.collected = true

  await state.rpc.onCollected([file])
  if (method === 'run') {
    file.result = { state: 'run', startTime: Date.now() }
    await state.rpc.onTaskUpdate(
      [[file.id, file.result, file.meta]],
      [[file.id, 'suite-prepare', undefined]],
    )
  }
}

function createTask(
  state: WorkerGlobalState,
  runFile: RunFile,
  parent: Suite,
  node: ViDotTaskNode,
  index: number,
): Task {
  const file = runFile.file
  const fullTestName = parent.fullTestName
    ? `${parent.fullTestName} > ${node.name}`
    : node.name
  const base = {
    id: `${parent.id}_${index}`,
    name: node.name,
    fullName: `${file.name} > ${fullTestName}`,
    fullTestName,
    mode: 'run',
    meta: {},
    file,
    suite: parent,
  } as const

  if (node.type === 'suite') {
    const suite: Suite = {
      ...base,
      type: 'suite',
      tasks: [],
    }
    runFile.tasks.set(node.id, suite)
    suite.tasks = node.children.map((child, childIndex) => createTask(
      state,
      runFile,
      suite,
      child,
      childIndex,
    ))
    return suite
  }

  const test: Test = {
    ...base,
    type: 'test',
    context: {} as Test['context'],
    timeout: state.config.testTimeout,
    annotations: [],
    artifacts: [],
  }
  runFile.tasks.set(node.id, test)
  return test
}

async function reportTestStart(
  state: WorkerGlobalState,
  runFile: RunFile,
  id: string,
): Promise<void> {
  const test = getTest(runFile, id)
  test.result = {
    state: 'run',
    startTime: Date.now(),
  }
  await state.rpc.onTaskUpdate(
    [[test.id, test.result, test.meta]],
    [[test.id, 'test-prepare', undefined]],
  )
}

async function reportTestFinish(
  state: WorkerGlobalState,
  runFile: RunFile,
  event: Extract<ViDotEvent, { type: 'test_finish' }>,
): Promise<void> {
  const test = getTest(runFile, event.id)
  test.result = {
    state: event.state,
    startTime: test.result?.startTime,
    duration: event.duration,
    errors: toTestErrors(event.errors),
  }
  await state.rpc.onTaskUpdate(
    [[test.id, test.result, test.meta]],
    [[test.id, 'test-finished', undefined]],
  )
}

async function reportFileFinish(
  state: WorkerGlobalState,
  runFile: RunFile,
  duration?: number,
  errors?: ViDotError[],
): Promise<void> {
  const file = runFile.file
  if (!runFile.collected)
    throw new Error(`Godot finished an uncollected file: ${file.filepath}`)

  file.result = {
    state: errors?.length || hasFailedTask(file) ? 'fail' : 'pass',
    duration,
    errors: toTestErrors(errors),
  }
  await state.rpc.onTaskUpdate(
    [[file.id, file.result, file.meta]],
    [[file.id, 'suite-finished', undefined]],
  )
  runFile.finished = true
}

function getTest(runFile: RunFile, id: string): Test {
  const task = runFile.tasks.get(id)
  if (task?.type !== 'test')
    throw new Error(`Godot reported an unknown test: ${id}`)
  return task
}

function hasFailedTask(suite: Suite): boolean {
  return suite.tasks.some(task => (
    task.result?.state === 'fail'
    || (task.type === 'suite' && hasFailedTask(task))
  ))
}

function toTestErrors(errors?: ViDotError[]): TaskResult['errors'] {
  return errors?.map(error => ({
    name: error.name,
    message: error.message,
  }))
}
