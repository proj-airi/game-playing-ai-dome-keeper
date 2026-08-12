import type { ResultPromise } from 'execa'
import type { Buffer } from 'node:buffer'
import type { GodotProjectSandbox } from './sandbox'
import type { VidotContext } from './setup'
import { existsSync } from 'node:fs'
import { mkdir, rm, stat } from 'node:fs/promises'
import path from 'node:path'
import { execa } from 'execa'
import { inject, test as vitest } from 'vitest'
import { VidotClient } from './client'
import { installAutoload } from './project'
import { cleanupGodotProjectSandbox, createGodotProjectSandbox } from './sandbox'

const startupTimeoutMs = 30_000
const shutdownTimeoutMs = 5_000
const lineBreakPattern = /\r?\n/
const readyMessagePattern = /^(\d+) (".*")$/

export { type JsonValue, VidotClient } from './client'
export * from 'vitest'

interface GodotSession {
  client: VidotClient
  close: () => Promise<void>
}

const configuredTest = vitest.extend('vidotConfig', { scope: 'file' }, (): VidotContext => inject('vidot'))

export const test = configuredTest.extend('vidot', { scope: 'file' }, async ({ vidotConfig }, { onCleanup }) => {
  const godot = await startGodot(vidotConfig)
  onCleanup(godot.close)

  return godot.client
})

export const it = test

async function startGodot(context: VidotContext): Promise<GodotSession> {
  const { godotPath, movie, sandboxFiles, scene } = context
  const projectPath = path.resolve(context.projectPath)
  if (!existsSync(godotPath))
    throw new Error(`Godot executable does not exist: ${godotPath}`)

  const session = crypto.randomUUID()
  const sandbox = await createGodotProjectSandbox(projectPath, 'vidot', sandboxFiles)

  let subprocess: GodotProcess
  try {
    await installAutoload(sandbox.path)
    if (movie !== null) {
      await mkdir(path.dirname(movie), { recursive: true })
      await rm(movie, { force: true })
    }

    subprocess = execa(godotPath, [
      '--path',
      sandbox.path,
      ...(movie === null
        ? ['--headless']
        : [
            '--render-thread',
            'safe',
            '--disable-vsync',
            '--windowed',
            '--resolution',
            '960x540',
            '--write-movie',
            movie,
            '--fixed-fps',
            '30',
          ]),
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
        await stopGodot(subprocess, sandbox, true)
      }
      if (movie !== null && (await stat(movie)).size === 0)
        throw new Error(`Godot wrote an empty movie: ${movie}`)
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
      const lines = buffer.split(lineBreakPattern)
      buffer = lines.pop() ?? ''
      for (const line of lines) {
        const marker = line.indexOf(prefix)
        if (marker < 0)
          continue

        const ready = line.slice(marker + prefix.length).match(readyMessagePattern)
        cleanup()
        if (!ready) {
          reject(new Error(`ViDot reported an invalid sandbox: ${line}`))

          return
        }

        const port = Number.parseInt(ready[1], 10)
        let userDataDir: unknown
        try {
          userDataDir = JSON.parse(ready[2])
        }
        catch {
          reject(new Error(`ViDot reported an invalid sandbox: ${line}`))

          return
        }
        const usesExpectedUserData = typeof userDataDir === 'string'
          && path.resolve(userDataDir) === path.resolve(expectedUserDataDir)
        if (!Number.isInteger(port) || port <= 0 || !usesExpectedUserData) {
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

async function stopGodot(
  subprocess: GodotProcess,
  sandbox: GodotProjectSandbox,
  waitForGracefulExit = false,
): Promise<void> {
  const errors: unknown[] = []
  try {
    const exited = waitForGracefulExit && await exitsWithin(subprocess, shutdownTimeoutMs)
    if (exited) {
      const result = await subprocess
      if (result.failed) {
        const diagnostics = `${result.stdout}\n${result.stderr}`.trim().slice(-8192)
        errors.push(new Error(`Godot exited abnormally with exit code ${result.exitCode ?? 'unknown'}${diagnostics === '' ? '' : `\n${diagnostics}`}`))
      }
    }
    else {
      subprocess.kill()
      await subprocess
      if (waitForGracefulExit)
        errors.push(new Error(`Godot did not exit normally within ${shutdownTimeoutMs}ms`))
    }
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

function exitsWithin(subprocess: GodotProcess, timeoutMs: number): Promise<boolean> {
  return new Promise((resolve) => {
    const timeout = setTimeout(resolve, timeoutMs, false)
    const exited = () => {
      clearTimeout(timeout)
      resolve(true)
    }
    subprocess.then(exited, exited)
  })
}
