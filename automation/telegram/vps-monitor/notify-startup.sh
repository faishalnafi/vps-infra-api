#!/usr/bin/env bash
# Dipanggil oleh systemd (ExecStart pada vps-power-notify.service) saat VPS baru menyala/boot.
#
# TIDAK langsung kirim notifikasi begitu OS boot. Script ini MENUNGGU (dengan batas waktu)
# sampai semua service infrastruktur yang terdeteksi terpasang (Docker, DBMS, web server,
# PHP-FPM, dst.) berstatus aktif - supaya begitu devops menerima pesan "SEMUA NORMAL", itu
# benar-benar berarti seluruh infrastruktur di VPS ini sudah siap, bukan sekadar OS-nya nyala.
#
# Kalau ada yang tetap belum aktif sampai batas waktu, pesan TETAP dikirim (tidak didiamkan
# selamanya) tapi ditandai jelas mana yang bermasalah.
#
# Resource-ringan: selama menunggu, tiap 10 detik hanya menjalankan "systemctl is-active"
# (baca state internal systemd, hampir tanpa biaya CPU) - bukan command berat seperti
# "docker --version"/"nginx -v". Command versi lengkap baru dijalankan SEKALI di akhir,
# untuk isi laporan final.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/telegram.sh
source "$SCRIPT_DIR/lib/telegram.sh"
# shellcheck source=vps-status-report.sh
source "$SCRIPT_DIR/vps-status-report.sh"
# shellcheck source=service-check.sh
source "$SCRIPT_DIR/service-check.sh"

MAX_WAIT_SECONDS="${READY_MAX_WAIT_SECONDS:-300}"       # default: tunggu maks 5 menit
CHECK_INTERVAL_SECONDS="${READY_CHECK_INTERVAL_SECONDS:-10}"

# Beri jeda awal supaya jaringan/DNS sempat siap sebelum mulai polling.
sleep 15

elapsed=0
all_ready=0
while (( elapsed < MAX_WAIT_SECONDS )); do
    if all_services_active; then
        all_ready=1
        break
    fi
    sleep "$CHECK_INTERVAL_SECONDS"
    elapsed=$(( elapsed + CHECK_INTERVAL_SECONDS ))
done

# Ambil laporan LENGKAP (dengan versi) sekali saja untuk pesan final, apa pun hasilnya.
detect_installed_services 1
down_summary=$(build_down_services_summary)
services_report=$(build_services_report)
resource_report=$(build_status_report)

if [[ "$all_ready" -eq 1 ]]; then
    header="🟢 <b>${VPS_LABEL} BARU MENYALA — SEMUA SERVICE NORMAL</b>
✅ Semua service infrastruktur yang terdeteksi sudah berjalan normal (dikonfirmasi dalam ${elapsed}s)."
else
    header="🟡 <b>${VPS_LABEL} BARU MENYALA — ADA SERVICE BELUM NORMAL</b>
⚠️ Setelah menunggu ${MAX_WAIT_SECONDS}s, service berikut BELUM aktif: ${down_summary:-tidak diketahui}"
fi

send_telegram_message "${header}

${services_report}

${resource_report}"
