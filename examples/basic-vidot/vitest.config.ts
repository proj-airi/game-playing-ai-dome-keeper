import { vidot } from '@vidot/vitest'
import { defineConfig } from 'vitest/config'

export default defineConfig({
  root: import.meta.dirname,
  test: {
    fileParallelism: false,
    include: ['**/*.test.ts'],
    isolate: false,
    pool: vidot({
      projectPath: import.meta.dirname,
    }),
  },
})
