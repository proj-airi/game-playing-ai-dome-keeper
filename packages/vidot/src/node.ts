import type { PoolRunnerInitializer } from 'vitest/node'

import type { ViDotOptions } from './types.ts'
import { resolve } from 'node:path'
import process from 'node:process'
import { fileURLToPath } from 'node:url'
import { ViDotPoolWorker } from './pool.ts'

export type {
  ViDotLaunch,
  ViDotLaunchContext,
  ViDotLaunchOptions,
  ViDotOptions,
} from './types.ts'

export function vidot(options: ViDotOptions): PoolRunnerInitializer {
  const resolved = {
    projectPath: resolve(options.projectPath),
    godotPath: options.godotPath ?? process.env.GODOT_BIN ?? 'godot',
    runnerPath: fileURLToPath(new URL('../runtime/runner.gd', import.meta.url)),
    launch: options.launch ?? (() => ({ args: ['--headless'] })),
  }

  return {
    name: 'vidot',
    createPoolWorker: () => new ViDotPoolWorker(resolved),
  }
}
