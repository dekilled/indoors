#!/bin/sh
# Compila kernel, dtb e módulos. Saída em os/out/<aparelho>/
# Uso: ./build-kernel.sh oneplus-fajita
. "$(dirname "$0")/common.sh"
need curl tar make clang ld.lld bison flex bc perl python3 zstd depmod
[ "$DEVICE_METHOD" = mainline ] || die "$DEVICE usa '$DEVICE_METHOD'; por enquanto só mainline é suportado"

SRC="$CACHE/linux-$KERNEL_TAG"
if [ ! -d "$SRC" ]; then
    tarball=$(fetch "$KERNEL_URL" "linux-$KERNEL_TAG.tar.gz")
    tar -xzf "$tarball" -C "$CACHE"
fi

cp "$(pmaports_file "$KERNEL_CONFIG")" "$SRC/.config"
# Clang faz cross-compile sozinho, sem precisar de gcc aarch64
KMAKE="make -C $SRC ARCH=arm64 LLVM=1 -j$(nproc)"
$KMAKE olddefconfig
$KMAKE Image.gz modules dtbs

rm -rf "$OUT/modules"
$KMAKE modules_install INSTALL_MOD_PATH="$OUT/modules" INSTALL_MOD_STRIP=1
rm -f "$OUT"/modules/lib/modules/*/build "$OUT"/modules/lib/modules/*/source
cp "$SRC/arch/arm64/boot/Image.gz" "$OUT/Image.gz"
cp "$SRC/arch/arm64/boot/dts/$KERNEL_DTB.dtb" "$OUT/device.dtb"
cp "$SRC/include/config/kernel.release" "$OUT/kernel.release"
echo "ok: kernel $(cat "$OUT/kernel.release") em $OUT"
