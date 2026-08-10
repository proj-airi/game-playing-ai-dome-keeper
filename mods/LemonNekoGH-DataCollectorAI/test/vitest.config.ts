import { fileURLToPath } from 'node:url'
import { defineConfig } from 'vitest/config'

export default defineConfig({
  root: fileURLToPath(new URL('.', import.meta.url)),
  test: {
    globalSetup: './global-setup.ts',
    hookTimeout: 90_000,
    testTimeout: 90_000,
  },
})
