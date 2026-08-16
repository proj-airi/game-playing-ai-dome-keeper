import type { PoolRunnerInitializer } from 'vitest/node'

import type { ResolvedViDotOptions, ViDotOptions } from './types.ts'
import { resolve } from 'node:path'
import process from 'node:process'
import { fileURLToPath } from 'node:url'
import { ViDotPoolWorker } from './pool.ts'

export type { ViDotOptions } from './types.ts'

export function vidot(options: ViDotOptions): PoolRunnerInitializer {
  const resolved: ResolvedViDotOptions = {
    projectPath: resolve(options.projectPath),
    godotPath: options.godotPath ?? process.env.GODOT_BIN ?? 'godot',
    runnerPath: fileURLToPath(new URL('../runtime/runner.gd', import.meta.url)),
  }

  return {
    name: 'vidot',
    createPoolWorker: () => new ViDotPoolWorker(resolved),
  }
}
