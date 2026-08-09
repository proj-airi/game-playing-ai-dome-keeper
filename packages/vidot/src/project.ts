import { constants } from 'node:fs'
import { access, readFile, rename, rm, writeFile } from 'node:fs/promises'
import path from 'node:path'
import process from 'node:process'
import { fileURLToPath } from 'node:url'

const autoloadName = '__ViDot'
const ownerName = '.vidot-session.json'
const runtimeName = '__vidot_runtime.gd'
const temporaryName = '.vidot-project.godot.tmp'
const runtimeSource = fileURLToPath(new URL('../runtime/scripts/vidot_autoload.gd', import.meta.url))

export async function injectAutoload(projectPath: string): Promise<() => Promise<void>> {
  const files = projectFiles(projectPath)
  await reconcile(files)
  const [project, runtime] = await Promise.all([
    readFile(files.project, 'utf8'),
    readFile(runtimeSource, 'utf8'),
  ])
  const createdSection = !/^\[autoload\]\s*$/m.test(project)
  const injectedProject = addAutoload(project)

  await writeFile(files.owner, JSON.stringify({ createdSection, pid: process.pid }), { flag: 'wx' })
  try {
    await writeFile(files.runtime, runtime, { flag: 'wx' })
    await atomicWrite(files.project, files.temporary, injectedProject)
  }
  catch (error) {
    await removeAutoload(files, createdSection)
    throw error
  }

  let removed = false

  return async () => {
    if (removed)
      return

    removed = true
    await removeAutoload(files, createdSection)
  }
}

export async function assertAutoloadInjected(projectPath: string): Promise<void> {
  const files = projectFiles(projectPath)
  const [project, runtimeExists, ownerExists] = await Promise.all([
    readFile(files.project, 'utf8'),
    exists(files.runtime),
    exists(files.owner),
  ])
  if (!runtimeExists || !ownerExists || !project.includes(`${autoloadName}="*res://${runtimeName}"`))
    throw new Error(`ViDot is not injected into ${projectPath}`)
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

async function reconcile(files: ReturnType<typeof projectFiles>): Promise<void> {
  if (!await exists(files.owner)) {
    if (await exists(files.runtime) || await exists(files.temporary))
      throw new Error('Unowned ViDot injection files already exist')

    return
  }

  const owner = JSON.parse(await readFile(files.owner, 'utf8')) as { createdSection?: boolean, pid?: number }
  if (owner.pid && processIsAlive(owner.pid))
    throw new Error(`Godot project already has an active ViDot session owned by PID ${owner.pid}`)

  await removeAutoload(files, owner.createdSection === true)
}

async function removeAutoload(files: ReturnType<typeof projectFiles>, createdSection: boolean): Promise<void> {
  let project = await readFile(files.project, 'utf8')
  const current = project
  project = project.replace(/^__ViDot="\*res:\/\/__vidot_runtime\.gd"\r?\n?/m, '')
  if (createdSection)
    project = project.replace(/^\[autoload\][ \t]*\r?\n\r?\n/, '')

  if (project !== current)
    await atomicWrite(files.project, files.temporary, project)

  await rm(files.runtime, { force: true })
  await rm(`${files.runtime}.uid`, { force: true })
  await rm(files.temporary, { force: true })
  await rm(files.owner, { force: true })
}

async function atomicWrite(destination: string, temporary: string, content: string): Promise<void> {
  await rm(temporary, { force: true })
  await writeFile(temporary, content, { flag: 'wx' })
  await rename(temporary, destination)
}

function processIsAlive(pid: number): boolean {
  try {
    process.kill(pid, 0)

    return true
  }
  catch (error) {
    return (error as NodeJS.ErrnoException).code !== 'ESRCH'
  }
}

async function exists(file: string): Promise<boolean> {
  try {
    await access(file, constants.F_OK)

    return true
  }
  catch {
    return false
  }
}

function projectFiles(projectPath: string) {
  return {
    owner: path.join(projectPath, ownerName),
    project: path.join(projectPath, 'project.godot'),
    runtime: path.join(projectPath, runtimeName),
    temporary: path.join(projectPath, temporaryName),
  }
}
