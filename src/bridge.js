// Configuração da ponte (host + token), compartilhada pelos apps que falam com o Ubuntu.
const KEY = 'indoors.bridge'

export function bridgeConfig() {
  let saved = null
  try { saved = JSON.parse(localStorage.getItem(KEY)) } catch {}
  const fromLink = new URLSearchParams(location.hash.slice(1)).get('token')
  return {
    host: fromLink ? `${location.hostname || '127.0.0.1'}:8765` : saved?.host || '127.0.0.1:8765',
    token: fromLink || saved?.token || '',
  }
}

export function saveBridgeConfig(host, token) {
  try { localStorage.setItem(KEY, JSON.stringify({ host, token })) } catch {}
}
