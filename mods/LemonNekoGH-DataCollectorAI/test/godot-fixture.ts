import { copyFile, mkdir, rm } from 'node:fs/promises'
import path from 'node:path'
import process from 'node:process'
import { fileURLToPath } from 'node:url'
import { execa } from 'execa'

const source = fileURLToPath(new URL('godot', import.meta.url))
const output = fileURLToPath(new URL('../scripts/__test__', import.meta.url))
const typings = path.join(source, '_typings')

export async function prepareGodotFixture(): Promise<void> {
  await cleanGodotFixture()
  await mkdir(output, { recursive: true })
  try {
    await execa('bunx', ['tstogd', 'convert'], { cwd: source, stdio: 'inherit' })
    await copyFile(path.join(source, 'move_test.tscn'), path.join(output, 'move_test.tscn'))
  }
  catch (error) {
    await cleanGodotFixture()
    throw error
  }
}

export async function cleanGodotFixture(): Promise<void> {
  await Promise.all([
    rm(output, { force: true, recursive: true }),
    rm(typings, { force: true, recursive: true }),
  ])
}

if (import.meta.main) {
  if (process.argv[2] !== 'clean')
    throw new Error('Expected the clean command')

  cleanGodotFixture().catch((error) => {
    console.error(error)
    process.exitCode = 1
  })
}
