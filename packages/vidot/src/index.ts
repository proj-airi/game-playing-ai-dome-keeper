import type { ResultPromise } from 'execa'
import type { Buffer } from 'node:buffer'
import type { GodotProjectSandbox } from './sandbox'
import type { VidotContext } from './setup'
import { existsSync } from 'node:fs'
import path from 'node:path'
import { execa } from 'execa'
import { inject, test as vitest } from 'vitest'
import { VidotClient } from './client'
import { assertAutoloadInjected } from './project'
import { cleanupGodotProjectSandbox, createGodotProjectSandbox } from './sandbox'

const startupTimeoutMs = 30_000

export { type JsonValue, VidotClient } from './client'
export { injectAutoload } from './project'
export * from 'vitest'

interface GodotSession {
  client: VidotClient
  close: () => Promise<void>
}

const configuredTest = vitest.extend('vidotConfig', { scope: 'file' }, (): VidotContext => inject('vidot'))

export const test = configuredTest.extend('vidot', { scope: 'file' }, async ({ vidotConfig }, { onCleanup }) => {
  const { godotPath, projectPath, scene } = vidotConfig
  const godot = await startGodot(godotPath, projectPath, scene)
  onCleanup(godot.close)

  return godot.client
})

export const it = test

async function startGodot(
  godotPath: string,
  projectPath: string,
  scene: string | null,
): Promise<GodotSession> {
  projectPath = path.resolve(projectPath)
  if (!existsSync(godotPath))
    throw new Error(`Godot executable does not exist: ${godotPath}`)

  await assertAutoloadInjected(projectPath)

  const session = crypto.randomUUID()
  const sandbox = await createGodotProjectSandbox(projectPath, 'vidot', session)
  let subprocess: GodotProcess
  try {
    subprocess = execa(godotPath, [
      '--headless',
      '--path',
      sandbox.path,
      ...(scene === null ? [] : [scene]),
      '--',
      `--vidot-session=${session}`,
    ], {
      forceKillAfterDelay: 1000,
      reject: false,
    })
  }
  catch (error) {
    return rethrowAfterCleanup(error, () => cleanupGodotProjectSandbox(sandbox))
  }
  let client: VidotClient
  try {
    const port = await waitForReady(subprocess, session, sandbox.userDataDir, startupTimeoutMs)
    client = await VidotClient.connect(`ws://127.0.0.1:${port}`, startupTimeoutMs)
    await client.initialize(session)
  }
  catch (error) {
    return rethrowAfterCleanup(error, () => stopGodot(subprocess, sandbox))
  }

  let closed = false

  return {
    client,
    async close() {
      if (closed)
        return

      closed = true
      try {
        client.close()
      }
      finally {
        await stopGodot(subprocess, sandbox)
      }
    },
  }
}

type GodotProcess = ResultPromise<{ forceKillAfterDelay: number, reject: false }>

async function rethrowAfterCleanup(error: unknown, cleanup: () => Promise<void>): Promise<never> {
  try {
    await cleanup()
  }
  catch (cleanupError) {
    throw new AggregateError([error, cleanupError], 'ViDot failed and could not clean up its Godot process')
  }

  throw error
}

async function stopGodot(
  subprocess: GodotProcess,
  sandbox: GodotProjectSandbox,
): Promise<void> {
  const errors: unknown[] = []
  try {
    subprocess.kill()
    await subprocess
  }
  catch (error) {
    errors.push(error)
  }

  try {
    await cleanupGodotProjectSandbox(sandbox)
  }
  catch (error) {
    errors.push(error)
  }

  if (errors.length > 0)
    throw new AggregateError(errors, 'ViDot could not stop Godot or remove its sandbox')
}

async function waitForReady(
  subprocess: GodotProcess,
  session: string,
  expectedUserDataDir: string,
  timeoutMs: number,
): Promise<number> {
  const { nodeChildProcess, stderr, stdout } = subprocess
  const prefix = `VIDOT_READY ${session} `

  return new Promise((resolve, reject) => {
    let buffer = ''
    let diagnostics = ''
    const timeout = setTimeout(() => {
      cleanup()
      reject(new Error(`Godot did not start ViDot within ${timeoutMs}ms\n${diagnostics.trim()}`))
    }, timeoutMs)
    function onStdout(chunk: Buffer) {
      const text = chunk.toString()
      buffer += text
      diagnostics = `${diagnostics}${text}`.slice(-8192)
      for (const line of buffer.split(/\r?\n/)) {
        const marker = line.indexOf(prefix)
        if (marker < 0)
          continue

        const ready = line.slice(marker + prefix.length).match(/^(\d+) (".*")$/)
        cleanup()
        if (!ready) {
          reject(new Error(`ViDot reported an invalid port: ${line}`))

          return
        }

        const port = Number.parseInt(ready[1], 10)
        let userDataDir: unknown
        try {
          userDataDir = JSON.parse(ready[2])
        }
        catch {
          reject(new Error(`ViDot reported an invalid user-data directory: ${line}`))

          return
        }
        if (!Number.isInteger(port) || port <= 0 || userDataDir !== expectedUserDataDir) {
          reject(new Error(`ViDot reported an unexpected sandbox: ${line}`))

          return
        }

        resolve(port)

        return
      }
      buffer = buffer.slice(-4096)
    }
    function onStderr(chunk: Buffer) {
      diagnostics = `${diagnostics}${chunk.toString()}`.slice(-8192)
    }
    function onExit(exitCode: number | null) {
      cleanup()
      reject(new Error(`Godot exited before ViDot became ready (exit ${exitCode ?? 'unknown'})\n${diagnostics.trim()}`))
    }
    function cleanup() {
      clearTimeout(timeout)
      stdout.off('data', onStdout)
      stderr.off('data', onStderr)
      nodeChildProcess.off('close', onExit)
    }
    stdout.on('data', onStdout)
    stderr.on('data', onStderr)
    nodeChildProcess.once('close', onExit)
  })
}
