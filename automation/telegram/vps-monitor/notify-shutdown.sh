#!/usr/bin/env bash
# Dipanggil oleh systemd (ExecStop pada vps-power-notify.service) saat VPS sedang dimatikan/reboot.
#
# CATATAN: dijalankan di detik-detik terakhir sebelum sistem mati, saat jaringan
# mungkin sudah mulai dimatikan juga. Pengiriman best-effort - tidak 100% terjamin
# selalu berhasil sampai ke Telegram (lihat README.md bagian "Keterbatasan").
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/telegram.sh
source "$SCRIPT_DIR/lib/telegram.sh"
# shellcheck source=vps-status-report.sh
source "$SCRIPT_DIR/vps-status-report.sh"

report=$(build_status_report)
send_telegram_message "🔴 <b>${VPS_LABEL} SEDANG DIMATIKAN</b>

${report}"
