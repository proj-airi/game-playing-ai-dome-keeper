import type { TestProject } from 'vitest/node'
import path from 'node:path'
import process from 'node:process'
import { injectAutoload } from './project'

export interface VidotContext {
  godotPath: string
  projectPath: string
}

declare module 'vitest' {
  export interface ProvidedContext {
    vidot: VidotContext
  }
}

export function setupViDot(projectPath: string) {
  projectPath = path.resolve(projectPath)

  return async (project: TestProject) => {
    const godotPath = process.env.GODOT_BIN
    if (!godotPath)
      throw new Error('GODOT_BIN must be provided by mise')

    project.provide('vidot', { godotPath, projectPath })

    return injectAutoload(projectPath)
  }
}
