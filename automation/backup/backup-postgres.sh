#!/usr/bin/env bash
# Dump semua database PostgreSQL (kecuali template), 1 file .sql.gz per database.
# Dipanggil oleh run-backup.sh dengan argumen: folder staging tujuan.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

OUT_DIR="${1:?Folder staging tujuan wajib diisi}"

if ! command -v pg_dump >/dev/null 2>&1; then
    exit 0
fi
if ! systemctl is-active --quiet postgresql 2>/dev/null; then
    log_info "PostgreSQL terpasang tapi service tidak aktif - dilewati"
    exit 0
fi

PG_USER="${POSTGRES_BACKUP_USER:-postgres}"

databases=$(sudo -u "$PG_USER" psql -Atqc "SELECT datname FROM pg_database WHERE datistemplate = false;" 2>/dev/null)

if [[ -z "$databases" ]]; then
    log_error "PostgreSQL: tidak bisa daftar database (cek POSTGRES_BACKUP_USER di .env & akses sudo)"
    exit 1
fi

had_error=0
ts=$(date +%Y%m%d_%H%M%S)
for db in $databases; do
    filename="${VPS_LABEL}_postgres_${db}_${ts}.sql.gz"
    if sudo -u "$PG_USER" pg_dump "$db" 2>/dev/null | gzip > "$OUT_DIR/$filename"; then
        log_info "PostgreSQL: $db -> $filename ($(du -h "$OUT_DIR/$filename" | cut -f1))"
    else
        log_error "PostgreSQL: gagal dump database '$db'"
        rm -f "$OUT_DIR/$filename"
        had_error=1
    fi
done

exit "$had_error"
