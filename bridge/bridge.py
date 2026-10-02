#!/usr/bin/env python3
"""Ponte terminal: WebSocket <-> PTY (bash). Roda DENTRO do Ubuntu.

Protocolo: mensagem binária = bytes de entrada do teclado;
           mensagem texto  = JSON de controle, ex.: {"type":"resize","cols":80,"rows":24}.
Saída do terminal vai ao cliente como mensagem binária.
Autenticação: ?token=... na URL (token em ~/.indoors-token ou $INDOORS_TOKEN).
"""
import asyncio
import fcntl
import functools
import http.server
import json
import os
import pty
import secrets
import signal
import struct
import termios
import threading
from urllib.parse import parse_qs, urlparse

import websockets

HOST = os.environ.get("INDOORS_BIND", "127.0.0.1")
PORT = int(os.environ.get("INDOORS_PORT", "8765"))
SHELL = os.environ.get("INDOORS_SHELL", "/bin/bash")
WEB_PORT = int(os.environ.get("INDOORS_WEB_PORT", "8080"))
WEB_DIR = os.environ.get("INDOORS_WEB", os.path.join(os.path.dirname(os.path.abspath(__file__)), "web"))
TOKEN_FILE = os.path.expanduser("~/.indoors-token")


def load_token():
    token = os.environ.get("INDOORS_TOKEN")
    if token:
        return token
    if os.path.exists(TOKEN_FILE):
        with open(TOKEN_FILE) as f:
            return f.read().strip()
    token = secrets.token_urlsafe(24)
    fd = os.open(TOKEN_FILE, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        f.write(token)
    return token


TOKEN = load_token()


def set_winsize(fd, rows, cols):
    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))


async def handler(ws):
    # websockets <14 expõe ws.path; >=14 expõe ws.request.path
    path = getattr(ws, "path", None) or ws.request.path
    supplied = parse_qs(urlparse(path).query).get("token", [""])[0]
    if not secrets.compare_digest(supplied, TOKEN):
        await ws.close(4401, "unauthorized")
        return

    pid, fd = pty.fork()
    if pid == 0:
        os.environ.update(TERM="xterm-256color", HOME=os.environ.get("HOME", "/root"))
        os.execvp(SHELL, [SHELL, "-l"])

    loop = asyncio.get_running_loop()
    out = asyncio.Queue()

    def on_readable():
        try:
            data = os.read(fd, 4096)
        except OSError:
            data = b""
        out.put_nowait(data or None)
        if not data:
            loop.remove_reader(fd)

    loop.add_reader(fd, on_readable)

    async def pump_output():
        while True:
            data = await out.get()
            if data is None:
                await ws.close(1000, "shell encerrado")
                return
            await ws.send(data)

    pump = asyncio.create_task(pump_output())
    try:
        async for msg in ws:
            if isinstance(msg, bytes):
                os.write(fd, msg)
            else:
                ctl = json.loads(msg)
                if ctl.get("type") == "resize":
                    set_winsize(fd, int(ctl["rows"]), int(ctl["cols"]))
    except websockets.ConnectionClosed:
        pass
    finally:
        pump.cancel()
        try:
            loop.remove_reader(fd)
        except Exception:
            pass
        try:
            os.kill(pid, signal.SIGHUP)
            await asyncio.sleep(0.5)
            if os.waitpid(pid, os.WNOHANG) == (0, 0):
                os.kill(pid, signal.SIGKILL)
                os.waitpid(pid, 0)
        except (ProcessLookupError, ChildProcessError):
            pass
        os.close(fd)


class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass


def serve_web():
    """Serve o próprio Indoors (arquivos estáticos) para o navegador do celular."""
    if not os.path.isdir(WEB_DIR):
        print(f"[indoors-bridge] pasta web não encontrada: {WEB_DIR}", flush=True)
        return False
    handler_cls = functools.partial(QuietHandler, directory=WEB_DIR)
    srv = http.server.ThreadingHTTPServer((HOST, WEB_PORT), handler_cls)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    return True


async def main():
    web = serve_web()
    async with websockets.serve(handler, HOST, PORT):
        print(f"[indoors-bridge] terminal em ws://{HOST}:{PORT}")
        if web:
            print("\n>>> Abra este link no navegador do celular:")
            print(f"    http://127.0.0.1:{WEB_PORT}/#token={TOKEN}\n", flush=True)
        else:
            print(f"[indoors-bridge] token: {TOKEN}", flush=True)
        await asyncio.Future()


if __name__ == "__main__":
    asyncio.run(main())
