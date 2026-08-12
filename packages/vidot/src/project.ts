import { readFile, writeFile } from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const autoloadName = '__ViDot'
const runtimeName = '__vidot_runtime.gd'
const runtimeSource = fileURLToPath(new URL('../runtime/scripts/vidot_autoload.gd', import.meta.url))

export async function installAutoload(projectPath: string): Promise<void> {
  const projectFile = path.join(projectPath, 'project.godot')
  const runtimeFile = path.join(projectPath, runtimeName)
  const [project, runtime] = await Promise.all([
    readFile(projectFile, 'utf8'),
    readFile(runtimeSource, 'utf8'),
  ])

  await Promise.all([
    writeFile(projectFile, addAutoload(project)),
    writeFile(runtimeFile, runtime, { flag: 'wx' }),
  ])
}

function addAutoload(project: string): string {
  const entry = `${autoloadName}="*res://${runtimeName}"`
  if (new RegExp(`^${autoloadName}\\s*=`, 'm').test(project))
    throw new Error(`Godot project already defines the ${autoloadName} Autoload`)

  const eol = project.includes('\r\n') ? '\r\n' : '\n'
  const section = /^\[autoload\]\s*$/m.exec(project)
  if (!section)
    return `[autoload]${eol}${entry}${eol}${eol}${project}`

  const insertAt = project.indexOf('\n', section.index) + 1
  if (insertAt === 0)
    return `${project}${eol}${entry}${eol}`

  return `${project.slice(0, insertAt)}${entry}${eol}${project.slice(insertAt)}`
}
