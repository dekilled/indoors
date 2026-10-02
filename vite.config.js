import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// base './' permite carregar via file:// (Electron) e via Capacitor
export default defineConfig({
  base: './',
  plugins: [vue()],
  server: { port: 5173 },
})
