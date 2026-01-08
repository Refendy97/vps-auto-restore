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

# ==================================================
# AUTO RESTORE rclone.conf (ENCRYPTED, PASSWORD)
# ==================================================

RCLONE_CONF_PATH="/root/.config/rclone/rclone.conf"

if [ ! -f "$RCLONE_CONF_PATH" ]; then
  echo "[INFO] rclone.conf not found, restoring from embedded encrypted data"

  # === EMBEDDED ENCRYPTED rclone.conf (BASE64) ===
  RCLONE_CONF_ENC_B64='U2FsdGVkX1/pElR6Ss0bRAWfe0u1twsrFEWR0UFrnJCaeLexrFsL3wJV8KpvyGSjVNzAz3HDaStPVKbWLpRCQ06wvOuz3sG+GoItEegbjDaM05bTynIJdIv/zA2LG51Uc4jp4cEts1s9ETa/WZla+BoeyoI9WXqPbMu8uCSJKonviMpkSd/2CJdumZJk8HDSMrSsHUZN6C0ut//y5dPYMFs/ebwKaKhOZlUG3ej4MD4WbNaIcIl+xilI0nUZM7f+8VNgdRtideHe7cn0wvrDmAFMNrOmxUuM2vfbkz++8sG/aXXnzzVH4aM0sx3dNE4Mbr1qPck/UJFOVJmGeGC8SLu2T+3I76jbCaVMJ65kf4kLHSQ0wzTrMvAleNczGctFhEaoEQQHigf5RcBrTy7CtFD9LjBfMviK0Z9GNwzGPLY+0yECgc+1ExL2rNIvWeh0RyLgG8ocl1ng2+UnBovvtoC5wvD6dzORtJzWBqwFUS20kSDt6cPZbYHQlWz4BEoBE4rFoTe4nJmnvBssT/qctb1VVT+n92pgok+lHMwu+ZlUjAmVcuhWdIPsvYFl68sZDjJtg/DzGDdU+dFhVsZBf2RSwPqB5Gy6x4QQUTGTA4Bb7IY7XyfkDg7f+3FNWurwX8OTD8W05xxbIpQyrk6GKYoeGBenK61xNw1t+6Fmcw5hBVlErZTKmGKqYqlnC5oHkX+kV7Zim6nMn9TCzCCgf2uQKry7fd22cMOW6JOeAnU='

  mkdir -p /root/.config/rclone
  chmod 700 /root/.config/rclone

  # Password prompt (silent)
  read -r -s -p "Enter rclone.conf password: " RCLONE_PASS
  echo

  printf '%s' "$RCLONE_CONF_ENC_B64" \
    | base64 -d \
    | openssl enc -d -aes-256-cbc -pbkdf2 \
        -pass pass:"$RCLONE_PASS" \
    > "$RCLONE_CONF_PATH" || {
          echo "[ERROR] Failed to decrypt rclone.conf"
          exit 1
        }

  chmod 600 "$RCLONE_CONF_PATH"
  echo "[OK] rclone.conf restored"
else
  echo "[OK] rclone.conf already exists, skipping restore"
fi

# ==================================================

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