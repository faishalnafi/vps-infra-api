#!/usr/bin/env bash
# Backup Docker volume yang didaftarkan lewat DOCKER_VOLUMES di .env (comma-separated) ->
# 1 file .tar.gz per volume. HANYA volume yang didaftarkan eksplisit yang di-backup.
#
# Pakai container Alpine sementara untuk mount & tar volume-nya - cara ini portable, tidak
# bergantung pada path internal Docker (/var/lib/docker/volumes/...) yang spesifik per driver.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

OUT_DIR="${1:?Folder staging tujuan wajib diisi}"

[[ -z "${DOCKER_VOLUMES:-}" ]] && exit 0
if ! command -v docker >/dev/null 2>&1; then
    log_error "DOCKER_VOLUMES diisi di .env tapi docker tidak terpasang di VPS ini"
    exit 1
fi

had_error=0
ts=$(date +%Y%m%d_%H%M%S)
IFS=',' read -ra volumes <<< "$DOCKER_VOLUMES"

for raw_vol in "${volumes[@]}"; do
    vol="$(echo "$raw_vol" | xargs)"
    [[ -z "$vol" ]] && continue

    if ! docker volume inspect "$vol" >/dev/null 2>&1; then
        log_error "Docker volume '$vol' tidak ditemukan (cek DOCKER_VOLUMES di .env)"
        had_error=1
        continue
    fi

    filename="${VPS_LABEL}_volume_${vol}_${ts}.tar.gz"
    if docker run --rm \
        -v "${vol}:/source:ro" \
        -v "${OUT_DIR}:/backup" \
        alpine:latest \
        tar czf "/backup/${filename}" -C /source . >/dev/null 2>&1; then
        log_info "Docker volume: $vol -> $filename ($(du -h "$OUT_DIR/$filename" | cut -f1))"
    else
        log_error "Docker volume: gagal backup '$vol'"
        rm -f "$OUT_DIR/$filename"
        had_error=1
    fi
done

exit "$had_error"
