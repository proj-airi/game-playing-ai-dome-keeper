#!/usr/bin/env bun
import { existsSync, lstatSync, mkdirSync, readdirSync, readlinkSync, statSync, symlinkSync, unlinkSync } from 'node:fs'
import path from 'node:path'
import process from 'node:process'
import { execa } from 'execa'

const env = import.meta.env
const gameDir = env.DOMEKEEPER_GAME_DIR
const gdreToolsBin = env.GDRETOOLS_BIN
const version = env.DOMEKEEPER_VERSION
const repoRoot = path.resolve(import.meta.dir, '..')
const outRoot = env.DOMEKEEPER_OUT_ROOT ?? path.join(repoRoot, 'external/domekeeper-decompiled')
const run = execa({ stdio: 'inherit' })
const activeModName = 'LemonNekoGH-DataCollectorAI'
const disabledModName = 'LemonNekoGH-YoloDataCollector'

if (!gameDir) {
  console.error('Missing DOMEKEEPER_GAME_DIR. Provide the game install directory.')
  process.exit(1)
}
if (!version) {
  console.error('Missing DOMEKEEPER_VERSION. Provide the game version tag for output isolation.')
  process.exit(1)
}
if (!existsSync(gameDir)) {
  console.error(`Game directory does not exist: ${gameDir}`)
  process.exit(1)
}
if (!gdreToolsBin) {
  console.error('Missing GDRETOOLS_BIN. Provide the path to the gdre_tools binary.')
  process.exit(1)
}
if (!existsSync(gdreToolsBin)) {
  console.error(`GDRETools binary not found: ${gdreToolsBin}`)
  process.exit(1)
}

const pckCandidates = readdirSync(gameDir)
  .filter(f => f.toLowerCase().endsWith('.pck'))
  .map(f => path.join(gameDir, f))
  .filter(p => statSync(p).isFile())

if (pckCandidates.length === 0) {
  console.error('No .pck file found in the game directory. Provide the correct install path.')
  process.exit(1)
}
if (pckCandidates.length > 1) {
  console.warn('Multiple .pck files found. Using the first one:')
}
const pckPath = pckCandidates[0]

const outDir = path.join(outRoot, version)
mkdirSync(outDir, { recursive: true })

console.log('\nRunning GDRETools to recover project...')
try {
  await run(gdreToolsBin, ['--headless', `--recover=${pckPath}`, `--output=${outDir}`])
  console.log('GDRETools recovery complete.')
}
catch (error) {
  console.error('GDRETools failed. Check the output above and verify tool versions.')
  console.error(error)
  process.exit(1)
}

console.log('\nGenerating TypeScript declarations for the decompiled game...')
try {
  await run('bun', ['run', path.join(repoRoot, 'scripts/generate-domekeeper-typings.ts'), outDir])
}
catch (error) {
  console.error('Failed to generate TypeScript declarations.')
  console.error(error)
  process.exit(1)
}

const modsRoot = path.join(repoRoot, 'mods')
if (existsSync(modsRoot)) {
  const modsUnpackedDir = path.join(outDir, 'mods-unpacked')
  mkdirSync(modsUnpackedDir, { recursive: true })

  const disabledModTarget = path.join(modsUnpackedDir, disabledModName)
  const disabledModTargetStat = lstatSync(disabledModTarget, { throwIfNoEntry: false })
  if (disabledModTargetStat !== undefined) {
    if (!disabledModTargetStat.isSymbolicLink()) {
      console.error(`Disabled Mod target is not a repository-owned symbolic link: ${disabledModTarget}`)
      console.error('Remove or relocate that exact target before running decompile again.')
      process.exit(1)
    }

    const disabledModSource = path.join(modsRoot, disabledModName)
    const targetMatches = path.resolve(path.dirname(disabledModTarget), readlinkSync(disabledModTarget)) === disabledModSource
    if (!targetMatches) {
      console.error(`Disabled Mod target has an unexpected source: ${disabledModTarget}`)
      console.error('Remove or relocate that exact target before running decompile again.')
      process.exit(1)
    }
    unlinkSync(disabledModTarget)
    console.log(`Disabled legacy Mod by removing its repository link: ${disabledModTarget}`)
  }

  const activeModSource = path.join(modsRoot, activeModName, 'scripts')
  if (!statSync(activeModSource).isDirectory()) {
    console.error(`Active Mod source is not a directory: ${activeModSource}`)
    process.exit(1)
  }

  const activeModTarget = path.join(modsUnpackedDir, activeModName)
  const activeModTargetStat = lstatSync(activeModTarget, { throwIfNoEntry: false })
  if (activeModTargetStat !== undefined) {
    const targetMatches = activeModTargetStat.isSymbolicLink()
      && path.resolve(path.dirname(activeModTarget), readlinkSync(activeModTarget)) === activeModSource
    if (targetMatches) {
      console.log(`Mod source is already linked to ${activeModTarget}`)
    }
    else {
      console.error(`Mod target already exists with an unexpected source: ${activeModTarget}`)
      console.error('Remove or relocate that exact target before running decompile again.')
      process.exit(1)
    }
  }
  else {
    try {
      symlinkSync(activeModSource, activeModTarget, 'junction')
      console.log(`Linked mod source to ${activeModTarget}`)
    }
    catch (error) {
      console.error(`Failed to link mod source for ${activeModName}.`)
      console.error(error)
      process.exit(1)
    }
  }
}
else {
  console.warn(`Mods directory not found at ${modsRoot}. Skipping link step.`)
}
