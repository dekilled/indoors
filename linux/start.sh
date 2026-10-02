#!/system/bin/sh
# Entra no Ubuntu (chroot) dentro de namespaces próprios.
# Uso (como root): sh start.sh [comando...]
# Variáveis opcionais:
#   INDOORS_SDCARD=1      liga /sdcard dentro do Linux (permissão de arquivos)
#   INDOORS_NET_ISOLATE=1 rede isolada (netns); sem rede até configurar veth
ROOT=/data/local/indoors/ubuntu

[ "$(id -u)" = "0" ] || { echo "rode como root (su)"; exit 1; }
[ -d "$ROOT/bin" ] || { echo "rootfs não encontrado: rode setup.sh antes"; exit 1; }

FLAGS="-m -u -i -p -f"                       # mount, uts, ipc, pid
[ "$INDOORS_NET_ISOLATE" = "1" ] && FLAGS="$FLAGS -n"

[ $# -eq 0 ] && set -- /bin/bash -l

# Os mounts ficam no mount namespace: somem sozinhos quando o Linux fecha.
exec unshare $FLAGS sh -c '
  ROOT="$1"; shift
  mount --make-rprivate / 2>/dev/null || mount -o rprivate / 2>/dev/null
  mount -o bind /dev "$ROOT/dev"
  mount -t devpts devpts "$ROOT/dev/pts" 2>/dev/null
  mount -t proc proc "$ROOT/proc"
  mount -t sysfs sysfs "$ROOT/sys"
  mount -t tmpfs tmpfs "$ROOT/tmp"
  if [ "$INDOORS_SDCARD" = "1" ]; then
    mkdir -p "$ROOT/sdcard"; mount -o bind /sdcard "$ROOT/sdcard"
  fi
  hostname indoors
  exec chroot "$ROOT" /usr/bin/env -i HOME=/root TERM="${TERM:-xterm-256color}" \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin "$@"
' sh "$ROOT" "$@"
