<script setup>
import { useWindows } from '../stores/windows'
const wm = useWindows()
const cores = ['#111827', '#1e1b4b', '#052e16', '#4c0519']
</script>
<template>
  <p>Papel de parede</p>
  <button v-for="c in cores" :key="c" @click="wm.wallpaper = c"
          :style="{ background: c, width: '36px', height: '36px', marginRight: '8px', border: '2px solid #fff', borderRadius: '8px' }" />
</template>
