import type { ProvidedContext } from 'vitest'
import type { TestProject } from 'vitest/node'
import type { GodotSandboxFile } from './sandbox'
import path from 'node:path'
import process from 'node:process'

export interface VidotContext {
  godotPath: string
  movie: string | null
  projectPath: string
  sandboxFiles: GodotSandboxFile[]
  scene: string | null
}

export interface VidotOptions {
  movie?: string
  sandboxFiles?: Record<string, string>
  scene?: string
}

declare module 'vitest' {
  export interface ProvidedContext {
    vidot: VidotContext
  }
}

export function setupViDot(projectPath: string, options: VidotOptions = {}) {
  projectPath = path.resolve(projectPath)
  const movie = options.movie == null ? null : path.resolve(options.movie)
  const sandboxFiles = normalizeSandboxFiles(options.sandboxFiles)
  const scene = normalizeScene(options.scene)

  return async (project: TestProject) => {
    const godotPath = process.env.GODOT_BIN
    if (!godotPath)
      throw new Error('GODOT_BIN must be provided by mise')

    const context: ProvidedContext['vidot'] = {
      godotPath,
      movie,
      projectPath,
      sandboxFiles,
      scene,
    }
    project.provide('vidot', context)
  }
}

function normalizeSandboxFiles(files: Record<string, string> | undefined): GodotSandboxFile[] {
  return Object.entries(files ?? {}).map(([target, source]) => {
    if (!target.startsWith('res://'))
      throw new Error(`ViDot sandbox file targets must use res:// paths: ${target}`)

    const relativeTarget = target.slice('res://'.length)
    if (relativeTarget === '' || path.posix.isAbsolute(relativeTarget) || relativeTarget.includes('\\') || relativeTarget.split('/').includes('..'))
      throw new Error(`ViDot sandbox file target escapes the project: ${target}`)

    return {
      source: path.resolve(source),
      target: relativeTarget,
    }
  })
}

function normalizeScene(scene: string | undefined): string | null {
  if (scene === undefined)
    return null

  if (!scene.startsWith('res://') || !scene.endsWith('.tscn'))
    throw new Error('ViDot scene must be a res:// path to a .tscn file')

  return scene
}
