import type { VidotClient } from '@vidot/vitest'

export const dataCollectorAI = '/root/DataCollectorAI'

export async function withDataCollectorAI<T>(
  vidot: VidotClient,
  run: (controller: string) => Promise<T>,
): Promise<T> {
  await waitForDataCollectorAI(vidot)
  try {
    return await run(dataCollectorAI)
  }
  finally {
    await vidot.call(dataCollectorAI, 'reset')
  }
}

async function waitForDataCollectorAI(vidot: VidotClient, timeoutMs = 60_000): Promise<void> {
  const deadline = Date.now() + timeoutMs
  while (Date.now() < deadline) {
    try {
      await vidot.waitForProperty(dataCollectorAI, 'move_ready', true, deadline - Date.now())

      return
    }
    catch (error) {
      if (!(error instanceof Error) || error.message !== `Unknown node: ${dataCollectorAI}`)
        throw error
    }

    await new Promise(resolve => setTimeout(resolve, 25))
  }

  throw new Error(`Timed out waiting for ${dataCollectorAI}`)
}
