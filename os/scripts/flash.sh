#!/bin/sh
# Coloca o Indoors OS no aparelho (em modo fastboot)
#   ./flash.sh oneplus-fajita test      boot.img vai só pra RAM, nada é gravado
#   ./flash.sh oneplus-fajita install   grava boot e rootfs (APAGA O ANDROID)
. "$(dirname "$0")/common.sh"
need fastboot
mode=${2:-test}
[ -f "$OUT/boot.img" ] || die "rode build-boot.sh $DEVICE primeiro"
case $mode in
    test)
        fastboot boot "$OUT/boot.img" ;;
    install)
        [ -n "${ROOTFS_PARTITION:-}" ] || die "$DEVICE_NAME ainda não tem instalação (só o modo test)"
        [ -f "$OUT/rootfs.img" ] || die "rode build-rootfs.sh $DEVICE primeiro"
        echo "Isto APAGA o Android e todos os dados de $DEVICE_NAME."
        echo "Fez o backup (scripts/backup.sh)? Digite APAGAR para continuar:"
        read -r ok
        [ "$ok" = APAGAR ] || die "cancelado"
        fastboot flash boot "$OUT/boot.img"
        fastboot flash "$ROOTFS_PARTITION" "$OUT/rootfs.img"
        fastboot reboot ;;
    *) die "modo desconhecido: $mode (use test ou install)" ;;
esac
