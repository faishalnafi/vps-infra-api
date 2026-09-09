#!/usr/bin/env bash
# Bootstrap 1-baris untuk VPS Monitor - dipakai lewat:
#   curl -sSL https://raw.githubusercontent.com/faishalnafi/vps-infra-api/pro/automation/telegram/vps-monitor/bootstrap.sh | sudo bash
#
# Yang dilakukan: pasang git kalau belum ada, clone repo (shallow, branch "pro"),
# lalu jalankan install.sh interaktif dari dalamnya.
#
# CATATAN TEKNIS: script ini sendiri dijalankan lewat pipe ("curl | bash"), jadi stdin-nya
# adalah isi script itu sendiri, bukan keyboard Anda. Supaya install.sh tetap bisa menerima
# jawaban interaktif (Bot Token, Chat ID, dst.), stdin-nya di-reattach paksa ke /dev/tty
# sebelum dijalankan - lihat baris "exec bash install.sh < /dev/tty" di bawah.
set -euo pipefail

REPO_URL="https://github.com/faishalnafi/vps-infra-api.git"
BRANCH="pro"
TARGET_DIR="/opt/vps-monitor-src"

if [[ $EUID -ne 0 ]]; then
    echo "Jalankan sebagai root, contoh: curl -sSL <url> | sudo bash" >&2
    exit 1
fi

if [[ ! -e /dev/tty ]]; then
    echo "Tidak ada /dev/tty (bukan sesi terminal interaktif) - install.sh butuh input interaktif." >&2
    echo "Jalankan langsung dari terminal SSH biasa, bukan dari script non-interaktif." >&2
    exit 1
fi

if ! command -v git >/dev/null 2>&1; then
    echo "==> git belum terpasang, memasang dulu..."
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update -qq && apt-get install -y -qq git
    elif command -v yum >/dev/null 2>&1; then
        yum install -y -q git
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y -q git
    else
        echo "Tidak bisa auto-install git di distro ini. Install git manual lalu jalankan ulang." >&2
        exit 1
    fi
fi

echo "==> Mengunduh vps-monitor dari ${REPO_URL} (branch: ${BRANCH})"
rm -rf "$TARGET_DIR"
git clone --depth 1 --branch "$BRANCH" --quiet "$REPO_URL" "$TARGET_DIR"

cd "$TARGET_DIR/automation/telegram/vps-monitor"
chmod +x install.sh

echo "==> Menjalankan installer interaktif..."
echo
exec bash install.sh < /dev/tty
