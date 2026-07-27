#!/usr/bin/env bun
import { existsSync } from 'node:fs'
import { mkdir } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import path from 'node:path'
import process from 'node:process'
import { x } from 'tinyexec'

const args = process.argv.slice(2)
const fps = args.length ? Number(args[1]) : 30
if ((args.length && (args.length !== 2 || args[0] !== '--fps')) || !Number.isInteger(fps) || fps <= 0)
  fail('Usage: mise run godot:record -- --fps <positive integer>')
const godot = import.meta.env.GODOT_BIN
const version = import.meta.env.DOMEKEEPER_VERSION
if (!godot || !version)
  fail('GODOT_BIN and DOMEKEEPER_VERSION must be provided by mise')
const project = path.resolve(import.meta.dir, '..', 'external', 'domekeeper-decompiled', version)

if (!existsSync(godot))
  fail(`Godot binary does not exist: ${godot}`)
if (!existsSync(path.join(project, 'project.godot')))
  fail(`Decompiled project does not exist: ${project}`)
const sessionDir = path.join(tmpdir(), 'airi-dome-keeper-replays', `session_${crypto.randomUUID()}`)
const avi = path.join(sessionDir, 'recording.avi')
const mp4 = path.join(sessionDir, 'recording.mp4')
const replay = path.join(sessionDir, 'recording.json')

await mkdir(sessionDir, { recursive: true })
console.log(`Recording to ${sessionDir}`)
await run(godot, [
  '--path',
  project,
  '--render-thread',
  'safe',
  '--write-movie',
  avi,
  '--fixed-fps',
  String(fps),
  '--',
  `--airi-recording-dir=${sessionDir}`,
  `--airi-recording-fps=${fps}`,
], 'Godot recording failed; the incomplete session was kept')

if (!existsSync(replay))
  fail(`No replay JSON was written. Start teacher collection during the run. Movie output: ${avi}`)

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
], 'FFmpeg conversion failed; the AVI and replay JSON were kept')

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

function fail(message: string): never {
  console.error(message)
  process.exit(1)
}
