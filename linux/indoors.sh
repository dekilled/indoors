#!/system/bin/sh
# UM comando que liga tudo: copia o Indoors para dentro do Ubuntu e inicia.
# Uso (como root), de dentro da pasta linux/:   sh indoors.sh
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT=/data/local/indoors/ubuntu
[ -d "$ROOT/bin" ] || { echo "Ubuntu não instalado: rode setup.sh antes"; exit 1; }
[ -d "$HERE/../web" ] || { echo "pasta web/ não encontrada ao lado de linux/"; exit 1; }

mkdir -p "$ROOT/opt/indoors"
cp "$HERE/../bridge/bridge.py" "$ROOT/opt/indoors/bridge.py"
rm -rf "$ROOT/opt/indoors/web"
cp -r "$HERE/../web" "$ROOT/opt/indoors/web"

exec sh "$HERE/start.sh" python3 /opt/indoors/bridge.py
