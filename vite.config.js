import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// base './' permite carregar via file:// (Electron) e via Capacitor.
// target esnext: o noVNC usa top-level await (WebView do Android 14 e Electron suportam).
export default defineConfig({
  base: './',
  plugins: [vue()],
  server: { port: 5173 },
  build: { target: 'esnext' },
  optimizeDeps: { esbuildOptions: { target: 'esnext' } },
})
