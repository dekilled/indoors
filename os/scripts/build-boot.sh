#!/bin/sh
# Junta kernel + dtb + initramfs no boot.img
# Uso: ./build-boot.sh oneplus-fajita [indoors.debug]
. "$(dirname "$0")/common.sh"
need python3
[ -f "$OUT/initramfs.cpio.gz" ] || die "rode build-initramfs.sh $DEVICE primeiro"
shift
cat "$OUT/Image.gz" "$OUT/device.dtb" > "$OUT/Image.gz-dtb"
python3 "$OS_DIR/scripts/mkbootimg.py" \
    --kernel "$OUT/Image.gz-dtb" --ramdisk "$OUT/initramfs.cpio.gz" \
    --cmdline "$BOOT_CMDLINE root=LABEL=indoors-root $*" \
    --pagesize "$BOOT_PAGESIZE" --base "$BOOT_BASE" \
    --kernel_offset "$BOOT_KERNEL_OFFSET" --ramdisk_offset "$BOOT_RAMDISK_OFFSET" \
    --second_offset "$BOOT_SECOND_OFFSET" --tags_offset "$BOOT_TAGS_OFFSET" \
    --output "$OUT/boot.img"
echo "ok: $OUT/boot.img ($(du -h "$OUT/boot.img" | cut -f1))"
