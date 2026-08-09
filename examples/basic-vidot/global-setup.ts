import { fileURLToPath } from 'node:url'
import { setupViDot } from '@vidot/vitest/setup'

const projectPath = fileURLToPath(new URL('.', import.meta.url))

export default setupViDot(projectPath)
