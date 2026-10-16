# Funções comuns. Uso: . "$(dirname "$0")/common.sh" <aparelho>
set -eu

OS_DIR=$(cd "$(dirname "$0")/.." && pwd)
DEVICE=${1:-}
[ -n "$DEVICE" ] || { echo "uso: $0 <aparelho>  (ex.: oneplus-fajita)"; ls "$OS_DIR/devices"; exit 1; }
[ -f "$OS_DIR/devices/$DEVICE/device.conf" ] || { echo "aparelho desconhecido: $DEVICE"; exit 1; }
. "$OS_DIR/devices/$DEVICE/device.conf"

CACHE="$OS_DIR/cache"
OUT="$OS_DIR/out/$DEVICE"
mkdir -p "$CACHE" "$OUT"

die() { echo "erro: $*" >&2; exit 1; }
# Confere tudo de uma vez e diz o pacote de cada comando que falta
need() {
    falta=
    for c in "$@"; do command -v "$c" >/dev/null || falta="$falta $c"; done
    [ -z "$falta" ] && return 0
    echo "erro: faltam comandos no PC:" >&2
    for c in $falta; do
        case $c in
            ld.lld) p="lld" ;;
            depmod) p="kmod" ;;
            mkfs.ext4) p="e2fsprogs" ;;
            bsdtar) p="libarchive (Arch) / libarchive-tools (Debian/Ubuntu) / bsdtar (Fedora)" ;;
            mountpoint|mount) p="util-linux" ;;
            md5sum|chroot) p="coreutils" ;;
            ar) p="binutils" ;;
            python3) p="python (Arch) / python3 (Debian/Ubuntu/Fedora)" ;;
            fastboot) p="android-tools (Arch/Fedora) / fastboot (Debian/Ubuntu)" ;;
            qemu-system-aarch64) p="qemu-system-aarch64 (Arch/Fedora) / qemu-system-arm (Debian/Ubuntu)" ;;
            *) p="$c" ;;
        esac
        echo "  $c  ->  pacote: $p" >&2
    done
    echo "lista completa em os/README.md, seção \"Preparar o PC\"" >&2
    exit 1
}

# Baixa uma vez para o cache e devolve o caminho
fetch() {
    f="$CACHE/$2"
    [ -s "$f" ] || { curl -fL --retry 3 -o "$f.part" "$1" && mv "$f.part" "$f"; } >&2
    echo "$f"
}

pmaports_file() {
    fetch "https://gitlab.postmarketos.org/postmarketOS/pmaports/-/raw/$PMAPORTS_REF/$1" "pmaports-${PMAPORTS_REF%"${PMAPORTS_REF#???????}"}-$(basename "$1")"
}
