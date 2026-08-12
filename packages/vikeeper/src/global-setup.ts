import type { TestProject } from 'vitest/node'
import { readdir, readFile, realpath } from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { setupViDot } from '@vidot/vitest/setup'

const runtimePath = fileURLToPath(new URL('../runtime', import.meta.url))

export default async function setup(project: TestProject) {
  const context = project.getProvidedContext().vikeeper
  const projectPath = await findProject(context.projectsPath, context.modPath)

  return setupViDot(projectPath, {
    movie: context.movie ?? undefined,
    sandboxFiles: {
      'res://__vikeeper/move_test.gd': path.join(runtimePath, 'scripts/move_test.gd'),
      'res://__vikeeper/move_test.tscn': path.join(runtimePath, 'move_test.tscn'),
    },
    scene: 'res://__vikeeper/move_test.tscn',
  })(project)
}

async function findProject(projectsPath: string, modPath: string): Promise<string> {
  const manifest = JSON.parse(await readFile(path.join(modPath, 'manifest.json'), 'utf8')) as {
    name: string
    namespace: string
  }
  const modId = `${manifest.namespace}-${manifest.name}`
  const source = await realpath(modPath)
  const projects: string[] = []

  for (const entry of await readdir(projectsPath, { withFileTypes: true })) {
    if (!entry.isDirectory())
      continue

    const projectPath = path.join(projectsPath, entry.name)
    try {
      if (await realpath(path.join(projectPath, 'mods-unpacked', modId)) === source)
        projects.push(projectPath)
    }
    catch (error) {
      if ((error as NodeJS.ErrnoException).code !== 'ENOENT')
        throw error
    }
  }

  if (projects.length !== 1)
    throw new Error(`Expected one decompiled project linked to ${modId}, found ${projects.length}`)

  return projects[0]
}
