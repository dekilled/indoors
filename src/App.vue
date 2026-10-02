<script setup>
import { useWindows, APPS } from './stores/windows'
import Window from './components/Window.vue'
const wm = useWindows()
</script>

<template>
  <div class="desktop" :style="{ background: wm.wallpaper }">
    <Window v-for="w in wm.list" :key="w.id" :win="w">
      <component :is="APPS[w.appId].component" />
    </Window>

    <div class="taskbar">
      <button v-for="(app, id) in APPS" :key="id" @click="wm.open(id)" :title="app.title">{{ app.icon }}</button>
      <span class="sep" />
      <button v-for="w in wm.list" :key="w.id" class="task" @click="wm.focus(w.id)">{{ w.title }}</button>
    </div>
  </div>
</template>

<style scoped>
.desktop { position: relative; width: 100%; height: 100%; }
.taskbar { position: absolute; left: 0; right: 0; bottom: 0; height: 52px; display: flex; align-items: center; gap: 6px; padding: 0 10px; background: rgba(31,41,55,.9); backdrop-filter: blur(8px); z-index: 99999; }
.taskbar button { background: transparent; border: 0; color: inherit; font-size: 20px; padding: 6px 10px; border-radius: 8px; cursor: pointer; }
.taskbar button:hover { background: rgba(255,255,255,.1); }
.task { font-size: 13px !important; }
.sep { width: 1px; height: 24px; background: rgba(255,255,255,.2); margin: 0 6px; }
</style>
