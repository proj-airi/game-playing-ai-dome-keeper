<script setup lang="ts">
import Button from '@proj-airi/ui/src/components/misc/button.vue'
import { computed, ref } from 'vue'
import { useDashboard } from './dashboard'
import { DashboardMode } from './types/status'

const mode = ref(DashboardMode.Live)
const dashboard = useDashboard()
const video = dashboard.video
const snapshot = computed(() => {
  const value = mode.value === DashboardMode.Live ? dashboard.live.value : dashboard.selectedEvent.value?.state
  return value?.available ? value : null
})
const number = new Intl.NumberFormat(undefined, { maximumFractionDigits: 1 })
const preciseNumber = new Intl.NumberFormat(undefined, { maximumFractionDigits: 3 })
const format = (value: number, suffix = '') => `${number.format(value)}${suffix}`
const precise = (value: number) => preciseNumber.format(value)
const time = (seconds: number) => `${Math.floor(seconds / 60)}:${String(Math.floor(seconds) % 60).padStart(2, '0')}`
const resources = (value: Record<string, number>) => Object.entries(value).filter(([, count]) => count).map(([name, count]) => `${count} ${name}`).join(' · ') || 'None'
const keeperRows = computed(() => snapshot.value
  ? [
      ['Movement speed', `${format(snapshot.value.keeper.stats.movement_speed.current)} current · ${format(snapshot.value.keeper.stats.movement_speed.base)} base · Level ${snapshot.value.keeper.stats.movement_speed.level}`],
      ['Carry strength', `${format(snapshot.value.keeper.stats.carry_strength.current_slowdown_percent, '%')} current slowdown · ${precise(snapshot.value.keeper.stats.carry_strength.speed_loss_per_carry)} loss · Level ${snapshot.value.keeper.stats.carry_strength.level}`],
      ['Drill strength', `${format(snapshot.value.keeper.stats.drill_strength.value)} · Level ${snapshot.value.keeper.stats.drill_strength.level}`],
      ['Carried resources', resources(snapshot.value.keeper.carried_resources)],
    ]
  : [])
</script>

<template>
  <main class="min-h-screen bg-neutral-50 font-sans text-neutral-900">
    <div class="mx-auto max-w-[1200px] px-4 py-6 sm:px-7 lg:py-8">
      <header class="mb-6 flex flex-wrap items-end justify-between gap-4">
        <h1 class="m-0 text-4xl text-primary-500 font-rounded font-650 tracking-tight">
          Dome Keeper
        </h1>
        <div class="flex gap-2">
          <Button label="Live" size="sm" variant="secondary-muted" :toggled="mode === DashboardMode.Live" @click="mode = DashboardMode.Live" />
          <Button label="Replay" size="sm" variant="secondary-muted" :toggled="mode === DashboardMode.Replay" @click="mode = DashboardMode.Replay" />
        </div>
      </header>

      <p v-if="mode === DashboardMode.Live && dashboard.liveError.value" class="mb-3 text-sm text-orange-600">
        {{ dashboard.liveError.value }}{{ dashboard.live.value ? ' · Showing the last snapshot.' : '' }}
      </p>

      <section v-if="mode === DashboardMode.Replay" class="surface mb-4 p-5">
        <div class="flex flex-wrap gap-2">
          <label class="file-button">Select JSON<input class="hidden" type="file" accept=".json,application/json" @change="dashboard.selectJson"></label>
          <label class="file-button">Select MP4<input class="hidden" type="file" accept=".mp4,video/mp4" @change="dashboard.selectMp4"></label>
        </div>
        <p v-if="dashboard.fileError.value" class="text-sm text-orange-600">
          {{ dashboard.fileError.value }}
        </p>
        <video
          v-if="dashboard.movieUrl.value" ref="video" :key="dashboard.movieUrl.value" class="mt-4 aspect-video w-full rounded-2xl bg-neutral-900"
          :src="dashboard.movieUrl.value" :playback-rate.camel="dashboard.rate.value" controls preload="metadata" @loadedmetadata="dashboard.selectEvent(dashboard.eventIndex.value)" @timeupdate="dashboard.syncEvent"
        />
        <div v-if="dashboard.selectedEvent.value" class="mt-4 flex flex-wrap items-center gap-3 border-t border-neutral-200 pt-4">
          <Button label="Previous" size="sm" variant="secondary" :disabled="dashboard.eventIndex.value <= 0" @click="dashboard.selectEvent(dashboard.eventIndex.value - 1)" />
          <Button label="Next" size="sm" variant="secondary" :disabled="dashboard.eventIndex.value >= (dashboard.replay.value?.events.length ?? 0) - 1" @click="dashboard.selectEvent(dashboard.eventIndex.value + 1)" />
          <select v-model.number="dashboard.rate.value" class="file-button" aria-label="Playback speed">
            <option v-for="speed in [0.5, 1, 2, 4]" :key="speed" :value="speed">
              {{ speed }}×
            </option>
          </select>
          <div class="min-w-60 flex-1">
            <strong class="capitalize">{{ dashboard.selectedEvent.value.transition ? `${dashboard.selectedEvent.value.transition.from} → ${dashboard.selectedEvent.value.transition.to}` : dashboard.selectedEvent.value.type.replaceAll('_', ' ') }}</strong>
            <span class="ml-2 text-sm text-neutral-500">{{ dashboard.selectedEvent.value.reason }}</span>
          </div>
        </div>
      </section>

      <section v-if="!snapshot" class="surface p-10 text-center text-neutral-500">
        {{ mode === DashboardMode.Live ? 'Waiting for an active Dome Keeper run.' : 'Select replay JSON to show synchronized status.' }}
      </section>
      <template v-else>
        <section class="surface grid gap-4 p-5 sm:grid-cols-3">
          <div>
            <p class="data-label">
              Current state
            </p><strong class="text-2xl text-primary-500">{{ snapshot.teacher.state }}</strong>
          </div>
          <div>
            <p class="data-label">
              Navigation
            </p><strong>{{ snapshot.teacher.nav_mode ?? '—' }}</strong>
          </div>
          <div>
            <p class="data-label">
              Run time
            </p><strong>{{ time(snapshot.run_time_seconds) }}</strong>
          </div>
        </section>

        <div class="mt-4 grid gap-4 md:grid-cols-2">
          <section class="surface p-5">
            <h2 class="m-0 text-xl font-650">
              Dome · {{ format(snapshot.dome.health.current) }} / {{ format(snapshot.dome.health.maximum) }} health · Level {{ snapshot.dome.health.level }}
            </h2>
            <dl class="mt-4">
              <div class="status-row">
                <dt>Laser attack</dt><dd>{{ format(snapshot.dome.laser.attack_strength.value) }} · Level {{ snapshot.dome.laser.attack_strength.level }}</dd>
              </div>
              <div class="status-row">
                <dt>Laser movement</dt><dd>{{ precise(snapshot.dome.laser.movement_speed.value) }} · {{ precise(snapshot.dome.laser.movement_speed.while_firing) }} firing · Level {{ snapshot.dome.laser.movement_speed.level }}</dd>
              </div>
              <div v-for="(count, name) in snapshot.dome.stored_resources" :key="name" class="status-row">
                <dt class="capitalize">
                  {{ name }}
                </dt><dd>{{ count }}</dd>
              </div>
            </dl>
          </section>
          <section class="surface p-5">
            <h2 class="m-0 text-xl font-650">
              Wave {{ snapshot.wave.number }} · {{ snapshot.wave.seconds_until_next === null ? '—' : `${Math.ceil(snapshot.wave.seconds_until_next)}s` }}
            </h2>
            <dl class="mt-4">
              <div v-for="group in snapshot.wave.active_monsters" :key="group.kind" class="status-row">
                <dt>{{ group.kind }} · {{ group.count }}</dt><dd>{{ format(group.health) }} / {{ format(group.max_health) }} health</dd>
              </div>
            </dl>
          </section>
        </div>

        <section class="surface mt-4 p-5">
          <h2 class="m-0 text-xl font-650">
            Keeper
          </h2>
          <dl class="grid gap-x-8 md:grid-cols-2">
            <div v-for="[label, value] in keeperRows" :key="label" class="status-row">
              <dt>{{ label }}</dt><dd class="capitalize">
                {{ value }}
              </dd>
            </div>
          </dl>
        </section>
        <section class="surface mt-4 grid gap-5 p-5 md:grid-cols-2">
          <div>
            <p class="data-label">
              Pending upgrades
            </p><p class="capitalize">
              {{ snapshot.upgrades.pending_intents.join(' · ') || 'None' }}
            </p>
          </div>
          <div>
            <p class="data-label">
              Next upgrade
            </p><strong>{{ snapshot.upgrades.resolved_next?.id ?? 'Not resolved' }}</strong><p class="capitalize">
              {{ snapshot.upgrades.resolved_next ? resources(snapshot.upgrades.resolved_next.cost) : '' }}
            </p>
          </div>
        </section>
      </template>
    </div>
  </main>
</template>
