import type { TestProject } from 'vitest/node'
import path from 'node:path'
import process from 'node:process'
import { fileURLToPath } from 'node:url'
import { setupViDot } from '@vidot/vitest/setup'
import { cleanGodotFixture, prepareGodotFixture } from './godot-fixture'

const version = process.env.DOMEKEEPER_VERSION
if (!version)
  throw new Error('DOMEKEEPER_VERSION must be provided by mise')

const repoRoot = fileURLToPath(new URL('../../..', import.meta.url))
const setup = setupViDot(
  path.join(repoRoot, 'external', 'domekeeper-decompiled', version),
  {
    scene: 'res://mods-unpacked/LemonNekoGH-DataCollectorAI/__test__/move_test.tscn',
  },
)

export default async function setupDataCollectorAITest(project: TestProject) {
  await prepareGodotFixture()
  try {
    const cleanupViDot = await setup(project)

    return async () => {
      try {
        await cleanupViDot()
      }
      finally {
        await cleanGodotFixture()
      }
    }
  }
  catch (error) {
    await cleanGodotFixture()
    throw error
  }
}
