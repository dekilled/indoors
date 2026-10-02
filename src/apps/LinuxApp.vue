<script setup>
// Mostra um app gráfico do Ubuntu (via VNC/noVNC) dentro de uma janela do Indoors.
import { ref, onMounted, onBeforeUnmount } from 'vue'
import RFB from '@novnc/novnc'
import { bridgeConfig } from '../bridge'

const props = defineProps({ app: { type: String, required: true } })
const el = ref(null)
const status = ref('conectando...')
let rfb

onMounted(() => {
  const { host, token } = bridgeConfig()
  if (!token) { status.value = 'sem token: abra o Terminal e conecte primeiro'; return }
  const url = `ws://${host}/vnc?token=${encodeURIComponent(token)}&app=${encodeURIComponent(props.app)}&w=800&h=500`
  rfb = new RFB(el.value, url, { wsProtocols: ['binary'] })
  rfb.scaleViewport = true   // encaixa a tela do app no tamanho da janela
  rfb.background = '#0b1020'
  rfb.addEventListener('connect', () => { status.value = '' })
  rfb.addEventListener('disconnect', e => { status.value = e.detail.clean ? 'app encerrado' : 'falha na conexão' })
})

onBeforeUnmount(() => { try { rfb?.disconnect() } catch {} })
</script>

<template>
  <div class="wrap">
    <div ref="el" class="screen" />
    <div v-if="status" class="msg">{{ status }}</div>
  </div>
</template>

<style scoped>
.wrap { position: relative; height: 100%; margin: -10px; background: #0b1020; }
.screen { width: 100%; height: 100%; }
.msg { position: absolute; inset: 0; display: grid; place-items: center; font-size: 13px; opacity: .8; pointer-events: none; }
</style>
