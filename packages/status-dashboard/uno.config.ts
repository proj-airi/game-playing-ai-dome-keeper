import { defineConfig, presetWind3 } from 'unocss'

export default defineConfig({
  presets: [presetWind3()],
  theme: {
    colors: { primary: { 50: '#eef8ff', 100: '#d9f0ff', 200: '#bce5ff', 300: '#8ed5ff', 400: '#59bbf8', 500: '#3298e6', 600: '#2379c4', 700: '#21619f', 800: '#205282', 900: '#20456c', 950: '#162c48' } },
    fontFamily: { sans: '"DM Sans", "Avenir Next", Inter, ui-sans-serif, system-ui, sans-serif', rounded: '"Comfortaa", "Avenir Next Rounded", ui-rounded, sans-serif' },
  },
  shortcuts: {
    'surface': 'border border-solid border-neutral-200/55 rounded-3xl bg-white/85',
    'data-label': 'm-0 text-xs text-neutral-500 font-550',
    'status-row': 'flex min-h-11 items-center justify-between gap-4 border-b border-neutral-200/55 last:border-b-0',
    'file-button': 'min-h-9 cursor-pointer rounded-xl border border-neutral-200 bg-white px-3 py-2 text-xs text-neutral-600',
  },
})
