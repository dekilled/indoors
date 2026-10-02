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

## Ligar tudo (jeito simples)

1. Uma vez só, dentro do Ubuntu:
   `apt install -y python3 python3-websockets tigervnc-standalone-server xterm mousepad fonts-dejavu-core`
2. Copie o repositório inteiro para o celular (pastas `linux/`, `bridge/` e `web/` juntas).
3. Como root, dentro da pasta `linux/`:  `sh indoors.sh`
4. Ele imprime um link `http://127.0.0.1:8080/#token=...` : abra no Chrome do celular.
   O terminal conecta sozinho.

A pasta `web/` é o Indoors já compilado (gerada por `npm run build:web`).
Por padrão tudo escuta só em 127.0.0.1; o token é obrigatório.

## Apps gráficos (Linux GUI dentro do Indoors)

Os ícones 🐧 (xterm) e 📝 (Mousepad) na barra abrem apps X11 do Ubuntu numa janela do Indoors.
Cada janela = um Xvnc próprio (socket Unix 0600, sem porta TCP) + o app, ligados à bridge.
Fechou a janela, o app e o display são encerrados.

Para liberar outro app, adicione-o em `GUI_APPS` no `bridge/bridge.py` e em `src/stores/windows.js`.
O cliente escolhe um NOME da lista; nunca manda comando arbitrário.
Sem aceleração de GPU (render por software).
