#!/usr/bin/env bash
set -Eeuo pipefail

# Auto Restore VPS (Marzban/Xray + Nginx + Bot) - Debian 11/12
# Source of truth env: /opt/vpn-backup/backup.env
#
# Usage:
#   ./restore.sh --dry-run
#   ./restore.sh --yes
#   ./restore.sh --backup vpn-backup-YYYY-MM-DD.tar.gz --yes

log(){ echo "[$(date '+%F %T')] $*"; }
die(){ echo "ERROR: $*" >&2; exit 1; }
require_cmd(){ command -v "$1" >/dev/null 2>&1 || die "Command not found: $1"; }

YES=0
DRY=0
PICK_BACKUP=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes) YES=1; shift ;;
    --dry-run) DRY=1; shift ;;
    --backup) PICK_BACKUP="${2:-}"; shift 2 ;;
    -h|--help)
      sed -n '1,120p' "$0"
      exit 0
      ;;
    *) die "Unknown arg: $1" ;;
  esac
done

[[ $EUID -eq 0 ]] || die "Run as root."

ENV_FILE="/opt/vpn-backup/backup.env"
[[ -f "$ENV_FILE" ]] || die "ENV file not found: $ENV_FILE"

# shellcheck disable=SC1090
source "$ENV_FILE"
: "${RCLONE_REMOTE:?missing in backup.env}"
: "${LOCAL_WORKDIR:?missing in backup.env}"
: "${BACKUP_ITEMS:?missing in backup.env}"

WORKDIR="/opt/restore-run"
mkdir -p "$WORKDIR"
chmod 700 "$WORKDIR" || true

require_cmd rclone
require_cmd tar
require_cmd systemctl
require_cmd date

# Detect compose (docker compose v2 or docker-compose)
COMPOSE_BIN=""
if command -v docker >/dev/null 2>&1; then
  if docker compose version >/dev/null 2>&1; then
    COMPOSE_BIN="docker compose"
  elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_BIN="docker-compose"
  fi
fi

MARZBAN_COMPOSE="/opt/marzban/docker-compose.yml"
HAS_MARZBAN_COMPOSE=0
if [[ -n "$COMPOSE_BIN" && -f "$MARZBAN_COMPOSE" ]]; then
  HAS_MARZBAN_COMPOSE=1
fi

BOT_SERVICE="budivpn-bot.service"
NGINX_SERVICE="nginx.service"

log "Finding backup on remote: $RCLONE_REMOTE"

if [[ -n "$PICK_BACKUP" ]]; then
  BACKUP_NAME="$PICK_BACKUP"
else
  BACKUP_NAME="$(rclone lsf "$RCLONE_REMOTE" --files-only 2>/dev/null \
    | grep -E '^vpn-backup-[0-9]{4}-[0-9]{2}-[0-9]{2}\.tar\.gz$' \
    | sort | tail -n 1 || true)"
fi

[[ -n "${BACKUP_NAME:-}" ]] || die "No vpn-backup-YYYY-MM-DD.tar.gz found in remote."

REMOTE_OBJ="${RCLONE_REMOTE%/}/$BACKUP_NAME"
LOCAL_TARBALL="$WORKDIR/$BACKUP_NAME"

# Restore paths = BACKUP_ITEMS (space-separated)
# shellcheck disable=SC2206
RESTORE_PATHS=($BACKUP_ITEMS)

print_plan() {
  echo "=== PLAN ==="
  echo "ENV_FILE: $ENV_FILE"
  echo "RCLONE_REMOTE: $RCLONE_REMOTE"
  echo "WORKDIR: $WORKDIR"
  echo "Backup tarball: $LOCAL_TARBALL"
  echo "Will restore paths (from backup):"
  for p in "${RESTORE_PATHS[@]}"; do echo "  $p"; done
  echo "Actions: download, validate tar, pre-backup current state, stop services, extract, reload systemd, restart services"
  echo "============"
}

log "Selected backup: $BACKUP_NAME"
log "Remote object: $REMOTE_OBJ"
log "Local tarball: $LOCAL_TARBALL"
print_plan

if [[ "$DRY" -eq 1 ]]; then
  log "DRY RUN: no changes will be made."
  exit 0
fi

[[ "$YES" -eq 1 ]] || die "Safety stop: run with --yes to actually restore."

# 1) Download first (min downtime)
log "Downloading backup from remote..."
rclone copyto "$REMOTE_OBJ" "$LOCAL_TARBALL" --progress

# 2) Validate tarball
log "Validating tarball (tar -tf)..."
tar -tf "$LOCAL_TARBALL" >/dev/null

# 3) Pre-restore safety backup (local)
STAMP="$(date '+%F_%H%M%S')"
PRE_TAR="$WORKDIR/pre-restore-$STAMP.tar.gz"
log "Creating pre-restore safety backup: $PRE_TAR"
EXISTING=()
for p in "${RESTORE_PATHS[@]}"; do
  [[ -e "$p" ]] && EXISTING+=("$p")
done

if [[ ${#EXISTING[@]} -gt 0 ]]; then
  tar -czf "$PRE_TAR" --warning=no-file-changed --absolute-names "${EXISTING[@]}" || true
  log "Pre-restore backup created."
else
  log "Nothing to pre-backup (paths not found)."
fi

# 4) Stop services (downtime starts)
log "Stopping services..."
if systemctl list-unit-files 2>/dev/null | grep -q "^${BOT_SERVICE}"; then
  systemctl stop "$BOT_SERVICE" || true
fi

if [[ "$HAS_MARZBAN_COMPOSE" -eq 1 ]]; then
  log "Stopping marzban via compose..."
  $COMPOSE_BIN -f "$MARZBAN_COMPOSE" down || true
fi

systemctl stop "$NGINX_SERVICE" || true

# 5) Extract restore
log "Restoring files from tarball..."
tar -xzf "$LOCAL_TARBALL" --absolute-names --overwrite

# 6) Reload systemd
log "Reloading systemd daemon..."
systemctl daemon-reload || true

# 7) Start services
log "Starting services..."
systemctl start "$NGINX_SERVICE" || true

if [[ "$HAS_MARZBAN_COMPOSE" -eq 1 ]]; then
  log "Starting marzban via compose..."
  $COMPOSE_BIN -f "$MARZBAN_COMPOSE" up -d
fi

if systemctl list-unit-files 2>/dev/null | grep -q "^${BOT_SERVICE}"; then
  systemctl start "$BOT_SERVICE" || true
fi

# 8) Quick health checks
log "Health checks:"
systemctl --no-pager --full status "$NGINX_SERVICE" | sed -n '1,14p' || true
if systemctl list-unit-files 2>/dev/null | grep -q "^${BOT_SERVICE}"; then
  systemctl --no-pager --full status "$BOT_SERVICE" | sed -n '1,14p' || true
fi
if command -v docker >/dev/null 2>&1; then
  docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}' || true
fi

log "RESTORE DONE."
log "Safety tar (local): $PRE_TAR"