#!/usr/bin/env bash
# Backup data Nginx Proxy Manager: SQLite DB internal + config proxy host + sertifikat
# Let's Encrypt. Sering kelupaan tapi krusial - kalau hilang, semua proxy host & SSL harus
# disetel ulang manual. Path diambil dari NPM_DATA_DIR / NPM_LETSENCRYPT_DIR di .env (bind
# mount host, BUKAN path di dalam container).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

OUT_DIR="${1:?Folder staging tujuan wajib diisi}"

[[ -z "${NPM_DATA_DIR:-}" && -z "${NPM_LETSENCRYPT_DIR:-}" ]] && exit 0

had_error=0
ts=$(date +%Y%m%d_%H%M%S)
filename="${VPS_LABEL}_npm-data_${ts}.tar.gz"

paths_to_backup=()
[[ -n "${NPM_DATA_DIR:-}" && -d "${NPM_DATA_DIR}" ]] && paths_to_backup+=("$NPM_DATA_DIR")
[[ -n "${NPM_LETSENCRYPT_DIR:-}" && -d "${NPM_LETSENCRYPT_DIR}" ]] && paths_to_backup+=("$NPM_LETSENCRYPT_DIR")

if [[ "${#paths_to_backup[@]}" -eq 0 ]]; then
    log_error "NPM_DATA_DIR/NPM_LETSENCRYPT_DIR diisi di .env tapi folder tidak ditemukan di disk"
    exit 1
fi

if tar czf "$OUT_DIR/$filename" "${paths_to_backup[@]}" 2>/dev/null; then
    log_info "NPM data: ${paths_to_backup[*]} -> $filename ($(du -h "$OUT_DIR/$filename" | cut -f1))"
else
    log_error "NPM data: gagal membuat arsip"
    rm -f "$OUT_DIR/$filename"
    had_error=1
fi

exit "$had_error"
