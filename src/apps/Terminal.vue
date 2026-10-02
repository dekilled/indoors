<script setup>
import { ref, onMounted, onBeforeUnmount } from 'vue'
import { Terminal } from '@xterm/xterm'
import { FitAddon } from '@xterm/addon-fit'
import '@xterm/xterm/css/xterm.css'

const KEY = 'indoors.bridge'
const saved = (() => { try { return JSON.parse(localStorage.getItem(KEY)) } catch { return null } })()
// Link mágico: http://.../#token=XXXX conecta sozinho, sem digitar nada
const fromLink = new URLSearchParams(location.hash.slice(1)).get('token')
const host = ref(fromLink ? `${location.hostname || '127.0.0.1'}:8765` : saved?.host || '127.0.0.1:8765')
const token = ref(fromLink || saved?.token || '')
const status = ref('desconectado')
const el = ref(null)

let term, fit, ws, ro

function send(obj) { if (ws?.readyState === WebSocket.OPEN) ws.send(JSON.stringify(obj)) }

function connect() {
  try { localStorage.setItem(KEY, JSON.stringify({ host: host.value, token: token.value })) } catch {}
  ws?.close()
  status.value = 'conectando...'
  ws = new WebSocket(`ws://${host.value}/?token=${encodeURIComponent(token.value)}`)
  ws.binaryType = 'arraybuffer'
  ws.onopen = () => { status.value = 'conectado'; fit.fit(); send({ type: 'resize', cols: term.cols, rows: term.rows }); term.focus() }
  ws.onmessage = e => term.write(new Uint8Array(e.data))
  ws.onclose = e => { status.value = e.code === 4401 ? 'token inválido' : 'desconectado' }
  ws.onerror = () => { status.value = 'erro de conexão' }
}

onMounted(() => {
  term = new Terminal({ cursorBlink: true, fontSize: 14, theme: { background: '#0b1020' } })
  fit = new FitAddon()
  term.loadAddon(fit)
  term.open(el.value)
  term.onData(d => { if (ws?.readyState === WebSocket.OPEN) ws.send(new TextEncoder().encode(d)) })
  term.onResize(({ cols, rows }) => send({ type: 'resize', cols, rows }))
  ro = new ResizeObserver(() => fit.fit())
  ro.observe(el.value)
  if (token.value) connect()
})

onBeforeUnmount(() => { ro?.disconnect(); ws?.close(); term?.dispose() })
</script>

<template>
  <div class="wrap">
    <form class="bar" @submit.prevent="connect">
      <input v-model="host" placeholder="host:porta" />
      <input v-model="token" placeholder="token" type="password" />
      <button>Conectar</button>
      <span class="st">{{ status }}</span>
    </form>
    <div ref="el" class="term" />
  </div>
</template>

<style scoped>
.wrap { display: flex; flex-direction: column; height: 100%; margin: -10px; }
.bar { display: flex; gap: 6px; padding: 6px; background: #111827; font-size: 12px; align-items: center; user-select: none; }
.bar input { background: #0b1020; color: inherit; border: 1px solid #374151; border-radius: 6px; padding: 4px 6px; min-width: 0; flex: 1; }
.bar button { background: var(--accent); color: #fff; border: 0; border-radius: 6px; padding: 4px 10px; cursor: pointer; }
.st { opacity: .7; white-space: nowrap; }
.term { flex: 1; min-height: 0; background: #0b1020; padding: 4px; }
</style>
