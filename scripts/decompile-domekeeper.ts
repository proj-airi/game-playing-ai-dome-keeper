#!/usr/bin/env bun
import { existsSync, mkdirSync, readdirSync, statSync } from 'node:fs'
import path from 'node:path'
import process from 'node:process'
import { x } from 'tinyexec'

const env = import.meta.env
const gameDir = env.DOMEKEEPER_GAME_DIR
const godotBin = env.GODOT_BIN
const gdreToolsBin = env.GDRETOOLS_BIN
const version = env.DOMEKEEPER_VERSION
const repoRoot = path.resolve(import.meta.dir, '..')
const outRoot = env.DOMEKEEPER_OUT_ROOT ?? path.join(repoRoot, 'external/domekeeper-decompiled')

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
if (!godotBin) {
  console.error('Missing GODOT_BIN. Provide the path to the Godot binary used for decompilation.')
  process.exit(1)
}
if (!existsSync(godotBin)) {
  console.error(`Godot binary not found: ${godotBin}`)
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
  await x(gdreToolsBin, ['--headless', `--recover=${pckPath}`, `--output=${outDir}`], {
    nodeOptions: { stdio: 'inherit' },
  })
  console.log('GDRETools recovery complete.')
}
catch (error) {
  console.error('GDRETools failed. Check the output above and verify tool versions.')
  console.error(error)
  process.exit(1)
}

const modsRoot = path.join(repoRoot, 'mods')
if (existsSync(modsRoot)) {
  const modsUnpackedDir = path.join(outDir, 'mods-unpacked')
  mkdirSync(modsUnpackedDir, { recursive: true })

  const modEntries = readdirSync(modsRoot)
    .map(entry => path.join(modsRoot, entry))
    .filter(entryPath => statSync(entryPath).isDirectory())

  for (const modPath of modEntries) {
    const modName = path.basename(modPath)
    const modTarget = path.join(modsUnpackedDir, modName)

    if (existsSync(modTarget)) {
      console.warn(`Mod target already exists: ${modTarget}. Skipping link step.`)
      continue
    }

    try {
      await x('ln', ['-s', modPath, modTarget], { nodeOptions: { stdio: 'inherit' } })
      console.log(`Linked mod source to ${modTarget}`)
    }
    catch (error) {
      console.error(`Failed to link mod source for ${modName}. You may need to link manually.`)
      console.error(error)
    }
  }
}
else {
  console.warn(`Mods directory not found at ${modsRoot}. Skipping link step.`)
}
