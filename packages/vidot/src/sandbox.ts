import { existsSync } from 'node:fs'
import { mkdtemp, readdir, readFile, rm, stat, symlink, writeFile } from 'node:fs/promises'
import { homedir, tmpdir } from 'node:os'
import path from 'node:path'
import process from 'node:process'

export interface GodotProjectSandbox {
  path: string
  userDataDir: string
}

export async function createGodotProjectSandbox(
  projectPath: string,
  namespace: string,
  session: string,
): Promise<GodotProjectSandbox> {
  if (!/^[\w-]+$/.test(namespace) || !/^[\w-]+$/.test(session))
    throw new Error('Godot sandbox names may contain only letters, numbers, underscores, and hyphens')

  projectPath = path.resolve(projectPath)
  const sandboxPath = await mkdtemp(path.join(tmpdir(), 'godot-project-'))
  try {
    const customUserDir = path.join(namespace, session)
    const userDataDir = resolveUserDataDir(customUserDir)
    const entries = await readdir(projectPath, { withFileTypes: true })
    await Promise.all(entries.map(async (entry) => {
      if (entry.name === 'project.godot' || entry.name === 'override.cfg' || entry.name.startsWith('.vidot-'))
        return

      const source = path.join(projectPath, entry.name)
      const sourceStat = entry.isSymbolicLink() ? await stat(source) : entry
      await symlink(source, path.join(sandboxPath, entry.name), sourceStat.isDirectory() ? 'junction' : 'file')
    }))

    await writeFile(
      path.join(sandboxPath, 'project.godot'),
      await readFile(path.join(projectPath, 'project.godot')),
    )
    const sourceOverride = path.join(projectPath, 'override.cfg')
    const override = existsSync(sourceOverride) ? await readFile(sourceOverride, 'utf8') : ''
    await writeFile(path.join(sandboxPath, 'override.cfg'), setUserDataSettings(override, customUserDir))

    return { path: sandboxPath, userDataDir }
  }
  catch (error) {
    try {
      await rm(sandboxPath, { force: true, recursive: true })
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
}

function setUserDataSettings(config: string, customUserDir: string): string {
  const eol = config.includes('\r\n') ? '\r\n' : '\n'
  const settings = [
    'config/use_custom_user_dir=true',
    `config/custom_user_dir_name=${JSON.stringify(customUserDir)}`,
  ]
  const section = /^\[application\][ \t]*$/m.exec(config)
  if (!section)
    return `${config}${config.endsWith(eol) || config === '' ? '' : eol}${eol}[application]${eol}${settings.join(eol)}${eol}`

  const headerEnd = config.indexOf('\n', section.index)
  if (headerEnd < 0)
    return `${config}${eol}${settings.join(eol)}${eol}`

  const bodyStart = headerEnd + 1
  const sectionEnd = /^\[/m.exec(config.slice(bodyStart))?.index
  const bodyEnd = sectionEnd === undefined ? config.length : bodyStart + sectionEnd
  let body = config.slice(bodyStart, bodyEnd)
  for (const setting of settings) {
    const key = setting.slice(0, setting.indexOf('='))
    const pattern = new RegExp(`^${key.replaceAll('/', '\\/')}=.*$`, 'm')
    body = pattern.test(body) ? body.replace(pattern, setting) : `${body}${body.endsWith(eol) || body === '' ? '' : eol}${setting}${eol}`
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
