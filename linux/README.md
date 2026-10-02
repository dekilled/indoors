# Linux (chroot) para Android com root

Testado em: nada ainda. Alvo: Galaxy Note 10+ (KernelSU, kernel 4.14, Android 14, SELinux Enforcing).
Kernel precisa de: NAMESPACES, PID_NS, UTS_NS, IPC_NS (opcional NET_NS).

1. Baixe `ubuntu-base-*-base-arm64.tar.gz` e coloque em /sdcard/Download.
2. Copie `linux/` para o celular (ex.: /data/local/indoors/bin) e, como root:
       sh setup.sh /sdcard/Download/<arquivo>.tar.gz
       sh start.sh
3. Dentro do Linux: `apt update && apt install -y sudo nano`.

Se algo falhar, copie a mensagem de erro: o SELinux Enforcing é o suspeito nº 1
(teste com `setenforce 0` só para diagnosticar).
