#!/usr/bin/env bash
# ==============================================================================
#  Valheim dedicated server installer para Oracle Cloud
#  VM.Standard.A1.Flex (ARM64) + Ubuntu 22.04
#
#  Estrategia: Box64 (emulador x86_64 -> ARM64) + SteamCMD + Valheim dedicated.
#  Idempotente: podes volver a correrlo si algo falla.
# ==============================================================================
set -euo pipefail

# ------- helpers -------
log()  { echo -e "\033[1;32m[+] $*\033[0m"; }
warn() { echo -e "\033[1;33m[!] $*\033[0m"; }
err()  { echo -e "\033[1;31m[x] $*\033[0m" >&2; }

if [[ $EUID -ne 0 ]]; then
  err "Corré este script con sudo (sudo ./install.sh)"
  exit 1
fi

# Auto-normalizar CRLF -> LF si este script o los vecinos vienen de Windows.
# (Evita "/usr/bin/env: 'bash\r': No such file or directory" en próximos runs.)
SELF="${BASH_SOURCE[0]}"
SELF_DIR="$(cd "$(dirname "$SELF")" && pwd)"
if grep -qlI $'\r' "$SELF_DIR"/*.sh "$SELF_DIR"/*.service 2>/dev/null; then
  warn "Detecté finales de línea CRLF — los normalizo a LF..."
  for f in "$SELF_DIR"/*.sh "$SELF_DIR"/*.service; do
    [[ -f "$f" ]] && sed -i 's/\r$//' "$f"
  done
  log "Normalizado. Volvé a correr: sudo ./install.sh"
  exit 0
fi

ARCH="$(dpkg --print-architecture)"
if [[ "$ARCH" != "arm64" ]]; then
  warn "Esta guia esta pensada para arm64 (detecte: $ARCH). Continuo igual, pero revisa."
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ------- input -------
read -rp "Nombre del servidor (aparece en la lista pública): " VH_NAME
read -rp "Nombre del mundo (archivo del mapa, ej: Midgard): "  VH_WORLD
while true; do
  read -rsp "Contraseña del servidor (>=5 chars, no puede contener el nombre ni el mundo): " VH_PASS
  echo
  if [[ ${#VH_PASS} -lt 5 ]]; then
    warn "Muy corta, probá de nuevo."
    continue
  fi
  if [[ "$VH_PASS" == *"$VH_NAME"* ]] || [[ "$VH_PASS" == *"$VH_WORLD"* ]]; then
    warn "La contraseña no puede contener el nombre del servidor ni el del mundo."
    continue
  fi
  break
done

# ------- usuario de servicio -------
if ! id -u valheim >/dev/null 2>&1; then
  log "Creando usuario de sistema 'valheim'..."
  useradd -m -s /bin/bash valheim
else
  log "Usuario 'valheim' ya existe."
fi
VHOME="/home/valheim"

# ------- paquetes base -------
log "Actualizando sistema e instalando dependencias base..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y --no-install-recommends \
  ca-certificates curl wget gnupg lsb-release software-properties-common \
  iptables iptables-persistent netfilter-persistent \
  tar xz-utils unzip locales \
  libc6 libstdc++6 libsdl2-2.0-0 \
  cron

# Habilitar multiverse/universe (SteamCMD vive en multiverse)
add-apt-repository -y universe
add-apt-repository -y multiverse

# Habilitar armhf (algunas libs auxiliares que SteamCMD baja lo requieren en ARM)
if ! dpkg --print-foreign-architectures | grep -q armhf; then
  log "Habilitando arquitectura armhf..."
  dpkg --add-architecture armhf
fi
apt-get update -y

# ------- Box64 + Box86 (repos oficiales de Ryanfortner) -------
# Box64 corre binarios x86_64 (Valheim server).
# Box86 corre binarios x86 32-bit (SteamCMD, que es 32 bits).
log "Instalando Box64 y Box86..."
mkdir -p /etc/apt/keyrings

BOX64_KEY="/etc/apt/keyrings/box64.gpg"
BOX64_LIST="/etc/apt/sources.list.d/box64.list"
if [[ ! -f "$BOX64_KEY" ]]; then
  curl -fsSL https://ryanfortner.github.io/box64-debs/KEY.gpg \
    | gpg --dearmor -o "$BOX64_KEY"
fi
if [[ ! -f "$BOX64_LIST" ]]; then
  echo "deb [signed-by=$BOX64_KEY] https://ryanfortner.github.io/box64-debs/debian ./" \
    > "$BOX64_LIST"
fi

BOX86_KEY="/etc/apt/keyrings/box86.gpg"
BOX86_LIST="/etc/apt/sources.list.d/box86.list"
if [[ ! -f "$BOX86_KEY" ]]; then
  curl -fsSL https://ryanfortner.github.io/box86-debs/KEY.gpg \
    | gpg --dearmor -o "$BOX86_KEY"
fi
if [[ ! -f "$BOX86_LIST" ]]; then
  echo "deb [signed-by=$BOX86_KEY] https://ryanfortner.github.io/box86-debs/debian ./" \
    > "$BOX86_LIST"
fi

apt-get update -y
apt-get install -y box64 || apt-get install -y box64-generic-arm
# box86 es un "virtual package" — hay que pedir una variante concreta.
apt-get install -y box86-generic-arm:armhf || apt-get install -y box86-generic-arm || apt-get install -y box86

# Libs armhf que necesita Box86 para correr SteamCMD (32-bit) correctamente.
log "Instalando libs armhf (runtime de Box86 + SteamCMD)..."
apt-get install -y --no-install-recommends \
  libc6:armhf libstdc++6:armhf \
  libcurl4-gnutls-dev:armhf \
  libncurses6:armhf libtinfo6:armhf libsdl2-2.0-0:armhf || \
apt-get install -y --no-install-recommends \
  libc6:armhf libstdc++6:armhf libcurl4-gnutls-dev:armhf

# ------- SteamCMD -------
# En arm64 NO existe el paquete apt `steamcmd`. Bajamos el tarball oficial de Valve
# y lo corremos bajo Box86 (SteamCMD es un binario x86 de 32 bits).
log "Descargando SteamCMD desde Valve..."
STEAMCMD_DIR="$VHOME/steamcmd"
sudo -u valheim mkdir -p "$STEAMCMD_DIR"
if [[ ! -x "$STEAMCMD_DIR/linux32/steamcmd" ]]; then
  sudo -u valheim bash -c "cd '$STEAMCMD_DIR' && \
    curl -fsSL https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz \
    | tar zxf -"
fi

# Wrapper: usamos steamcmd.sh (el wrapper oficial de Valve) y dejamos que
# binfmt_misc + Box86 se encarguen transparentemente del binario x86.
# Invocar "box86 ./linux32/steamcmd" directamente rompe el auto-update interno
# de SteamCMD (pierde LD_LIBRARY_PATH en el re-exec).
cat > "$VHOME/steamcmd_box86.sh" <<'EOF'
#!/usr/bin/env bash
set -e
export HOME=/home/valheim
export BOX86_LD_LIBRARY_PATH="/lib/arm-linux-gnueabihf:/usr/lib/arm-linux-gnueabihf:${BOX86_LD_LIBRARY_PATH:-}"
cd /home/valheim/steamcmd
exec ./steamcmd.sh "$@"
EOF
chmod +x "$VHOME/steamcmd_box86.sh"
chown valheim:valheim "$VHOME/steamcmd_box86.sh"

rm -f "$VHOME/steamcmd_box64.sh"

# ------- Descargar/actualizar Valheim dedicated server (AppID 896660) -------
# Importante: hacemos esto DESPUES de instalar systemd, asi si la descarga falla
# temporalmente el usuario puede reintentar con update.sh sin reinstalar todo.
SERVER_DIR="$VHOME/valheim-server"
sudo -u valheim mkdir -p "$SERVER_DIR"

# ------- Script de arranque -------
START_SCRIPT="$VHOME/start_valheim.sh"
log "Generando $START_SCRIPT ..."
cat > "$START_SCRIPT" <<EOF
#!/usr/bin/env bash
# Autogenerado por install.sh — podes editarlo y hacer: sudo systemctl restart valheim-server
set -e
export HOME=/home/valheim
export templdpath="\$LD_LIBRARY_PATH"
export LD_LIBRARY_PATH="$SERVER_DIR/linux64:\$LD_LIBRARY_PATH"
export SteamAppId=892970

cd "$SERVER_DIR"
exec box64 ./valheim_server.x86_64 \\
  -nographics -batchmode \\
  -name "$VH_NAME" \\
  -port 2456 \\
  -world "$VH_WORLD" \\
  -password "$VH_PASS" \\
  -public 1 \\
  -savedir "\$HOME/valheim-data"

export LD_LIBRARY_PATH="\$templdpath"
EOF
chmod 750 "$START_SCRIPT"
chown valheim:valheim "$START_SCRIPT"

# ------- Script de update -------
cat > "$VHOME/update.sh" <<EOF
#!/usr/bin/env bash
set -e
exec "$VHOME/steamcmd_box86.sh" \\
  +@sSteamCmdForcePlatformType linux \\
  +force_install_dir "$SERVER_DIR" \\
  +login anonymous \\
  +app_update 896660 validate \\
  +quit
EOF
chmod +x "$VHOME/update.sh"
chown valheim:valheim "$VHOME/update.sh"

# ------- Backup diario -------
BACKUP_DIR="$VHOME/backups"
sudo -u valheim mkdir -p "$BACKUP_DIR"
cat > /etc/cron.daily/valheim-backup <<'EOF'
#!/usr/bin/env bash
set -e
SRC="/home/valheim/valheim-data"
DST="/home/valheim/backups"
TS="$(date +%Y%m%d-%H%M%S)"
[[ -d "$SRC" ]] || exit 0
sudo -u valheim tar -czf "$DST/valheim-$TS.tar.gz" -C "$(dirname "$SRC")" "$(basename "$SRC")"
# Retener los últimos 14 backups
ls -1t "$DST"/valheim-*.tar.gz 2>/dev/null | tail -n +15 | xargs -r rm -f
EOF
chmod +x /etc/cron.daily/valheim-backup

# ------- systemd unit -------
log "Instalando unidad systemd..."
install -m 0644 "$SCRIPT_DIR/valheim-server.service" /etc/systemd/system/valheim-server.service
systemctl daemon-reload
systemctl enable valheim-server.service

# ------- Firewall (iptables) -------
log "Abriendo puertos UDP 2456-2458 en iptables..."
if ! iptables -C INPUT -p udp --dport 2456:2458 -j ACCEPT 2>/dev/null; then
  iptables -I INPUT 6 -m state --state NEW -p udp --dport 2456:2458 -j ACCEPT || \
  iptables -A INPUT -m state --state NEW -p udp --dport 2456:2458 -j ACCEPT
fi
netfilter-persistent save || true

# ------- Permisos correctos antes de descargar -------
chown -R valheim:valheim "$VHOME"

# ------- Descargar Valheim dedicated server (con reintentos) -------
# Se hace AL FINAL, asi aunque la descarga falle (red, reintento de SteamCMD, etc.)
# ya quedaron instalados systemd, firewall y update.sh. El usuario puede reintentar
# con:   sudo -u valheim /home/valheim/update.sh
log "Descargando Valheim dedicated server (AppID 896660). Esto tarda varios minutos..."
set +e
for attempt in 1 2 3; do
  sudo -u valheim "$VHOME/steamcmd_box86.sh" \
    +@sSteamCmdForcePlatformType linux \
    +force_install_dir "$SERVER_DIR" \
    +login anonymous \
    +app_update 896660 validate \
    +quit
  rc=$?
  if [[ $rc -eq 0 ]]; then
    log "Valheim server descargado correctamente."
    break
  fi
  warn "Intento $attempt: SteamCMD salio con codigo $rc. Reintentando en 10s..."
  sleep 10
done
set -e

if [[ ! -x "$SERVER_DIR/valheim_server.x86_64" ]]; then
  warn "La descarga automatica no completo. Podes reintentarla manualmente:"
  warn "    sudo -u valheim /home/valheim/update.sh"
  warn "Si vuelve a fallar, probá sin 'set -e':"
  warn "    sudo -u valheim /home/valheim/steamcmd_box86.sh +force_install_dir $SERVER_DIR +login anonymous +app_update 896660 validate +quit"
fi

chown -R valheim:valheim "$VHOME"

# ------- Resumen -------
log "========================================================================"
log "Instalación OK."
log ""
log "Para arrancar el servidor:"
log "    sudo systemctl start valheim-server"
log ""
log "Para ver los logs en vivo:"
log "    sudo journalctl -u valheim-server -f"
log ""
log "RECORDA abrir tambien los puertos UDP 2456-2458 en la Security List"
log "de tu VCN en OCI (Console web)."
log "========================================================================"
