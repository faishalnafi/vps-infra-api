#!/usr/bin/env bash
# Instalasi otomatis VPS Monitor (Telegram notifier).
# Jalankan dari dalam folder vps-monitor/ ini sebagai root: sudo ./install.sh
#
# Yang dilakukan script ini:
#   1. Salin semua file ke /opt/vps-monitor
#   2. Buat .env dari .env.example (kalau belum ada - tidak menimpa .env lama)
#   3. Set permission yang benar (script executable, .env chmod 600)
#   4. Pasang & aktifkan unit systemd (power-notify + heartbeat timer)
set -euo pipefail

INSTALL_DIR="/opt/vps-monitor"
SYSTEMD_DIR="/etc/systemd/system"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $EUID -ne 0 ]]; then
    echo "Script ini harus dijalankan sebagai root, contoh: sudo ./install.sh" >&2
    exit 1
fi

echo "==> Menyalin file ke ${INSTALL_DIR}"
mkdir -p "$INSTALL_DIR"
cp -r "$SCRIPT_DIR"/. "$INSTALL_DIR"/

echo "==> Menyiapkan .env"
ENV_WAS_CREATED=0
if [[ -f "$INSTALL_DIR/.env" ]]; then
    echo "    .env sudah ada, tidak ditimpa."
else
    cp "$INSTALL_DIR/.env.example" "$INSTALL_DIR/.env"
    ENV_WAS_CREATED=1
    echo "    .env dibuat dari template (.env.example)."
fi

echo "==> Mengatur permission"
chmod +x "$INSTALL_DIR"/*.sh
chmod 600 "$INSTALL_DIR/.env"

echo "==> Memasang unit systemd"
cp "$INSTALL_DIR/systemd/vps-power-notify.service" "$SYSTEMD_DIR/"
cp "$INSTALL_DIR/systemd/vps-heartbeat.service" "$SYSTEMD_DIR/"
cp "$INSTALL_DIR/systemd/vps-heartbeat.timer" "$SYSTEMD_DIR/"
systemctl daemon-reload

echo "==> Mengaktifkan service & timer (otomatis jalan lagi tiap reboot)"
systemctl enable --now vps-power-notify.service
systemctl enable --now vps-heartbeat.timer

echo
echo "=============================================================="
echo "Instalasi selesai di ${INSTALL_DIR}"
echo "=============================================================="

if [[ "$ENV_WAS_CREATED" -eq 1 ]]; then
    cat <<EOF

LANGKAH TERAKHIR (WAJIB - .env masih berisi placeholder):
  1. sudo nano ${INSTALL_DIR}/.env
     -> isi TELEGRAM_BOT_TOKEN dan TELEGRAM_CHAT_ID
  2. sudo systemctl restart vps-power-notify.service
EOF
fi

cat <<EOF

Tes kirim pesan sekarang (tanpa perlu reboot):
  sudo ${INSTALL_DIR}/notify-heartbeat.sh

Cek status:
  systemctl status vps-power-notify.service
  systemctl list-timers vps-heartbeat.timer
EOF
