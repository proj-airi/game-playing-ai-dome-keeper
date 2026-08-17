import type { PoolRunnerInitializer } from 'vitest/node'

import { existsSync } from 'node:fs'
import { mkdir, rm, stat } from 'node:fs/promises'
import path from 'node:path'
import { vidot } from '@vidot/vitest'

export interface ViKeeperOptions {
  projectPath: string
  testRoot: string
  godotPath?: string
  movie?: string
}

export function vikeeper(options: ViKeeperOptions): PoolRunnerInitializer {
  const projectPath = path.resolve(options.projectPath)
  const testRoot = path.resolve(options.testRoot)
  const movie = options.movie === undefined ? undefined : path.resolve(options.movie)

  if (!existsSync(path.join(projectPath, 'project.godot')))
    throw new Error(`Dome Keeper project does not exist: ${projectPath}`)
  if (!existsSync(testRoot))
    throw new Error(`Mod test root does not exist: ${testRoot}`)

  return vidot({
    projectPath,
    godotPath: options.godotPath,
    launch: ({ method }) => {
      const env = { VIKEEPER_TEST_ROOT: testRoot }
      if (method === 'collect' || movie === undefined)
        return { args: ['--headless'], env }

      return {
        args: [
          '--render-thread',
          'safe',
          '--disable-vsync',
          '--windowed',
          '--resolution',
          '960x540',
          '--write-movie',
          movie,
          '--fixed-fps',
          '30',
        ],
        env,
        before: async () => {
          await mkdir(path.dirname(movie), { recursive: true })
          await rm(movie, { force: true })
        },
        after: async () => {
          if ((await stat(movie)).size === 0)
            throw new Error(`Godot wrote an empty movie: ${movie}`)
        },
      }
    },
  })
}
