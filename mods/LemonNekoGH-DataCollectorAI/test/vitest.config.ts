import path from 'node:path'
import process from 'node:process'
import { vikeeper } from '@vikeeper/vitest'
import { defineConfig } from 'vitest/config'

const version = process.env.DOMEKEEPER_VERSION
if (!version)
  throw new Error('DOMEKEEPER_VERSION must be provided by mise')

const repoRoot = path.resolve(import.meta.dirname, '../../..')

export default defineConfig({
  root: import.meta.dirname,
  test: {
    fileParallelism: false,
    include: ['**/*.test.ts'],
    isolate: false,
    pool: vikeeper({
      projectPath: path.join(repoRoot, 'external', 'domekeeper-decompiled', version),
      testRoot: import.meta.dirname,
      movie: process.env.VIDOT_MOVIE,
    }),
  },
})
