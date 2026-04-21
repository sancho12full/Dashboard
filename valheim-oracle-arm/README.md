# Servidor dedicado de Valheim en Oracle Cloud (VM ARM `A1.Flex`, Ubuntu 22.04)

Guía paso a paso para montar un servidor dedicado de **Valheim** en una VM ARM de Oracle Cloud (Ampere A1).

> **Importante sobre ARM64:** el servidor dedicado oficial de Valheim (SteamCMD AppID `896660`) **solo existe en x86_64**. No hay build nativa para ARM. La solución probada por la comunidad es ejecutarlo con **[Box64](https://github.com/ptitSeb/box64)** (emulador x86_64→ARM64, overhead ~5-15 %). Además, **SteamCMD es un binario x86 de 32 bits**, así que se usa **[Box86](https://github.com/ptitSeb/box86)** para esa parte. El script instala ambos. Con tus 2 OCPU + 12 GB RAM rinde sobrado para 1-10 jugadores.

---

## 0. Antes de empezar — lo que tenés que tener listo

- La VM creada (tu caso: `VM.Standard.A1.Flex`, 2 OCPU, 12 GB RAM, Ubuntu 22.04 aarch64). ✅
- La **clave SSH privada** (el `.key` que descargaste al crear la instancia).
- La **IP pública** de la VM (la ves en el panel de la instancia en OCI).
- Decidir 3 cosas del servidor:
  - **Nombre** que aparecerá en la lista de servidores (ej. `MiServidorCopado`).
  - **Mundo** (nombre del archivo del mapa, ej. `Midgard`).
  - **Contraseña** del servidor: **mínimo 5 caracteres**, y **no** puede contener el nombre del servidor ni del mundo (si no, el server falla al arrancar).

---

## 1. Abrir los puertos de Valheim

Valheim usa **UDP 2456, 2457 y 2458**. Hay que abrirlos en **dos lugares**:

### 1.a) En Oracle Cloud (Security List de la VCN)

1. OCI Console → **Networking → Virtual Cloud Networks** → tu VCN.
2. Entrá a la **Subnet** donde está tu VM → **Security Lists** → la default.
3. **Add Ingress Rules**, uno por puerto (o un único rango):
   - Source Type: `CIDR`
   - Source CIDR: `0.0.0.0/0`
   - IP Protocol: **UDP**
   - Destination Port Range: `2456-2458`
   - Description: `Valheim`

> Si usás **Network Security Groups** en vez de Security Lists, aplicá la misma regla ahí.

### 1.b) Dentro del SO (iptables en Ubuntu de Oracle)

Oracle Ubuntu viene con `iptables` bloqueando por defecto. Lo hace el script de instalación (`install.sh`), pero si querés hacerlo a mano:

```bash
sudo iptables -I INPUT 6 -m state --state NEW -p udp --dport 2456:2458 -j ACCEPT
sudo netfilter-persistent save
```

---

## 2. Conectarte a la VM por SSH

Desde tu máquina local:

```bash
chmod 600 ~/Descargas/tu-clave.key
ssh -i ~/Descargas/tu-clave.key ubuntu@TU_IP_PUBLICA
```

El usuario por defecto en las imágenes Ubuntu de Oracle es **`ubuntu`**.

---

## 3. Copiar el instalador a la VM

Desde tu máquina local, estando en esta carpeta (`valheim-oracle-arm/`):

```bash
scp -i ~/Descargas/tu-clave.key install.sh valheim-server.service ubuntu@TU_IP_PUBLICA:~
```

O, más rápido, cloná este repo directamente en la VM:

```bash
# dentro de la VM
sudo apt-get update && sudo apt-get install -y git
git clone <URL-de-tu-repo>.git
cd <tu-repo>/valheim-oracle-arm
```

---

## 4. Ejecutar el instalador

Dentro de la VM:

```bash
chmod +x install.sh
sudo ./install.sh
```

El script hace todo esto de forma desatendida:

1. Actualiza el sistema y crea el usuario de servicio `valheim`.
2. Activa arquitectura **armhf** y repositorios **universe** / **multiverse**.
3. Instala **Box64** (para el server) y **Box86** (para SteamCMD) desde los repos oficiales de Ryanfortner.
4. Descarga **SteamCMD** desde Valve y lo corre bajo Box86.
5. Descarga el servidor dedicado de Valheim (AppID 896660) y lo ejecuta bajo Box64.
6. Crea el script de arranque `start_valheim.sh` con tus variables.
7. Instala y habilita el servicio **systemd** `valheim-server.service`.
8. Abre los puertos UDP 2456-2458 en iptables y lo persiste.
9. Configura una **tarea de backup diaria** del mundo en `/home/valheim/backups`.

El script te va a **preguntar** al principio:

- Nombre del servidor
- Nombre del mundo
- Contraseña (mínimo 5 caracteres)

---

## 5. Arrancar y verificar

```bash
sudo systemctl start valheim-server
sudo systemctl status valheim-server
sudo journalctl -u valheim-server -f
```

Tardás **2-5 minutos** la primera vez en ver el log `Game server connected` / `DungeonDB Start`. Eso significa que el servidor ya está listo y registrado en el _Community Server List_ de Steam.

---

## 6. Conectarte desde el juego

En Steam, con Valheim abierto:

- **Start Game → Community (o "Join Game") → buscá por nombre**, o
- **Join IP** → `TU_IP_PUBLICA:2456` (el puerto que se usa para unirse es `2456`; los otros dos los usa Steam internamente).

---

## 7. Operación diaria

| Acción | Comando |
| --- | --- |
| Arrancar | `sudo systemctl start valheim-server` |
| Parar (hace _world save_ limpio) | `sudo systemctl stop valheim-server` |
| Reiniciar | `sudo systemctl restart valheim-server` |
| Ver logs en vivo | `sudo journalctl -u valheim-server -f` |
| Habilitar al boot | `sudo systemctl enable valheim-server` |
| Actualizar Valheim | `sudo systemctl stop valheim-server && sudo -u valheim /home/valheim/update.sh && sudo systemctl start valheim-server` |

Los mundos viven en `/home/valheim/.config/unity3d/IronGate/Valheim/worlds_local/`.

---

## 8. Backups

El instalador crea `/etc/cron.daily/valheim-backup` que guarda un `.tar.gz` del directorio de mundos en `/home/valheim/backups` y mantiene los últimos **14 días**.

Para bajarte un backup a tu máquina:

```bash
scp -i ~/Descargas/tu-clave.key ubuntu@TU_IP_PUBLICA:/home/valheim/backups/valheim-*.tar.gz .
```

---

## 9. Consejos y troubleshooting

- **`Package 'steamcmd' has no installation candidate`:** correcto — en arm64 ese paquete no existe. El script ya lo maneja: baja el tarball oficial de Valve y lo ejecuta bajo Box86. Si te aparece al correr una versión vieja del script, reclona/pulleá la rama.

- **`[BOX64] Error: File is not found. (./linux64/steamcmd)`:** SteamCMD es 32-bit, el binario correcto es `./linux32/steamcmd` y se corre con **Box86**, no Box64. Actualizá el script (`git pull`) y volvé a correrlo.

- **`ERROR! Failed to install app '896660' (Missing configuration)`:** suele pasar por un appcache corrupto de un intento anterior, o por pasar `+@sSteamCmdForcePlatformType linux` (que Box86 a veces interpreta mal). El script ya NO usa ese flag y limpia `~/Steam/appcache` entre reintentos. Si te pasa corriendo a mano:
  ```bash
  sudo -u valheim rm -rf /home/valheim/Steam/appcache
  sudo -u valheim /home/valheim/update.sh
  ```

- **`Update complete, launching...` y después muere / `Unit valheim-server.service not found`:** pasaba porque invocábamos el binario de SteamCMD directo en vez del wrapper `steamcmd.sh`, y el auto-update interno perdía `LD_LIBRARY_PATH` en el re-exec. El script actual usa `./steamcmd.sh` + binfmt y reintenta 3 veces. Si tu descarga quedó a mitad, reintentala con:
  ```bash
  sudo -u valheim /home/valheim/update.sh
  ```

- **`Package 'box86:armhf' has no installation candidate`:** correcto — `box86` es un virtual package, hay que pedir una variante (`box86-generic-arm`). Ya manejado.

- **`E: Unable to locate package box64-generic-arm`:** warning inofensivo — el repo de Ryanfortner ya provee el paquete genérico `box64`. El script hace fallback automáticamente.

- **`/usr/bin/env: 'bash\r': No such file or directory`:** el script tiene finales de línea de Windows (CRLF) en vez de Unix (LF). Suele pasar si bajaste/editaste los archivos en Windows. Fijalo con:
  ```bash
  sudo apt-get install -y dos2unix
  dos2unix install.sh valheim-server.service
  # o sin instalar nada:
  # sed -i 's/\r$//' install.sh valheim-server.service
  chmod +x install.sh
  sudo ./install.sh
  ```
  El repo ya trae un `.gitattributes` que fuerza LF, así que si clonás fresco no debería volver a pasarte.

- **No aparece en la lista de servidores:** esperá 3-5 min la primera vez; revisá que los puertos UDP estén abiertos _en ambos_ sitios (OCI + iptables). Probá conectar por IP directa primero.
- **"Failed to load mono"** al arrancar: suele ser arquitectura armhf no habilitada. El script lo hace, pero si corriste algo a mano verificá con `dpkg --print-foreign-architectures` que aparezca `armhf`.
- **CPU al 100 %:** Valheim escala mal con muchos jugadores; 2 OCPU aguantan perfecto hasta ~5 y bien hasta ~10. Si crece el grupo, subí a 4 OCPU (la A1 es flexible).
- **RAM:** el proceso usa ~3-5 GB en servidor de 10 personas. Tenés 12 GB, sobra.
- **Ancho de banda:** ~100-300 KB/s por jugador. 2 Gbps sobra.
- **Always Free:** la shape A1.Flex hasta 4 OCPU y 24 GB está dentro del tier gratuito de OCI.

---

## 10. Cuestiones de seguridad

- El servidor corre como usuario **no privilegiado** `valheim`, no root.
- SSH: desactivá login por password y dejá solo clave (por defecto en Oracle Ubuntu ya es así).
- Si vas a exponer SSH, considerá cambiarlo de puerto o usar `fail2ban`:
  ```bash
  sudo apt-get install -y fail2ban
  ```
- La contraseña del servidor viaja **cifrada** entre cliente y servidor (el juego usa su propio handshake).

---

## Archivos de este repo

- `install.sh` — instalador automatizado, idempotente.
- `valheim-server.service` — unidad systemd.
- `start_valheim.sh.tmpl` — plantilla del script de arranque (el instalador la rellena con tus datos).
- `update.sh` — script auxiliar para actualizar el server cuando sale parche.
- `backup.sh` — script de backup diario.

¡Listo! Cualquier cosa, revisá primero `journalctl -u valheim-server -n 200`.
