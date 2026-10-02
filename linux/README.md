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

## Ponte do terminal (bridge)

Dentro do Ubuntu: `apt install -y python3 python3-websockets`

Copie `bridge/bridge.py` para o rootfs e inicie o Linux já rodando a ponte:

    cp bridge/bridge.py /data/local/indoors/ubuntu/root/bridge.py
    sh start.sh python3 /root/bridge.py

Ela imprime o token (também fica em /root/.indoors-token). No app Indoors, abra o
Terminal, informe `127.0.0.1:8765` + token e clique em Conectar.
Por padrão escuta só em 127.0.0.1. Para testar a partir do PC na mesma rede:
`INDOORS_BIND=0.0.0.0` (o token continua obrigatório; use só em rede confiável).
