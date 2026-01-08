#!/usr/bin/env bash
set -Eeuo pipefail

# install.sh — VPS Auto Restore bootstrap (Debian 11/12)
#
# Goal: make a fresh VPS ready to run `vpn-restore` (restore.sh).
#
# Idempotent behavior:
# - Safe to re-run.
# - Does NOT overwrite /opt/vpn-backup/backup.env if it already exists.
# - Updates /usr/local/bin/vpn-restore to latest from GitHub (backs up old file).

trap 'echo "[$(date +"%F %T")] [ERROR] line ${LINENO}: ${BASH_COMMAND}" >&2' ERR

log()  { echo "[$(date '+%F %T')] [INFO] $*"; }
warn() { echo "[$(date '+%F %T')] [WARN] $*" >&2; }
die()  { echo "[$(date '+%F %T')] [ERROR] $*" >&2; exit 1; }

[[ ${EUID:-999} -eq 0 ]] || die "Run as root"

# --- OS check (Debian 11/12 only) ---
[[ -r /etc/os-release ]] || die "Cannot read /etc/os-release"
# shellcheck disable=SC1091
. /etc/os-release
[[ "${ID:-}" == "debian" ]] || die "This installer supports Debian only (Detected: ${ID:-unknown})"
case "${VERSION_ID:-}" in
  11|12) : ;;
  *) die "Supported Debian versions: 11 or 12 (Detected: ${VERSION_ID:-unknown})" ;;
esac
log "Detected OS: ${PRETTY_NAME:-Debian}"

apt_update_once() {
  log "apt-get update"
  DEBIAN_FRONTEND=noninteractive apt-get update -y
}

apt_install_required() {
  log "Installing required packages: $*"
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@"
}

apt_install_optional() {
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@" >/dev/null 2>&1 \
    || warn "Optional packages not installed: $*"
}

apt_update_once

# Required for restore flow
apt_install_required ca-certificates curl tar gzip rclone systemd

# Docker (best effort). If not available, restore.sh will still run, but marzban compose actions may be skipped.
apt_install_optional docker.io
apt_install_optional docker-compose-plugin
apt_install_optional docker-compose

# Enable docker if present
if systemctl list-unit-files 2>/dev/null | grep -q '^docker\.service'; then
  log "Enabling docker service"
  systemctl enable --now docker >/dev/null 2>&1 || true
fi

# --- Install/Update vpn-restore from GitHub (restore.sh) ---
RESTORE_URL="https://raw.githubusercontent.com/Refendy97/vps-auto-restore/main/restore.sh"
DEST_BIN="/usr/local/bin/vpn-restore"
TMP_BIN="${DEST_BIN}.tmp"
STAMP="$(date +%F_%H%M%S)"

log "Downloading restore.sh -> ${DEST_BIN}"
curl -fsSL "${RESTORE_URL}" -o "${TMP_BIN}"

# Basic sanity check: must be a shell script with a shebang
head -n 1 "${TMP_BIN}" | grep -Eq '^#!.*/(ba)?sh' || die "Downloaded file does not look like a shell script"

# Backup existing binary (if any), then replace atomically
if [[ -f "${DEST_BIN}" ]]; then
  cp -a "${DEST_BIN}" "${DEST_BIN}.bak-${STAMP}" || true
fi
install -m 0755 "${TMP_BIN}" "${DEST_BIN}"
rm -f "${TMP_BIN}" || true

# Optional convenience wrapper: `restore` + `restore YYYY-MM-DD`
# (Will not overwrite if you already have your own /usr/local/bin/restore)
RESTORE_WRAPPER="/usr/local/bin/restore"
if [[ -e "${RESTORE_WRAPPER}" ]]; then
  warn "Skip creating ${RESTORE_WRAPPER} (already exists)"
else
  cat > "${RESTORE_WRAPPER}" <<'EOW'
#!/usr/bin/env bash
set -euo pipefail
BIN="/usr/local/bin/vpn-restore"
[[ ${EUID:-999} -eq 0 ]] || { echo "Run as root" >&2; exit 1; }
[[ -x "$BIN" ]] || { echo "vpn-restore not found: $BIN" >&2; exit 1; }

# Short commands:
#   restore              -> restore latest (requires rclone.conf + backup.env)
#   restore YYYY-MM-DD   -> restore that date
#   restore --dry-run    -> pass through
#   restore --yes        -> pass through

if [[ $# -eq 0 ]]; then
  exec "$BIN" --yes
elif [[ $# -eq 1 && "$1" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  exec "$BIN" --backup "vpn-backup-$1.tar.gz" --yes
else
  exec "$BIN" "$@"
fi
EOW
  chmod 0755 "${RESTORE_WRAPPER}"
fi

# --- Ensure backup.env exists (source of truth for restore.sh) ---
ENV_DIR="/opt/vpn-backup"
ENV_FILE="${ENV_DIR}/backup.env"
mkdir -p "${ENV_DIR}"
chmod 700 "${ENV_DIR}" || true

if [[ -f "${ENV_FILE}" ]]; then
  log "Found existing ${ENV_FILE} (not overwritten)"
else
  log "Creating ${ENV_FILE}"
  cat > "${ENV_FILE}" <<'EENV'
RCLONE_REMOTE="gdrive:VPN-BACKUP"
LOCAL_WORKDIR="/opt/vpn-backup"
BACKUP_ITEMS="/root/.config/rclone /opt/marzban /var/lib/marzban /etc/nginx /etc/systemd/system /opt/marzban-bot /opt/vpn-restore /opt/auto-restore-repo"
EENV
  chmod 600 "${ENV_FILE}" || true
fi

# --- Hard requirement before restore can DOWNLOAD from Google Drive ---
RCLONE_CONF="/root/.config/rclone/rclone.conf"
if [[ ! -f "${RCLONE_CONF}" ]]; then
  echo
  echo "STOP: rclone config not found:"
  echo "  ${RCLONE_CONF}"
  echo
  echo "Restore from Google Drive REQUIRES this file on the VPS first."
  echo "Create the directory + set permission (1x):"
  echo "  mkdir -p /root/.config/rclone && chmod 700 /root/.config/rclone"
  echo
  echo "Then place rclone.conf there (method depends on your situation):"
  echo "  - If old VPS still accessible: copy the file to this VPS"
  echo "  - Or paste the rclone.conf content into ${RCLONE_CONF}"
  echo
  echo "After rclone.conf exists, run (safe first):"
  echo "  vpn-restore --dry-run"
  echo "Then execute restore:"
  echo "  vpn-restore --yes"
  echo
  exit 2
fi

log "READY"
echo "Next (safe):  vpn-restore --dry-run"
echo "Then:         vpn-restore --yes"