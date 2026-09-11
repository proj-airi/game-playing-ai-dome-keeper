import path from 'node:path'
import process from 'node:process'
import { vikeeper } from '@vikeeper/vitest'
import { defineConfig } from 'vitest/config'

const version = process.env.DOMEKEEPER_VERSION
if (!version)
  throw new Error('DOMEKEEPER_VERSION must be provided by mise')

const repoRoot = path.resolve(import.meta.dirname, '../../..')
const collection = process.env.LOWER_V0_DATASET_DIR !== undefined
if (collection)
  process.env.VIDOT_MOVIE ??= path.join(repoRoot, 'recordings/lower-v0.avi')
if (collection && !/^[1-9]\d*$/.test(process.env.LOWER_V0_COUNT ?? ''))
  throw new Error('LOWER_V0_COUNT must be a positive integer')
if (collection && !/^\d+$/.test(process.env.LOWER_V0_SEED ?? ''))
  throw new Error('LOWER_V0_SEED must be a nonnegative integer')

export default defineConfig({
  root: import.meta.dirname,
  test: {
    fileParallelism: false,
    include: collection ? ['lower_collection.test.ts'] : ['**/*.test.ts'],
    exclude: collection ? [] : ['lower_collection.test.ts'],
    isolate: false,
    pool: vikeeper({
      projectPath: path.join(repoRoot, 'external', 'domekeeper-decompiled', version),
      movie: process.env.VIDOT_MOVIE ?? (collection ? path.join(repoRoot, 'recordings/lower-v0.avi') : undefined),
    }),
  },
})
