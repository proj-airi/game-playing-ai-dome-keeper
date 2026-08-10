import type { TestProject } from 'vitest/node'
import path from 'node:path'
import process from 'node:process'
import { injectAutoload } from './project'

export interface VidotContext {
  godotPath: string
  projectPath: string
  scene: string | null
}

export interface VidotOptions {
  scene?: string
}

declare module 'vitest' {
  export interface ProvidedContext {
    vidot: VidotContext
  }
}

export function setupViDot(projectPath: string, options: VidotOptions = {}) {
  projectPath = path.resolve(projectPath)
  const scene = normalizeScene(options.scene)

  return async (project: TestProject) => {
    const godotPath = process.env.GODOT_BIN
    if (!godotPath)
      throw new Error('GODOT_BIN must be provided by mise')

    project.provide('vidot', {
      godotPath,
      projectPath,
      scene,
    })

    return injectAutoload(projectPath)
  }
}

function normalizeScene(scene: string | undefined): string | null {
  if (scene === undefined)
    return null

  if (!scene.startsWith('res://') || !scene.endsWith('.tscn'))
    throw new Error('ViDot scene must be a res:// path to a .tscn file')

  return scene
}
