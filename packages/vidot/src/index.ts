import type { ResultPromise } from 'execa'
import type { Buffer } from 'node:buffer'
import type { VidotContext } from './setup'
import { existsSync } from 'node:fs'
import path from 'node:path'
import { execa } from 'execa'
import { inject, test as vitest } from 'vitest'
import { VidotClient } from './client'
import { assertAutoloadInjected } from './project'

const startupTimeoutMs = 30_000

export { type JsonValue, VidotClient } from './client'
export { injectAutoload } from './project'
export * from 'vitest'

const configuredTest = vitest.extend('vidotConfig', { scope: 'file' }, (): VidotContext => inject('vidot'))

export const test = configuredTest.extend('vidot', { scope: 'file' }, async ({ vidotConfig }, { onCleanup }) => {
  const { godotPath, projectPath } = vidotConfig
  const godot = await startGodot(godotPath, projectPath)
  onCleanup(godot.close)

  return godot.client
})

export const it = test

async function startGodot(godotPath: string, projectPath: string) {
  projectPath = path.resolve(projectPath)
  if (!existsSync(godotPath))
    throw new Error(`Godot executable does not exist: ${godotPath}`)

  await assertAutoloadInjected(projectPath)

  const session = crypto.randomUUID()
  const subprocess = execa(godotPath, [
    '--headless',
    '--path',
    projectPath,
    '--',
    `--vidot-session=${session}`,
  ], {
    forceKillAfterDelay: 1000,
    reject: false,
  })
  let client: VidotClient
  try {
    const port = await waitForReady(subprocess, session, startupTimeoutMs)
    client = await VidotClient.connect(`ws://127.0.0.1:${port}`, startupTimeoutMs)
    await client.initialize(session)
  }
  catch (error) {
    subprocess.kill()
    await subprocess
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
      subprocess.kill()
      await subprocess
    },
  }
}

type GodotProcess = ResultPromise<{ forceKillAfterDelay: number, reject: false }>

async function waitForReady(subprocess: GodotProcess, session: string, timeoutMs: number): Promise<number> {
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
