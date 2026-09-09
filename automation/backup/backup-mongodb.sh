#!/usr/bin/env bash
# Dump SEMUA database MongoDB dalam 1 file arsip (.archive.gz) - format native mongodump,
# BUKAN .sql karena MongoDB bukan relational. Dipanggil run-backup.sh dg argumen: folder staging.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

OUT_DIR="${1:?Folder staging tujuan wajib diisi}"

if ! command -v mongodump >/dev/null 2>&1; then
    exit 0
fi
if ! systemctl is-active --quiet mongod 2>/dev/null; then
    log_info "MongoDB terpasang tapi service tidak aktif - dilewati"
    exit 0
fi

MONGO_URI_ARGS=()
[[ -n "${MONGODB_URI:-}" ]] && MONGO_URI_ARGS+=(--uri="$MONGODB_URI")

ts=$(date +%Y%m%d_%H%M%S)
filename="${VPS_LABEL}_mongodb_all_${ts}.archive.gz"

if mongodump "${MONGO_URI_ARGS[@]}" --archive="$OUT_DIR/$filename" --gzip >/dev/null 2>&1; then
    log_info "MongoDB: semua database -> $filename ($(du -h "$OUT_DIR/$filename" | cut -f1))"
    exit 0
else
    log_error "MongoDB: gagal menjalankan mongodump (cek MONGODB_URI di .env)"
    rm -f "$OUT_DIR/$filename"
    exit 1
fi
