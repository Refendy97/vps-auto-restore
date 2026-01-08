#!/usr/bin/env bash
set -Eeuo pipefail

log()  { echo "[$(date '+%F %T')] [INFO] $*"; }
warn() { echo "[$(date '+%F %T')] [WARN] $*" >&2; }
die()  { echo "[$(date '+%F %T')] [ERROR] $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Run as root"

# ===== OS CHECK =====
. /etc/os-release || die "Cannot read /etc/os-release"
[[ "${ID:-}" = "debian" ]] || die "Only Debian supported (detected: ${ID:-unknown})"
log "Detected OS: ${PRETTY_NAME:-Debian}"

# ===== APT HELPERS =====
apt_update_once() {
  apt-get update -y
}

apt_install_required() {
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@"
}

apt_install_optional() {
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@" \
    >/dev/null 2>&1 || warn "Optional packages not installed: $*"
}

# ===== INSTALL DEPENDENCIES =====
apt_update_once

# Required (restore will fail without these)
apt_install_required ca-certificates curl tar systemd rclone

# Optional (best effort)
apt_install_optional docker.io
apt_install_optional docker-compose-plugin
apt_install_optional docker-compose

# Enable docker if exists
if systemctl list-unit-files 2>/dev/null | grep -q '^docker\.service'; then
  systemctl enable --now docker >/dev/null 2>&1 || true
fi

# ===== INSTALL restore.sh =====
RESTORE_URL="https://raw.githubusercontent.com/Refendy97/vps-auto-restore/main/restore.sh"
RESTORE_BIN="/usr/local/bin/vpn-restore"

log "Downloading restore.sh -> $RESTORE_BIN"
rm -f "$RESTORE_BIN"
curl -fsSL "$RESTORE_URL" -o "$RESTORE_BIN"

# ----- VALIDATION (FIXED & PORTABLE) -----
# 1) File not empty
[[ -s "$RESTORE_BIN" ]] || die "Downloaded restore.sh is empty"

# 2) Has shebang (accepts /usr/bin/env bash)
head -n 1 "$RESTORE_BIN" | grep -q '^#!' \
  || die "Downloaded file has no shebang"

# 3) Valid bash syntax
bash -n "$RESTORE_BIN" || die "restore.sh failed bash syntax check"

chmod +x "$RESTORE_BIN"
log "restore.sh installed and validated"

# ===== PREPARE backup.env =====
ENV_DIR="/opt/vpn-backup"
ENV_FILE="$ENV_DIR/backup.env"

mkdir -p "$ENV_DIR"
chmod 700 "$ENV_DIR" || true

if [[ ! -f "$ENV_FILE" ]]; then
  log "Creating default backup.env"
  cat > "$ENV_FILE" <<'EOF'
RCLONE_REMOTE="gdrive:VPN-BACKUP"
LOCAL_WORKDIR="/opt/vpn-backup"
BACKUP_ITEMS="/root/.config/rclone /opt/marzban /var/lib/marzban /etc/nginx /etc/systemd/system /opt/marzban-bot /opt/vpn-restore /opt/auto-restore-repo"
EOF
  chmod 600 "$ENV_FILE" || true
else
  log "backup.env already exists (kept as-is)"
fi

# ===== FINAL CHECK =====
if [[ ! -f /root/.config/rclone/rclone.conf ]]; then
  echo
  warn "rclone.conf NOT found:"
  warn "  /root/.config/rclone/rclone.conf"
  echo
  echo "NEXT STEPS:"
  echo "  1) Copy rclone.conf from old VPS"
  echo "  2) Then run:"
  echo "     vpn-restore --dry-run"
  echo "     vpn-restore --yes"
  exit 2
fi

echo
log "INSTALL COMPLETE"
echo "Next:"
echo "  vpn-restore --dry-run"
echo "  vpn-restore --yes"