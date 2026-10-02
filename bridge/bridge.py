#!/usr/bin/env python3
"""Ponte terminal: WebSocket <-> PTY (bash). Roda DENTRO do Ubuntu.

Protocolo: mensagem binária = bytes de entrada do teclado;
           mensagem texto  = JSON de controle, ex.: {"type":"resize","cols":80,"rows":24}.
Saída do terminal vai ao cliente como mensagem binária.
Autenticação: ?token=... na URL (token em ~/.indoors-token ou $INDOORS_TOKEN).

Rotas (mesma porta):
  /          terminal (PTY + bash)
  /vnc?app=X app gráfico X (da lista GUI_APPS) num display próprio, via RFB/VNC
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

# Apps gráficos que o Indoors pode abrir. Só o que está aqui roda: o cliente
# escolhe um NOME, nunca um comando. (Semente do futuro manifesto de permissões.)
GUI_APPS = {
    "xterm": ["xterm", "-fa", "Monospace", "-fs", "13"],
    "mousepad": ["mousepad"],
}
_displays_in_use = set()


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


def request_info(ws):
    # websockets <14 expõe ws.path; >=14 expõe ws.request.path
    path = getattr(ws, "path", None) or ws.request.path
    u = urlparse(path)
    return u.path, parse_qs(u.query)


async def handler(ws):
    route, query = request_info(ws)
    supplied = query.get("token", [""])[0]
    if not secrets.compare_digest(supplied, TOKEN):
        await ws.close(4401, "unauthorized")
        return
    if route == "/vnc":
        await gui_session(ws, query)
    else:
        await terminal_session(ws)


async def terminal_session(ws):
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


def clamp(value, lo, hi, default):
    try:
        return max(lo, min(hi, int(value)))
    except (TypeError, ValueError):
        return default


async def stop(proc):
    if proc and proc.returncode is None:
        proc.terminate()
        try:
            await asyncio.wait_for(proc.wait(), 2)
        except asyncio.TimeoutError:
            proc.kill()
            await proc.wait()


async def gui_session(ws, query):
    """Um app = um Xvnc próprio (socket Unix 0600, sem TCP) + o app, ligados ao WebSocket."""
    name = query.get("app", [""])[0]
    cmd = GUI_APPS.get(name)
    if not cmd:
        await ws.close(4404, "app não permitido")
        return
    width = clamp(query.get("w", [""])[0], 320, 1920, 800)
    height = clamp(query.get("h", [""])[0], 240, 1200, 500)

    num = next(n for n in range(10, 200) if n not in _displays_in_use)
    _displays_in_use.add(num)
    sock = f"/tmp/indoors-vnc-{num}.sock"
    xvnc = app = writer = None
    pumps = []
    try:
        xvnc = await asyncio.create_subprocess_exec(
            "Xvnc", f":{num}", "-geometry", f"{width}x{height}", "-depth", "24",
            "-rfbport", "-1", "-rfbunixpath", sock, "-rfbunixmode", "0600",
            "-SecurityTypes", "None", "-nolisten", "tcp",
            stdout=asyncio.subprocess.DEVNULL, stderr=asyncio.subprocess.DEVNULL)
        for _ in range(50):
            if os.path.exists(sock) or xvnc.returncode is not None:
                break
            await asyncio.sleep(0.1)
        if not os.path.exists(sock):
            await ws.close(1011, "Xvnc não iniciou")
            return

        env = dict(os.environ, DISPLAY=f":{num}", HOME=os.environ.get("HOME", "/root"))
        app = await asyncio.create_subprocess_exec(
            *cmd, env=env, stdout=asyncio.subprocess.DEVNULL, stderr=asyncio.subprocess.DEVNULL)

        reader, writer = await asyncio.open_unix_connection(sock)

        async def to_client():
            while True:
                data = await reader.read(65536)
                if not data:
                    break
                await ws.send(data)
            await ws.close(1000, "display encerrado")

        async def to_server():
            async for msg in ws:
                if isinstance(msg, bytes):
                    writer.write(msg)
                    await writer.drain()

        async def app_exit():
            await app.wait()
            await ws.close(1000, "app encerrado")

        pumps = [asyncio.create_task(c()) for c in (to_client, to_server, app_exit)]
        await asyncio.wait(pumps, return_when=asyncio.FIRST_COMPLETED)
    except websockets.ConnectionClosed:
        pass
    finally:
        for t in pumps:
            t.cancel()
        if writer:
            writer.close()
        await stop(app)
        await stop(xvnc)
        try:
            os.unlink(sock)
        except FileNotFoundError:
            pass
        _displays_in_use.discard(num)


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
    async with websockets.serve(handler, HOST, PORT, subprotocols=["binary"]):
        print(f"[indoors-bridge] terminal em ws://{HOST}:{PORT}")
        if web:
            print("\n>>> Abra este link no navegador do celular:")
            print(f"    http://127.0.0.1:{WEB_PORT}/#token={TOKEN}\n", flush=True)
        else:
            print(f"[indoors-bridge] token: {TOKEN}", flush=True)
        await asyncio.Future()


if __name__ == "__main__":
    asyncio.run(main())
