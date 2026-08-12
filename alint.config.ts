import {
  defineConfig,
  ignorePatternsAIAgents,
  ignorePatternsCommon,
} from '@alint-js/cli'

import jsPlugin from '@alint-js/plugin-js'

export default defineConfig([
  {
    ignores: [
      ...ignorePatternsCommon,
      ...ignorePatternsAIAgents,
    ],
  },
  {
    ignore: {
      gitignore: true,
    },
  },
  {
    extends: ['js/recommended'],
    files: ['**/*.{js,jsx,ts,tsx,mjs,cjs,mts,cts}'],
    plugins: {
      js: jsPlugin,
    },
  },
])
