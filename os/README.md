# Indoors OS: Arch Linux de verdade no celular

A ideia é um Linux nativo (sem chroot dentro do Android) que roda pacman, AUR, Flatpak e APK.
O que for fechado a gente reaproveita do Android ou contorna com driver mínimo.

> Status: **nada testado em hardware ainda.** No PC já funciona: o kernel do 6T (7.1-rc1 sdm845) compila
> e o boot.img sai com o header certo. No QEMU, o initramfs acha o rootfs pelo label e faz `switch_root`
> (ou cai no modo debug). `build-rootfs.sh` ainda não foi rodado: precisa de host com binfmt aarch64.

## Aparelhos

| Aparelho | SoC | Caminho | Papel |
|---|---|---|---|
| OnePlus 6T (`oneplus-fajita`) | SDM845 | mainline | laboratório: tudo é desenvolvido aqui primeiro |
| Lenovo Z5 Pro GT (`lenovo-z5progt`) | SM8150 | Halium (depois mainline) | alvo principal: nunca bootou Linux |
| Galaxy Z Flip3 | SM8350 | a decidir | prova de que a base é portável |
| Note10+ / Note20 Ultra | Exynos | — | banco de reserva |

**mainline**: kernel oficial com patches do [sdm845-mainline](https://gitlab.com/sdm845-mainline/linux). Os drivers são livres; só firmware é blob.
**Halium**: kernel do LineageOS + [libhybris](https://github.com/libhybris/libhybris), que carrega os drivers `.so` do Android dentro do Linux.

## Como as peças se encaixam

```
boot.img = Image.gz + dtb + initramfs (busybox + init do Indoors)
   │  init: carrega módulos, sobe rede USB (172.16.42.1), procura LABEL=indoors-root
   ▼
rootfs Arch Linux ARM (partição userdata)
   ├── pacman + AUR (base-devel, git)
   ├── Flatpak
   └── Waydroid (APK)      ← etapa 3
```

Sem rootfs (ou com `indoors.debug` na cmdline) o init vira um shell por telnet pela USB.
Assim dá para diagnosticar sem tela.

## Etapas

1. **Primeiro boot no 6T sem gravar nada**: kernel + initramfs via `fastboot boot`, shell pela USB.
2. **Arch instalado no 6T**: rootfs na userdata, SSH, NetworkManager, Flatpak.
3. **Celular de verdade**: Phosh ou Plasma Mobile, modem (rmtfs/pd-mapper/tqftpserv/qrtr), Wi-Fi, áudio, Waydroid, BlackArch.
4. **Z5 Pro GT via Halium**: precisa do kernel e do device tree do LineageOS dele.
5. **Z Flip3.**

## Usando (OnePlus 6T)

Dependências no PC (Arch): `clang lld bison flex bc perl python kmod cpio xz zstd libarchive binutils android-tools e2fsprogs qemu-user-static qemu-user-static-binfmt qemu-system-aarch64`.
No Debian/Ubuntu: `clang lld bison flex bc kmod zstd libssl-dev libelf-dev cpio xz-utils libarchive-tools binutils adb fastboot e2fsprogs qemu-user-static qemu-system-arm`.

```sh
cd os/scripts
./backup.sh                                     # ANTES de tudo, com o Android ainda ligado e root
./build-kernel.sh oneplus-fajita                # ~30-60 min na primeira vez
./build-initramfs.sh oneplus-fajita
./build-boot.sh oneplus-fajita indoors.debug    # debug: para no shell, não procura rootfs

./test-qemu.sh oneplus-fajita                   # opcional: testa o initramfs no QEMU antes

# celular em modo fastboot (desligado, Volume+ + Power)
./flash.sh oneplus-fajita test                  # boot só na RAM; reiniciou, voltou ao Android
telnet 172.16.42.1                              # se o PC não pegar IP: 172.16.42.2/24 na interface USB
```

Se o shell aparecer, a etapa 1 está pronta. Para instalar de verdade (**apaga o Android**):

```sh
sudo ./build-rootfs.sh oneplus-fajita
./build-boot.sh oneplus-fajita
./flash.sh oneplus-fajita install
ssh alarm@172.16.42.1                           # senha alarm; troque as senhas de alarm e root
```

Para voltar ao Android: reinstale o OxygenOS pelo MSM Download Tool ou grave as imagens do `backup/`.

## Avisos

- `backup.sh` salva `modemst1`, `modemst2`, `fsg` e `persist`. Elas são **únicas de cada aparelho** (IMEI, calibração). Se perder, não tem de onde tirar outra. Guarde em mais de um lugar.
- Se o `fastboot boot` der tela preta, confira primeiro o telnet. A tela pode só estar demorando. Depois veja a [página do aparelho no wiki do postmarketOS](https://wiki.postmarketos.org/wiki/OnePlus_6_(oneplus-enchilada)), que lista os detalhes de bootloader do 6/6T.
- Os valores de cada aparelho (offsets, kernel, firmware) ficam em `devices/<aparelho>/device.conf`, tirados do [pmaports](https://gitlab.postmarketos.org/postmarketOS/pmaports) num commit fixo.
