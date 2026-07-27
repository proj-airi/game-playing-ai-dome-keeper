import type { Plugin } from 'vite'
import { readFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import vue from '@vitejs/plugin-vue'
import UnoCSS from 'unocss/vite'
import { defineConfig } from 'vite'

const localStatus: Plugin = {
  name: 'dome-keeper-local-status',
  configureServer(server) {
    server.middlewares.use(async (request, response, next) => {
      if (request.method !== 'GET' || new URL(request.url ?? '/', 'http://localhost').pathname !== '/api/status')
        return next()
      try {
        const contents = await readFile(join(tmpdir(), 'airi-dome-keeper-status.json'))
        response.writeHead(200, { 'Cache-Control': 'no-store', 'Content-Length': contents.byteLength, 'Content-Type': 'application/json' }).end(contents)
      }
      catch {
        response.writeHead(503, { 'Cache-Control': 'no-store', 'Content-Type': 'text/plain' }).end('Status file is unavailable\n')
      }
    })
  },
}

export default defineConfig({ plugins: [localStatus, UnoCSS(), vue()], server: { host: '127.0.0.1', port: 5773, strictPort: true } })
