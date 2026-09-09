#!/usr/bin/env bash
# Dipanggil berkala oleh systemd timer (vps-heartbeat.timer) atau cron untuk laporan status rutin.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/telegram.sh
source "$SCRIPT_DIR/lib/telegram.sh"
# shellcheck source=vps-status-report.sh
source "$SCRIPT_DIR/vps-status-report.sh"
# shellcheck source=service-check.sh
source "$SCRIPT_DIR/service-check.sh"

# Deteksi sekali saja (dengan versi lengkap) - heartbeat cuma jalan sekali per interval,
# jadi tidak perlu pemisahan fast-check/full-check seperti di notify-startup.sh.
detect_installed_services 1
all_services_ok=1
for i in "${!SVC_ACTIVE[@]}"; do
    [[ "${SVC_ACTIVE[$i]}" -eq 0 ]] && all_services_ok=0
done
down_summary=$(build_down_services_summary)
services_report=$(build_services_report)
resource_report=$(build_status_report)

if [[ "$all_services_ok" -eq 1 ]]; then
    header="📡 <b>${VPS_LABEL} - Status Berkala (Semua Normal)</b>"
else
    header="📡 <b>${VPS_LABEL} - Status Berkala</b>
⚠️ Service bermasalah: ${down_summary:-tidak diketahui}"
fi

send_telegram_message "${header}

${services_report}

${resource_report}"
