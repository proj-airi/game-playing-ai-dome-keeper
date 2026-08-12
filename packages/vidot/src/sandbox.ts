import { createHash } from 'node:crypto'
import { existsSync } from 'node:fs'
import { copyFile, mkdir, readdir, readFile, rm, rmdir, stat, symlink, writeFile } from 'node:fs/promises'
import { homedir, tmpdir } from 'node:os'
import path from 'node:path'
import process from 'node:process'

export interface GodotProjectSandbox {
  path: string
  userDataDir: string
}

export interface GodotSandboxFile {
  source: string
  target: string
}

export async function createGodotProjectSandbox(
  projectPath: string,
  namespace: string,
  sandboxFiles: GodotSandboxFile[] = [],
): Promise<GodotProjectSandbox> {
  if (!/^[\w-]+$/.test(namespace))
    throw new Error('Godot sandbox names may contain only letters, numbers, underscores, and hyphens')

  projectPath = path.resolve(projectPath)
  const id = createHash('sha256').update(projectPath).digest('hex').slice(0, 12)
  const customUserDir = `${namespace}/${id}`
  const sandbox = {
    path: path.join(tmpdir(), `${namespace}-${id}`),
    userDataDir: resolveUserDataDir(customUserDir),
  }

  await cleanupGodotProjectSandbox(sandbox)
  await mkdir(sandbox.path)
  try {
    const sandboxFileRoots = new Set(sandboxFiles.map(file => file.target.split('/')[0]))
    const entries = await readdir(projectPath, { withFileTypes: true })
    for (const root of sandboxFileRoots) {
      if (root === 'project.godot' || root === 'override.cfg' || entries.some(entry => entry.name === root))
        throw new Error(`Godot sandbox file target already exists in the source project: res://${root}`)
    }

    await Promise.all(entries.map(async (entry) => {
      if (entry.name === 'project.godot' || entry.name === 'override.cfg')
        return

      const source = path.join(projectPath, entry.name)
      const sourceStat = entry.isSymbolicLink() ? await stat(source) : entry
      const destination = path.join(sandbox.path, entry.name)
      if (sourceStat.isDirectory()) {
        await symlink(source, destination, 'junction')

        return
      }

      await copyFile(source, destination)
    }))

    await writeFile(
      path.join(sandbox.path, 'project.godot'),
      await readFile(path.join(projectPath, 'project.godot')),
    )
    const sourceOverride = path.join(projectPath, 'override.cfg')
    const override = existsSync(sourceOverride) ? await readFile(sourceOverride, 'utf8') : ''
    await writeFile(path.join(sandbox.path, 'override.cfg'), setUserDataSettings(override, customUserDir))
    await Promise.all(sandboxFiles.map(async (file) => {
      const destination = path.join(sandbox.path, file.target)
      await mkdir(path.dirname(destination), { recursive: true })
      await copyFile(file.source, destination)
    }))

    return sandbox
  }
  catch (error) {
    try {
      await cleanupGodotProjectSandbox(sandbox)
    }
    catch (cleanupError) {
      throw new AggregateError([error, cleanupError], 'Godot sandbox setup failed and could not be cleaned up')
    }

    throw error
  }
}

export async function cleanupGodotProjectSandbox(sandbox: GodotProjectSandbox): Promise<void> {
  await Promise.all([
    rm(sandbox.path, { force: true, recursive: true }),
    rm(sandbox.userDataDir, { force: true, recursive: true }),
  ])
  try {
    await rmdir(path.dirname(sandbox.userDataDir))
  }
  catch (error) {
    const code = (error as NodeJS.ErrnoException).code
    if (code !== 'ENOENT' && code !== 'ENOTEMPTY')
      throw error
  }
}

function setUserDataSettings(config: string, customUserDir: string): string {
  const eol = config.includes('\r\n') ? '\r\n' : '\n'
  const settings = [
    'config/use_custom_user_dir=true',
    `config/custom_user_dir_name=${JSON.stringify(customUserDir)}`,
  ]
  const section = /^\[application\][ \t]*$/m.exec(config)
  if (!section)
    return `${config}${config === '' || config.endsWith(eol) ? '' : eol}${eol}[application]${eol}${settings.join(eol)}${eol}`

  const headerEnd = config.indexOf('\n', section.index)
  if (headerEnd < 0)
    return `${config}${eol}${settings.join(eol)}${eol}`

  const bodyStart = headerEnd + 1
  const relativeBodyEnd = /^\[/m.exec(config.slice(bodyStart))?.index
  const bodyEnd = relativeBodyEnd === undefined ? config.length : bodyStart + relativeBodyEnd
  let body = config.slice(bodyStart, bodyEnd)
  for (const setting of settings) {
    const key = setting.slice(0, setting.indexOf('='))
    const pattern = new RegExp(`^${key}=[^\\r\\n]*\\r?$`, 'm')
    body = pattern.test(body)
      ? body.replace(pattern, eol === '\r\n' ? `${setting}\r` : setting)
      : `${body}${body === '' || body.endsWith(eol) ? '' : eol}${setting}${eol}`
  }

  return `${config.slice(0, bodyStart)}${body}${config.slice(bodyEnd)}`
}

function resolveUserDataDir(customUserDir: string): string {
  switch (process.platform) {
    case 'darwin':
      return path.join(homedir(), 'Library', 'Application Support', customUserDir)
    case 'linux':
    case 'freebsd':
    case 'openbsd':
      return path.join(process.env.XDG_DATA_HOME ?? path.join(homedir(), '.local', 'share'), customUserDir)
    case 'win32': {
      const appData = process.env.APPDATA
      if (!appData)
        throw new Error('APPDATA is required to isolate Godot user data on Windows')

      return path.join(appData, customUserDir)
    }
    default:
      throw new Error(`The Godot user-data location is unknown on ${process.platform}`)
  }
}
