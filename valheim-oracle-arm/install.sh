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

# ------- Box64 -------
log "Instalando Box64 (repo oficial de Ryanfortner)..."
BOX64_LIST="/etc/apt/sources.list.d/box64.list"
BOX64_KEY="/etc/apt/keyrings/box64.gpg"
mkdir -p /etc/apt/keyrings
if [[ ! -f "$BOX64_KEY" ]]; then
  curl -fsSL https://ryanfortner.github.io/box64-debs/KEY.gpg \
    | gpg --dearmor -o "$BOX64_KEY"
fi
if [[ ! -f "$BOX64_LIST" ]]; then
  echo "deb [signed-by=$BOX64_KEY] https://ryanfortner.github.io/box64-debs/debian ./" \
    > "$BOX64_LIST"
fi
apt-get update -y
apt-get install -y box64-generic-arm || apt-get install -y box64

# ------- SteamCMD -------
log "Instalando SteamCMD..."
echo steam steam/question select "I AGREE" | debconf-set-selections
echo steam steam/license note ''           | debconf-set-selections
# steamcmd en arm64 se instala via i386? No: usamos el paquete steamcmd que trae los scripts
# y el binario real se ejecuta bajo box64 mas abajo.
apt-get install -y --no-install-recommends steamcmd || true

# En ARM, `steamcmd` puede no correr nativo: preparamos un wrapper con box64.
STEAMCMD_DIR="$VHOME/steamcmd"
sudo -u valheim mkdir -p "$STEAMCMD_DIR"
if [[ ! -f "$STEAMCMD_DIR/steamcmd.sh" ]]; then
  log "Descargando SteamCMD (binarios x86_64)..."
  sudo -u valheim bash -c "cd '$STEAMCMD_DIR' && \
    curl -sSL https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz \
    | tar zxf -"
fi

# Wrapper para ejecutar steamcmd bajo box64
cat > "$VHOME/steamcmd_box64.sh" <<'EOF'
#!/usr/bin/env bash
set -e
export HOME=/home/valheim
cd /home/valheim/steamcmd
exec box64 ./linux64/steamcmd "$@"
EOF
chmod +x "$VHOME/steamcmd_box64.sh"
chown valheim:valheim "$VHOME/steamcmd_box64.sh"

# ------- Descargar/actualizar Valheim dedicated server (AppID 896660) -------
SERVER_DIR="$VHOME/valheim-server"
sudo -u valheim mkdir -p "$SERVER_DIR"

log "Descargando/Actualizando Valheim dedicated server (esto tarda unos minutos)..."
sudo -u valheim "$VHOME/steamcmd_box64.sh" \
  +@sSteamCmdForcePlatformType linux \
  +force_install_dir "$SERVER_DIR" \
  +login anonymous \
  +app_update 896660 validate \
  +quit

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
exec "$VHOME/steamcmd_box64.sh" \\
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

# ------- Permisos finales -------
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
