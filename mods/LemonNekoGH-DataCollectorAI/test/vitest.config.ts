import path from 'node:path'
import process from 'node:process'
import { fileURLToPath } from 'node:url'
import { setupViKeeper } from '@vikeeper/vitest'

const repoRoot = fileURLToPath(new URL('../../..', import.meta.url))

export default setupViKeeper({
  modPath: fileURLToPath(new URL('../scripts', import.meta.url)),
  movie: process.env.VIDOT_MOVIE,
  projectsPath: path.join(repoRoot, 'external', 'domekeeper-decompiled'),
  root: fileURLToPath(new URL('.', import.meta.url)),
})
