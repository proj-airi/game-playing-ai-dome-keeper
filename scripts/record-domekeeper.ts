#!/usr/bin/env bun
import { createReadStream, existsSync } from 'node:fs'
import { mkdir } from 'node:fs/promises'
import path from 'node:path'
import process from 'node:process'
import { createInterface } from 'node:readline'
import { parseArgs } from 'node:util'
import { customAlphabet } from 'nanoid'
import { x } from 'tinyexec'

const nanoid = customAlphabet('0123456789abcdefghijklmnopqrstuvwxyz', 6)
const { values } = parseArgs({
  args: process.argv.slice(2),
  options: {
    fps: { type: 'string' },
    load: { type: 'string' },
    save: { type: 'boolean' },
    seed: { type: 'string' },
  },
  strict: true,
})
const fps = Number(values.fps ?? 10)
if (!Number.isInteger(fps) || fps <= 0)
  fail('--fps must be a positive integer')
const godot = import.meta.env.GODOT_BIN
const version = import.meta.env.DOMEKEEPER_VERSION
if (!godot || !version)
  fail('GODOT_BIN and DOMEKEEPER_VERSION must be provided by mise')
const project = path.resolve(import.meta.dir, '..', 'external', 'domekeeper-decompiled', version)
const recordingResolution = '1280x720'

if (!existsSync(godot))
  fail(`Godot binary does not exist: ${godot}`)
if (!existsSync(path.join(project, 'project.godot')))
  fail(`Decompiled project does not exist: ${project}`)
const timestamp = new Date().toISOString().slice(2, 19).replaceAll('-', '').replaceAll(':', '').replace('T', '_')
const sessionDir = path.join(process.cwd(), 'recordings', `session_${timestamp}_${nanoid()}`)
const sessionId = path.basename(sessionDir)
const avi = path.join(sessionDir, 'recording.avi')
const mp4 = path.join(sessionDir, 'recording.mp4')
const replay = path.join(sessionDir, 'recording.jsonl')

await mkdir(sessionDir, { recursive: true })
console.log(`Recording to ${sessionDir}`)
await run(godot, [
  '--path',
  project,
  '--render-thread',
  'safe',
  '--disable-vsync',
  '--windowed',
  '--resolution',
  recordingResolution,
  '--write-movie',
  avi,
  '--fixed-fps',
  String(fps),
  '--',
  `--airi-recording-dir=${sessionDir}`,
  `--airi-recording-fps=${fps}`,
  `--airi-checkpoint-session=${sessionId}`,
  ...(values.save ? ['--airi-checkpoint-save'] : []),
  ...(values.load == null ? [] : [`--airi-checkpoint-load=${values.load}`]),
  ...(values.seed == null ? [] : [`--airi-level-seed=${values.seed}`]),
], 'Godot recording failed; the incomplete session was kept')

if (!existsSync(replay))
  fail(`No replay JSONL was written. The incomplete movie was kept: ${avi}`)

await requireCompletedReplay(replay)

await run('ffmpeg', [
  '-i',
  avi,
  '-c:v',
  'libx264',
  '-pix_fmt',
  'yuv420p',
  '-c:a',
  'aac',
  mp4,
], 'FFmpeg conversion failed; the AVI and replay JSONL were kept')

console.log(`Replay ready: ${replay}`)

async function run(command: string, args: string[], failure: string): Promise<void> {
  try {
    await x(command, args, { nodeOptions: { stdio: 'inherit' } })
  }
  catch (error) {
    console.error(failure)
    console.error(error)
    process.exit(1)
  }
}

async function requireCompletedReplay(replayPath: string): Promise<void> {
  const lines = createInterface({ input: createReadStream(replayPath), crlfDelay: Infinity })
  let lineNumber = 0
  let finalEvent: { type?: string } | undefined
  for await (const line of lines) {
    lineNumber += 1
    try {
      finalEvent = JSON.parse(line)
    }
    catch (error) {
      console.error(error)
      fail(`Replay JSONL has malformed JSON on line ${lineNumber}; the incomplete session was kept: ${replayPath}`)
    }
  }
  if (lineNumber < 2 || finalEvent == null)
    fail(`Replay JSONL has no terminal event; the incomplete session was kept: ${replayPath}`)
  if (finalEvent.type !== 'run_won' && finalEvent.type !== 'run_lost')
    fail(`Replay JSONL has no terminal run outcome; the incomplete session was kept: ${replayPath}`)
}

function fail(message: string): never {
  console.error(message)
  process.exit(1)
}
