#!/usr/bin/env bash
# Dipanggil oleh systemd (ExecStop pada vps-power-notify.service) saat VPS sedang dimatikan/reboot.
#
# JAMINAN URUTAN (bukan sekadar best-effort): unit vps-power-notify.service diset dengan
# "Before=shutdown.target reboot.target halt.target" + "DefaultDependencies=no", artinya
# systemd WAJIB menyelesaikan (atau men-timeout) ExecStop ini dulu sebelum proses shutdown/
# reboot benar-benar melanjutkan ke tahap power-off. Kombinasi dengan "After=network-online.target"
# saat start membuat urutan berhenti jadi kebalikannya - jaringan baru dimatikan SETELAH
# service ini selesai, jadi script ini masih sempat kirim ke internet sebelum jaringan mati.
#
# Batas waktu total ditentukan oleh TimeoutStopSec di vps-power-notify.service (lihat file
# tersebut) - VPS baru benar-benar lanjut shutdown setelah script ini selesai ATAU timeout itu
# tercapai, mana yang lebih dulu. Ini best-effort dalam arti "Telegram API bisa saja down",
# tapi BUKAN best-effort dalam arti "asal kirim lalu OS langsung mati" - OS menunggu.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/telegram.sh
source "$SCRIPT_DIR/lib/telegram.sh"
# shellcheck source=vps-status-report.sh
source "$SCRIPT_DIR/vps-status-report.sh"
# shellcheck source=service-check.sh
source "$SCRIPT_DIR/service-check.sh"

detect_installed_services 1
down_summary=$(build_down_services_summary)
services_report=$(build_services_report)
resource_report=$(build_status_report)

if [[ -z "$down_summary" ]]; then
    status_line="Semua service masih normal sesaat sebelum mati."
else
    status_line="⚠️ Sudah bermasalah sebelum mati: ${down_summary}"
fi

send_telegram_message "🔴 <b>${VPS_LABEL} SEDANG DIMATIKAN</b>
${status_line}

${services_report}

${resource_report}"
