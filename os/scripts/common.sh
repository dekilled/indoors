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
need() { for c in "$@"; do command -v "$c" >/dev/null || die "falta o comando '$c' (veja os/README.md)"; done; }

# Baixa uma vez para o cache e devolve o caminho
fetch() {
    f="$CACHE/$2"
    [ -s "$f" ] || { curl -fL --retry 3 -o "$f.part" "$1" && mv "$f.part" "$f"; } >&2
    echo "$f"
}

pmaports_file() {
    fetch "https://gitlab.postmarketos.org/postmarketOS/pmaports/-/raw/$PMAPORTS_REF/$1" "pmaports-${PMAPORTS_REF%"${PMAPORTS_REF#???????}"}-$(basename "$1")"
}
