#!/usr/bin/env bash
# Dipanggil berkala oleh systemd timer (vps-heartbeat.timer) atau cron untuk laporan status rutin.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/telegram.sh
source "$SCRIPT_DIR/lib/telegram.sh"
# shellcheck source=vps-status-report.sh
source "$SCRIPT_DIR/vps-status-report.sh"

report=$(build_status_report)
send_telegram_message "📡 <b>${VPS_LABEL} - Status Berkala</b>

${report}"
