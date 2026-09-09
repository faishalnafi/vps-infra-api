#!/usr/bin/env bash
# Helper bersama: kirim pesan ke Telegram lewat Bot API.
# File ini di-"source" oleh notify-*.sh, BUKAN dijalankan langsung.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${VPS_MONITOR_ENV:-$SCRIPT_DIR/.env}"

if [[ -f "$ENV_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$ENV_FILE"
else
    echo "[vps-monitor] File .env tidak ditemukan di $ENV_FILE (lihat .env.example)" >&2
    exit 1
fi

: "${TELEGRAM_BOT_TOKEN:?TELEGRAM_BOT_TOKEN belum diisi di .env}"
: "${TELEGRAM_CHAT_ID:?TELEGRAM_CHAT_ID belum diisi di .env}"

VPS_LABEL="${VPS_LABEL:-$(hostname)}"

# Kirim satu pesan HTML ke Telegram. Return non-zero kalau gagal.
send_telegram_message() {
    local text="$1"
    local api_url="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"
    local response

    response=$(curl -sS --max-time 15 -X POST "$api_url" \
        --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
        --data-urlencode "parse_mode=HTML" \
        --data-urlencode "disable_web_page_preview=true" \
        --data-urlencode "text=${text}") || {
        echo "[vps-monitor] Gagal menghubungi Telegram API (curl error)" >&2
        return 1
    }

    if [[ "$response" != *'"ok":true'* ]]; then
        echo "[vps-monitor] Telegram API menolak pesan: $response" >&2
        return 1
    fi
}
