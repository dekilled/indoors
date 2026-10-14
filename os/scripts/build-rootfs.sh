#!/bin/sh
# Monta o rootfs Arch Linux ARM e gera os/out/<aparelho>/rootfs.img (ext4, LABEL=indoors-root)
# Uso (root): ./build-rootfs.sh oneplus-fajita
# Precisa rodar binários aarch64: host ARM64 ou qemu-user-static com binfmt registrado.
. "$(dirname "$0")/common.sh"
need curl bsdtar md5sum mkfs.ext4 chroot mount
[ "$(id -u)" = 0 ] || die "rode como root (precisa de chroot e de preservar donos dos arquivos)"
[ -d "$OUT/modules" ] || die "rode build-kernel.sh $DEVICE primeiro"
[ "$(uname -m)" = aarch64 ] || [ -e /proc/sys/fs/binfmt_misc/qemu-aarch64 ] ||
    die "sem suporte a aarch64: instale qemu-user-static + binfmt (Arch: qemu-user-static-binfmt)"

ALARM=http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz
tarball=$(fetch "$ALARM" ArchLinuxARM-aarch64-latest.tar.gz)
md5=$(fetch "$ALARM.md5" ArchLinuxARM-aarch64-latest.tar.gz.md5)
(cd "$CACHE" && md5sum -c "$md5") || die "md5 do Arch Linux ARM não confere (apague $CACHE e baixe de novo)"

ROOT="$OUT/rootfs"
umount -R "$ROOT" 2>/dev/null || true
rm -rf "$ROOT"
mkdir -p "$ROOT"
bsdtar -xpf "$tarball" -C "$ROOT"

cleanup() { umount -R "$ROOT/proc" "$ROOT/sys" "$ROOT/dev" 2>/dev/null || true; }
trap cleanup EXIT
mount -t proc proc "$ROOT/proc"
mount --rbind /sys "$ROOT/sys"
mount --rbind /dev "$ROOT/dev"
rm -f "$ROOT/etc/resolv.conf"
cp -L /etc/resolv.conf "$ROOT/etc/resolv.conf"

# Kernel e firmware nossos no lugar do kernel genérico do ALARM
cp -a "$OUT"/modules/lib/modules/. "$ROOT/usr/lib/modules/"
fwtar=$(fetch "$FIRMWARE_URL" "firmware-$DEVICE.tar.gz")
mkdir -p "$ROOT/usr/lib/firmware"
bsdtar -xf "$fwtar" -C "$ROOT/usr/lib" --strip-components 2 '*/lib/firmware'

chroot "$ROOT" /bin/bash -eu <<'CHROOT'
pacman-key --init
pacman-key --populate archlinuxarm
pacman -Rdd --noconfirm linux-aarch64 || true
pacman -Syu --noconfirm --needed \
    base-devel git sudo openssh networkmanager modemmanager bluez bluez-utils \
    flatpak pipewire wireplumber linux-firmware
systemctl enable sshd NetworkManager
# henchman: o pau-mandado oficial. É só um apelido; o pacman continua lá pro makepkg e pros helpers do AUR
ln -sf /usr/bin/pacman /usr/local/bin/henchman
echo indoors > /etc/hostname
echo 'LABEL=indoors-root / ext4 defaults,noatime 0 1' > /etc/fstab
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/wheel
# Rede USB fixa: o PC conversa com o celular em 172.16.42.1
cat > /etc/NetworkManager/system-connections/usb0.nmconnection <<NM
[connection]
id=usb0
type=ethernet
interface-name=usb0
[ipv4]
method=manual
address1=172.16.42.1/24
[ipv6]
method=ignore
NM
chmod 600 /etc/NetworkManager/system-connections/usb0.nmconnection
pacman -Scc --noconfirm
CHROOT

cleanup
trap - EXIT
rm -f "$ROOT/etc/resolv.conf"
ln -s /run/systemd/resolve/stub-resolv.conf "$ROOT/etc/resolv.conf"

rm -f "$OUT/rootfs.img"
mkfs.ext4 -q -L indoors-root -b "$ROOTFS_BLOCKSIZE" -d "$ROOT" "$OUT/rootfs.img" "$ROOTFS_SIZE"
echo "ok: $OUT/rootfs.img  (login: alarm/alarm, root/root -> TROQUE as senhas)"
