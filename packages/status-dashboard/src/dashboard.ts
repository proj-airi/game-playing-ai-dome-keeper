import type { ReplayRecording, StatusSnapshot } from './types/status'
import { computed, onMounted, onUnmounted, ref } from 'vue'

export function useDashboard() {
  const live = ref<StatusSnapshot | null>(null)
  const liveError = ref<string | null>(null)
  const replay = ref<ReplayRecording | null>(null)
  const movieUrl = ref<string | null>(null)
  const fileError = ref<string | null>(null)
  const video = ref<HTMLVideoElement | null>(null)
  const eventIndex = ref(0)
  const rate = ref(1)
  const selectedEvent = computed(() => replay.value?.events[eventIndex.value] ?? null)
  let timer: ReturnType<typeof setTimeout> | undefined
  let stopped = false

  async function poll() {
    try {
      const response = await fetch('/api/status', { cache: 'no-store' })
      if (!response.ok)
        throw new Error(`Status endpoint returned HTTP ${response.status}`)
      live.value = await response.json() as StatusSnapshot
      liveError.value = null
    }
    catch (error) {
      if (!stopped)
        liveError.value = error instanceof Error ? error.message : 'Unable to read status'
    }
    if (!stopped)
      timer = setTimeout(poll, 1_000)
  }

  async function selectJson(event: Event) {
    const input = event.currentTarget as HTMLInputElement
    const file = input.files?.[0]
    input.value = ''
    if (!file)
      return
    try {
      replay.value = JSON.parse(await file.text()) as ReplayRecording
      fileError.value = null
      selectEvent(0)
    }
    catch (error) {
      fileError.value = error instanceof Error ? error.message : 'Unable to read replay JSON'
    }
  }

  function selectMp4(event: Event) {
    const input = event.currentTarget as HTMLInputElement
    const file = input.files?.[0]
    input.value = ''
    if (!file)
      return
    clearMovie()
    movieUrl.value = URL.createObjectURL(file)
  }

  function selectEvent(index: number) {
    if (!replay.value?.events.length)
      return
    eventIndex.value = Math.min(Math.max(index, 0), replay.value.events.length - 1)
    video.value?.pause()
    if (video.value)
      video.value.currentTime = replay.value.events[eventIndex.value].movie_frame / replay.value.fixed_fps
  }

  function syncEvent() {
    if (!replay.value?.events.length || !video.value)
      return
    const time = video.value.currentTime
    const current = replay.value.events[eventIndex.value]
    if (current && Math.abs(time - current.movie_frame / replay.value.fixed_fps) < 0.000_1)
      return
    let lower = 0
    let upper = replay.value.events.length
    while (lower < upper) {
      const middle = Math.floor((lower + upper) / 2)
      if (replay.value.events[middle].movie_frame / replay.value.fixed_fps <= time)
        lower = middle + 1
      else
        upper = middle
    }
    eventIndex.value = Math.max(lower - 1, 0)
  }

  function clearMovie() {
    if (movieUrl.value)
      URL.revokeObjectURL(movieUrl.value)
    movieUrl.value = null
  }

  onMounted(poll)
  onUnmounted(() => {
    stopped = true
    clearTimeout(timer)
    clearMovie()
  })
  return { eventIndex, fileError, live, liveError, movieUrl, rate, replay, selectEvent, selectJson, selectMp4, selectedEvent, syncEvent, video }
}
