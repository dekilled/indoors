<script setup>
import { useWindows } from '../stores/windows'
const props = defineProps({ win: Object })
const wm = useWindows()

// Arrastar com Pointer Events: funciona com mouse (Electron) e toque (Android)
function startDrag(e) {
  wm.focus(props.win.id)
  const ox = e.clientX - props.win.x
  const oy = e.clientY - props.win.y
  const move = ev => { props.win.x = ev.clientX - ox; props.win.y = Math.max(0, ev.clientY - oy) }
  const up = () => { window.removeEventListener('pointermove', move); window.removeEventListener('pointerup', up) }
  window.addEventListener('pointermove', move)
  window.addEventListener('pointerup', up)
}
</script>

<template>
  <div v-show="!win.minimized" class="win" @pointerdown="wm.focus(win.id)"
       :style="{ left: win.x + 'px', top: win.y + 'px', width: win.w + 'px', height: win.h + 'px', zIndex: win.z }">
    <div class="bar" @pointerdown.prevent="startDrag">
      <span>{{ win.title }}</span>
      <span>
        <button @click.stop="wm.minimize(win.id)">–</button>
        <button @click.stop="wm.close(win.id)">✕</button>
      </span>
    </div>
    <div class="body"><slot /></div>
  </div>
</template>

<style scoped>
.win { position: absolute; display: flex; flex-direction: column; background: var(--panel); border-radius: 10px; box-shadow: 0 10px 30px rgba(0,0,0,.5); overflow: hidden; max-width: 100vw; }
.bar { display: flex; justify-content: space-between; align-items: center; padding: 6px 10px; background: var(--accent); cursor: grab; touch-action: none; font-size: 13px; }
.bar button { background: transparent; border: 0; color: inherit; cursor: pointer; font-size: 14px; }
.body { flex: 1; overflow: auto; padding: 10px; user-select: text; }
</style>
