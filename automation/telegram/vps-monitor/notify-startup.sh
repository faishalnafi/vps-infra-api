#!/usr/bin/env bash
# Dipanggil oleh systemd (ExecStart pada vps-power-notify.service) saat VPS baru menyala/boot.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/telegram.sh
source "$SCRIPT_DIR/lib/telegram.sh"
# shellcheck source=vps-status-report.sh
source "$SCRIPT_DIR/vps-status-report.sh"

# Beri jeda supaya jaringan & DNS sudah siap sebelum memanggil Telegram API / cek IP publik.
sleep 15

report=$(build_status_report)
send_telegram_message "🟢 <b>${VPS_LABEL} BARU MENYALA</b>

${report}"
