import type { Buffer } from 'node:buffer'
import type { Result } from 'tinyexec'
import type { VidotContext } from './setup'
import { existsSync } from 'node:fs'
import path from 'node:path'
import { x } from 'tinyexec'
import { inject, test as vitest } from 'vitest'
import { VidotClient } from './client'
import { assertAutoloadInjected } from './project'

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
  const { godotPath, projectPath } = vidotConfig
  const godot = await startGodot(godotPath, projectPath)
  onCleanup(godot.close)

  return godot.client
})

export const it = test

async function startGodot(godotPath: string, projectPath: string): Promise<GodotSession> {
  projectPath = path.resolve(projectPath)
  if (!existsSync(godotPath))
    throw new Error(`Godot executable does not exist: ${godotPath}`)

  await assertAutoloadInjected(projectPath)

  const session = crypto.randomUUID()
  const result = x(godotPath, [
    '--headless',
    '--path',
    projectPath,
    '--',
    `--vidot-session=${session}`,
  ], { throwOnError: false })
  let client: VidotClient
  try {
    const port = await waitForReady(result, session, startupTimeoutMs)
    client = await VidotClient.connect(`ws://127.0.0.1:${port}`, startupTimeoutMs)
    await client.initialize(session)
  }
  catch (error) {
    await stopProcess(result)
    throw error
  }

  let closed = false

  return {
    client,
    async close() {
      if (closed)
        return

      closed = true
      client.close()
      await stopProcess(result)
    },
  }
}

async function waitForReady(result: Result, session: string, timeoutMs: number): Promise<number> {
  const child = result.process
  if (!child)
    throw new Error('Godot process is unavailable')

  const stdout = child.stdout
  if (!stdout)
    throw new Error('Godot stdout is unavailable')

  const childProcess: NonNullable<typeof result.process> = child
  const stdoutStream: NonNullable<typeof child.stdout> = stdout
  const stderr = childProcess.stderr
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

        const port = Number.parseInt(line.slice(marker + prefix.length), 10)
        cleanup()
        if (!Number.isInteger(port) || port <= 0) {
          reject(new Error(`ViDot reported an invalid port: ${line}`))

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
    function onExit() {
      cleanup()
      reject(new Error(`Godot exited before ViDot became ready (exit ${result.exitCode ?? 'unknown'})\n${diagnostics.trim()}`))
    }
    function cleanup() {
      clearTimeout(timeout)
      stdoutStream.off('data', onStdout)
      stderr?.off('data', onStderr)
      childProcess.off('close', onExit)
    }
    stdoutStream.on('data', onStdout)
    stderr?.on('data', onStderr)
    childProcess.once('close', onExit)
  })
}

async function stopProcess(result: Result): Promise<void> {
  if (result.exitCode !== undefined) {
    await result

    return
  }

  result.kill('SIGTERM')
  if (!await exitsWithin(result, 1000)) {
    result.kill('SIGKILL')
    await result
  }
}

function exitsWithin(result: Result, timeoutMs: number): Promise<boolean> {
  return Promise.race([
    Promise.resolve(result).then(() => true, () => true),
    new Promise<false>(resolve => setTimeout(() => resolve(false), timeoutMs)),
  ])
}
