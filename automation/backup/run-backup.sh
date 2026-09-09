#!/usr/bin/env bash
# Orchestrator utama: jalankan semua backup-*.sh yang relevan (masing-masing melewati diri
# sendiri kalau target tidak terpasang), kumpulkan hasilnya di folder staging sementara,
# upload ke object storage lewat rclone, hapus backup lama di remote sesuai RETENTION_DAYS,
# lalu notifikasi Telegram HANYA kalau ada yang gagal (atau kalau NOTIFY_ON_SUCCESS=true).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

if ! command -v rclone >/dev/null 2>&1; then
    log_error "rclone tidak terpasang. Lihat README.md bagian instalasi rclone."
    send_telegram_message "🔴 <b>${VPS_LABEL} - Backup GAGAL</b>
rclone tidak terpasang di VPS ini."
    exit 1
fi

STAGING_DIR=$(mktemp -d /tmp/vps-backup.XXXXXX)
trap 'rm -rf "$STAGING_DIR"' EXIT

log_info "Mulai backup - staging: $STAGING_DIR"

FAILED_STEPS=()

run_step() {
    local name="$1" script="$2"
    if bash "$SCRIPT_DIR/$script" "$STAGING_DIR"; then
        :
    else
        FAILED_STEPS+=("$name")
    fi
}

run_step "MySQL/MariaDB" backup-mysql.sh
run_step "PostgreSQL" backup-postgres.sh
run_step "MongoDB" backup-mongodb.sh
run_step "Docker Volumes" backup-docker-volumes.sh
run_step "NPM Data" backup-npm-data.sh

file_count=$(find "$STAGING_DIR" -type f | wc -l | tr -d ' ')
total_size=$(du -sh "$STAGING_DIR" 2>/dev/null | cut -f1)

if [[ "$file_count" -eq 0 ]]; then
    log_error "Tidak ada file backup yang dihasilkan sama sekali."
    send_telegram_message "🔴 <b>${VPS_LABEL} - Backup GAGAL</b>
Tidak ada file backup yang dihasilkan - tidak ada DB/volume yang terdeteksi, atau semua step gagal.
Cek log: journalctl -u vps-backup.service"
    exit 1
fi

log_info "Mengunggah $file_count file ($total_size) ke ${RCLONE_REMOTE_PATH}"
if ! rclone copy "$STAGING_DIR" "$RCLONE_REMOTE_PATH" --stats-one-line -v; then
    log_error "Upload rclone gagal"
    send_telegram_message "🔴 <b>${VPS_LABEL} - Backup GAGAL</b>
Dump lokal berhasil (${file_count} file, ${total_size}) tapi UPLOAD ke storage gagal.
Cek log: journalctl -u vps-backup.service"
    exit 1
fi

log_info "Retensi: hapus backup lebih lama dari ${RETENTION_DAYS} hari di ${RCLONE_REMOTE_PATH}"
rclone delete "$RCLONE_REMOTE_PATH" --min-age "${RETENTION_DAYS}d" --rmdirs=false || \
    log_error "Retensi gagal dijalankan (backup baru tetap berhasil terkirim)"

if [[ "${#FAILED_STEPS[@]}" -eq 0 ]]; then
    log_info "Backup selesai - semua step berhasil (${file_count} file, ${total_size})"
    if [[ "$NOTIFY_ON_SUCCESS" == "true" ]]; then
        send_telegram_message "✅ <b>${VPS_LABEL} - Backup Berhasil</b>
${file_count} file, ${total_size}, retensi ${RETENTION_DAYS} hari."
    fi
else
    failed_list=$(IFS=', '; echo "${FAILED_STEPS[*]}")
    log_error "Backup selesai SEBAGIAN - gagal: $failed_list"
    send_telegram_message "🟡 <b>${VPS_LABEL} - Backup Sebagian Gagal</b>
Berhasil upload ${file_count} file (${total_size}), tapi step berikut GAGAL: ${failed_list}
Cek log: journalctl -u vps-backup.service"
fi
