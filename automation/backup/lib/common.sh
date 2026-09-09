#!/usr/bin/env bash
# Helper bersama: load .env, logging, notifikasi Telegram.
# Di-source oleh run-backup.sh dan tiap backup-*.sh - TIDAK dijalankan langsung.

set -uo pipefail

SCRIPT_DIR_COMMON="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${BACKUP_ENV:-$SCRIPT_DIR_COMMON/.env}"

if [[ -f "$ENV_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$ENV_FILE"
else
    echo "[backup] File .env tidak ditemukan di $ENV_FILE (lihat .env.example)" >&2
    exit 1
fi

: "${RCLONE_REMOTE_PATH:?RCLONE_REMOTE_PATH belum diisi di .env}"

VPS_LABEL="${VPS_LABEL:-$(hostname)}"
RETENTION_DAYS="${RETENTION_DAYS:-14}"
NOTIFY_ON_SUCCESS="${NOTIFY_ON_SUCCESS:-false}"

log_info()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]  $*"; }
log_error() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $*" >&2; }

# Kirim pesan Telegram - diam-diam dilewati kalau TELEGRAM_BOT_TOKEN/CHAT_ID kosong
# (notifikasi Telegram bersifat opsional untuk project backup ini).
send_telegram_message() {
    local text="$1"
    [[ -z "${TELEGRAM_BOT_TOKEN:-}" || -z "${TELEGRAM_CHAT_ID:-}" ]] && return 0
    curl -sS --max-time 15 -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
        --data-urlencode "parse_mode=HTML" \
        --data-urlencode "text=${text}" >/dev/null 2>&1
}
