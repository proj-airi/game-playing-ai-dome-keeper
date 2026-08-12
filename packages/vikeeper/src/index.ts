import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { defineConfig } from 'vitest/config'

export interface ViKeeperContext {
  modPath: string
  movie: string | null
  projectsPath: string
}

export interface ViKeeperOptions {
  modPath: string
  movie?: string
  projectsPath: string
  root: string
}

declare module 'vitest' {
  export interface ProvidedContext {
    vikeeper: ViKeeperContext
  }
}

export function setupViKeeper(options: ViKeeperOptions) {
  return defineConfig({
    root: path.resolve(options.root),
    test: {
      fileParallelism: false,
      globalSetup: fileURLToPath(new URL('./global-setup.ts', import.meta.url)),
      hookTimeout: 90_000,
      provide: {
        vikeeper: {
          modPath: path.resolve(options.modPath),
          movie: options.movie == null ? null : path.resolve(options.movie),
          projectsPath: path.resolve(options.projectsPath),
        },
      },
      testTimeout: 90_000,
    },
  })
}
