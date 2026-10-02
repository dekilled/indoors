import { defineStore } from 'pinia'
import Terminal from '../apps/Terminal.vue'
import Files from '../apps/Files.vue'
import Settings from '../apps/Settings.vue'
import LinuxApp from '../apps/LinuxApp.vue'

// Registro de apps: para criar um app novo, é só adicionar aqui.
export const APPS = {
  terminal: { title: 'Terminal', icon: '⌨️', component: Terminal },
  files: { title: 'Arquivos', icon: '📁', component: Files },
  settings: { title: 'Configurações', icon: '⚙️', component: Settings },
  // Apps gráficos do Ubuntu: o nome tem que existir em GUI_APPS na bridge.
  'linux-xterm': { title: 'xterm (Linux)', icon: '🐧', component: LinuxApp, props: { app: 'xterm' } },
  'linux-mousepad': { title: 'Mousepad (Linux)', icon: '📝', component: LinuxApp, props: { app: 'mousepad' } },
}

let nextId = 1
let nextZ = 1

export const useWindows = defineStore('windows', {
  state: () => ({ list: [], wallpaper: '#111827' }),
  actions: {
    open(appId) {
      const app = APPS[appId]
      const n = this.list.length
      this.list.push({
        id: nextId++, appId, title: app.title,
        x: 60 + n * 28, y: 50 + n * 28, w: 480, h: 320,
        z: nextZ++, minimized: false,
      })
    },
    focus(id) {
      const w = this.list.find(w => w.id === id)
      if (w) { w.z = nextZ++; w.minimized = false }
    },
    close(id) { this.list = this.list.filter(w => w.id !== id) },
    minimize(id) { const w = this.list.find(w => w.id === id); if (w) w.minimized = true },
  },
})
