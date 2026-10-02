#!/system/bin/sh
# Instala o rootfs do Ubuntu em /data/local/indoors/ubuntu
# Uso (como root): sh setup.sh /sdcard/Download/ubuntu-base-24.04-base-arm64.tar.gz
# Baixe o tarball em: https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/
set -e
TARBALL="$1"
ROOT=/data/local/indoors/ubuntu

[ "$(id -u)" = "0" ] || { echo "rode como root (su)"; exit 1; }
[ -f "$TARBALL" ] || { echo "uso: sh setup.sh <ubuntu-base-arm64.tar.gz>"; exit 1; }

mkdir -p "$ROOT"
tar -xzf "$TARBALL" -C "$ROOT"

# DNS estático (o Android não fornece resolv.conf dentro do chroot)
printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' > "$ROOT/etc/resolv.conf"
echo indoors > "$ROOT/etc/hostname"

# apt no Android: o usuário _apt não tem o grupo de rede do Android (inet=3003)
mkdir -p "$ROOT/etc/apt/apt.conf.d"
echo 'APT::Sandbox::User "root";' > "$ROOT/etc/apt/apt.conf.d/01-android-nosandbox"

echo "ok: rootfs em $ROOT. Agora rode: sh start.sh"
