#!/usr/bin/env bun
import { existsSync } from 'node:fs'
import { mkdtemp, rm } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import path from 'node:path'
import process from 'node:process'
import { execa } from 'execa'

const godot = import.meta.env.GODOT_BIN
const version = import.meta.env.DOMEKEEPER_VERSION
if (!godot || !version)
  fail('GODOT_BIN and DOMEKEEPER_VERSION must be provided by mise')

const project = path.resolve(import.meta.dir, '..', 'external', 'domekeeper-decompiled', version)
if (!existsSync(godot))
  fail(`Godot binary does not exist: ${godot}`)
if (!existsSync(path.join(project, 'project.godot')))
  fail(`Decompiled project does not exist: ${project}`)

const userDataDir = await mkdtemp(path.join(tmpdir(), 'airi-domekeeper-godot-check-'))
let failure: string | null = null

try {
  const result = await execa(godot, [
    '--headless',
    '--path',
    project,
    '--user-data-dir',
    userDataDir,
    '--quit-after',
    '5',
    'res://addons/mod_loader/restart_notification.tscn',
  ], {
    all: true,
    reject: false,
    timeout: 60_000,
  })
  const output = result.all
  const modErrors = findModErrors(output)
  const collectorReady = output.includes('Collector entered tree. Inside: true')

  if (modErrors.length > 0)
    console.error(modErrors.join('\n'))
  if (!collectorReady)
    console.error('The YOLO collector did not enter the scene tree; a mod script may have failed to load.')
  if (result.failed || modErrors.length > 0 || !collectorReady)
    failure = `Godot mod check failed with exit code ${result.exitCode ?? 'unknown'}`
  else
    console.log('Godot mod check passed: the YOLO collector entered the scene tree.')
}
finally {
  await rm(userDataDir, { force: true, recursive: true })
}

if (failure)
  fail(failure)

function findModErrors(output: string): string[] {
  const modPath = 'res://mods-unpacked/LemonNekoGH-YoloDataCollector'
  const lines = output.split('\n')
  const errors: string[] = []

  for (let index = 0; index < lines.length; index += 1) {
    if (lines[index].includes('Failed to load script')) {
      if (lines[index].includes(modPath))
        errors.push(lines.slice(index, index + 2).join('\n'))
      continue
    }
    if (!lines[index].includes('SCRIPT ERROR:'))
      continue
    const block = lines.slice(index, index + 4)
    if (block.some(line => line.includes(modPath)))
      errors.push(block.join('\n'))
  }

  return errors
}

function fail(message: string): never {
  console.error(message)
  process.exit(1)
}
