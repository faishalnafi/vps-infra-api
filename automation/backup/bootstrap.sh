#!/usr/bin/env bash
# Bootstrap 1-baris untuk VPS Backup - dipakai lewat:
#   curl -sSL https://raw.githubusercontent.com/faishalnafi/vps-infra-api/pro/automation/backup/bootstrap.sh | sudo bash
#
# Clone repo (shallow, branch "pro"), lalu jalankan install.sh interaktif dari dalamnya.
# Stdin di-reattach ke /dev/tty supaya install.sh tetap bisa menerima input meski script
# ini sendiri dijalankan lewat pipe (curl | bash).
set -euo pipefail

REPO_URL="https://github.com/faishalnafi/vps-infra-api.git"
BRANCH="pro"
TARGET_DIR="/opt/vps-backup-src"

if [[ $EUID -ne 0 ]]; then
    echo "Jalankan sebagai root, contoh: curl -sSL <url> | sudo bash" >&2
    exit 1
fi

if [[ ! -e /dev/tty ]]; then
    echo "Tidak ada /dev/tty (bukan sesi terminal interaktif) - install.sh butuh input interaktif." >&2
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

echo "==> Mengunduh vps-backup dari ${REPO_URL} (branch: ${BRANCH})"
rm -rf "$TARGET_DIR"
git clone --depth 1 --branch "$BRANCH" --quiet "$REPO_URL" "$TARGET_DIR"

cd "$TARGET_DIR/automation/backup"
chmod +x install.sh

echo "==> Menjalankan installer interaktif..."
echo
exec bash install.sh < /dev/tty
