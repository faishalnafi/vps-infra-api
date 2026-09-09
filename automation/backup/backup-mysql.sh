#!/usr/bin/env bash
# Dump semua database MySQL/MariaDB (kecuali schema internal), 1 file .sql.gz per database.
# Dipanggil oleh run-backup.sh dengan argumen: folder staging tujuan.
# Exit 0 kalau MySQL/MariaDB tidak terpasang (dilewati, bukan error). Exit 1 kalau ADA
# database yang gagal di-dump.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

OUT_DIR="${1:?Folder staging tujuan wajib diisi}"

if ! command -v mysqldump >/dev/null 2>&1; then
    exit 0
fi
if ! (systemctl is-active --quiet mysql 2>/dev/null || systemctl is-active --quiet mariadb 2>/dev/null); then
    log_info "MySQL/MariaDB terpasang tapi service tidak aktif - dilewati"
    exit 0
fi

MYSQL_ARGS=()
[[ -n "${MYSQL_BACKUP_USER:-}" ]] && MYSQL_ARGS+=(-u "$MYSQL_BACKUP_USER")
[[ -n "${MYSQL_BACKUP_PASSWORD:-}" ]] && MYSQL_ARGS+=(-p"$MYSQL_BACKUP_PASSWORD")

databases=$(mysql "${MYSQL_ARGS[@]}" -N -e "SHOW DATABASES;" 2>/dev/null | grep -Ev '^(information_schema|performance_schema|mysql|sys)$')

if [[ -z "$databases" ]]; then
    log_error "MySQL: tidak bisa daftar database (cek kredensial MYSQL_BACKUP_USER/PASSWORD di .env)"
    exit 1
fi

had_error=0
ts=$(date +%Y%m%d_%H%M%S)
for db in $databases; do
    filename="${VPS_LABEL}_mysql_${db}_${ts}.sql.gz"
    if mysqldump "${MYSQL_ARGS[@]}" --single-transaction --quick --routines --triggers "$db" 2>/dev/null | gzip > "$OUT_DIR/$filename"; then
        log_info "MySQL: $db -> $filename ($(du -h "$OUT_DIR/$filename" | cut -f1))"
    else
        log_error "MySQL: gagal dump database '$db'"
        rm -f "$OUT_DIR/$filename"
        had_error=1
    fi
done

exit "$had_error"
