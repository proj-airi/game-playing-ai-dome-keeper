#!/usr/bin/env bun
import { existsSync, lstatSync } from 'node:fs'
import path from 'node:path'
import process from 'node:process'
import { execa } from 'execa'
import { cleanupGodotProjectSandbox, createGodotProjectSandbox } from '../packages/vidot/src/sandbox'

const godot = import.meta.env.GODOT_BIN
const version = import.meta.env.DOMEKEEPER_VERSION
if (!godot || !version)
  fail('GODOT_BIN and DOMEKEEPER_VERSION must be provided by mise')

const project = path.resolve(import.meta.dir, '..', 'external', 'domekeeper-decompiled', version)
if (!existsSync(godot))
  fail(`Godot binary does not exist: ${godot}`)
if (!existsSync(path.join(project, 'project.godot')))
  fail(`Decompiled project does not exist: ${project}`)
if (lstatSync(path.join(project, 'mods-unpacked', 'LemonNekoGH-YoloDataCollector'), { throwIfNoEntry: false }) !== undefined)
  fail('The legacy YOLO collector Mod is still installed; run mise run decompile to remove its repository link before starting Godot')

const sandbox = await createGodotProjectSandbox(project, 'airi-domekeeper-godot-check')
let failure: string | null = null

try {
  const result = await execa(godot, [
    '--headless',
    '--path',
    sandbox.path,
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
  const dataCollectorAIReady = output.includes('DATA_COLLECTOR_AI_READY')
  const legacyModLoaded = output.includes('LemonNekoGH-YoloDataCollector')

  if (modErrors.length > 0)
    console.error(modErrors.join('\n'))
  if (!dataCollectorAIReady)
    console.error('DataCollectorAI did not enter the scene tree; its generated runtime may be missing or invalid.')
  if (legacyModLoaded)
    console.error('The legacy YOLO collector Mod is disabled but was still discovered by Mod Loader.')
  if (result.failed || modErrors.length > 0 || !dataCollectorAIReady || legacyModLoaded)
    failure = `Godot mod check failed with exit code ${result.exitCode ?? 'unknown'}`
}
finally {
  await cleanupGodotProjectSandbox(sandbox)
}

if (failure)
  fail(failure)

console.log('Godot mod check passed: DataCollectorAI loaded and the legacy YOLO collector stayed disabled.')

function findModErrors(output: string): string[] {
  const modPath = 'res://mods-unpacked/LemonNekoGH-DataCollectorAI'
  const lines = output.split('\n')
  const errors: string[] = []

  for (let index = 0; index < lines.length; index += 1) {
    if (lines[index].includes('Failed to load script')) {
      const block = lines.slice(index, index + 2)
      if (block.some(line => line.includes(modPath)))
        errors.push(block.join('\n'))
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
