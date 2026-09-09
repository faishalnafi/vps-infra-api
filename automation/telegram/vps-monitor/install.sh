#!/usr/bin/env bash
# Instalasi INTERAKTIF VPS Monitor (Telegram notifier).
# Jalankan dari dalam folder vps-monitor/ ini sebagai root: sudo ./install.sh
#
# Script ini akan bertanya (Bot Token, Chat ID, label VPS, interval heartbeat),
# menguji koneksi ke Telegram API, lalu memasang & mengaktifkan semuanya
# sekali jalan - tidak perlu edit file manual sama sekali.
set -euo pipefail

INSTALL_DIR="/opt/vps-monitor"
SYSTEMD_DIR="/etc/systemd/system"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $EUID -ne 0 ]]; then
    echo "Script ini harus dijalankan sebagai root, contoh: sudo ./install.sh" >&2
    exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
    echo "curl tidak ditemukan. Install dulu: apt install curl / yum install curl" >&2
    exit 1
fi

echo "=============================================================="
echo " VPS Monitor - Instalasi Interaktif"
echo "=============================================================="
echo "Jawab beberapa pertanyaan berikut, sisanya berjalan otomatis."
echo

# -------------------------------------------------------------
# 1. Kumpulkan konfigurasi dari devops
# -------------------------------------------------------------
DEFAULT_LABEL="$(hostname)"

BOT_TOKEN=""
while [[ -z "$BOT_TOKEN" ]]; do
    read -rp "Telegram Bot Token (dari @BotFather): " BOT_TOKEN
done

CHAT_ID=""
while [[ -z "$CHAT_ID" ]]; do
    read -rp "Telegram Chat ID (dari @userinfobot / getUpdates): " CHAT_ID
done

read -rp "Label VPS ini [default: ${DEFAULT_LABEL}]: " VPS_LABEL_INPUT
VPS_LABEL_INPUT="${VPS_LABEL_INPUT:-$DEFAULT_LABEL}"

INTERVAL_INPUT=""
while true; do
    read -rp "Interval heartbeat dalam menit [default: 60]: " INTERVAL_INPUT
    INTERVAL_INPUT="${INTERVAL_INPUT:-60}"
    [[ "$INTERVAL_INPUT" =~ ^[0-9]+$ ]] && [[ "$INTERVAL_INPUT" -ge 1 ]] && break
    echo "  Harus berupa angka menit (contoh: 30, 60, 120)."
done

# -------------------------------------------------------------
# 2. Uji koneksi ke Telegram sebelum lanjut - biar kesalahan
#    token/chat id ketahuan sekarang, bukan pas sudah reboot.
# -------------------------------------------------------------
echo
echo "==> Menguji koneksi ke Telegram API..."
TEST_RESPONSE=$(curl -sS --max-time 15 -X POST \
    "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${CHAT_ID}" \
    --data-urlencode "text=✅ VPS Monitor berhasil terhubung dari ${VPS_LABEL} (uji coba instalasi)." \
    2>/dev/null) || TEST_RESPONSE=""

if [[ "$TEST_RESPONSE" == *'"ok":true'* ]]; then
    echo "    Berhasil! Cek Telegram Anda - harus sudah ada pesan uji coba."
else
    echo "!! Gagal mengirim pesan uji ke Telegram." >&2
    echo "   Respons API: ${TEST_RESPONSE:-<tidak ada respons - cek koneksi internet VPS>}" >&2
    echo
    read -rp "Lanjutkan instalasi meski uji koneksi gagal? (y/N): " CONTINUE_ANYWAY
    if [[ ! "$CONTINUE_ANYWAY" =~ ^[Yy]$ ]]; then
        echo "Instalasi dibatalkan. Perbaiki Bot Token/Chat ID lalu jalankan ulang: sudo ./install.sh" >&2
        exit 1
    fi
    echo "Melanjutkan instalasi - ingat untuk perbaiki .env nanti kalau notifikasi tidak pernah masuk."
fi

# -------------------------------------------------------------
# 3. Salin file ke lokasi instalasi
# -------------------------------------------------------------
echo
echo "==> Menyalin file ke ${INSTALL_DIR}"
mkdir -p "$INSTALL_DIR"
cp -r "$SCRIPT_DIR"/. "$INSTALL_DIR"/

# -------------------------------------------------------------
# 4. Tulis .env langsung dari jawaban interaktif (tidak perlu nano manual)
# -------------------------------------------------------------
echo "==> Menulis konfigurasi ke ${INSTALL_DIR}/.env"
cat > "$INSTALL_DIR/.env" <<EOF
TELEGRAM_BOT_TOKEN=${BOT_TOKEN}
TELEGRAM_CHAT_ID=${CHAT_ID}
VPS_LABEL=${VPS_LABEL_INPUT}
INTERVAL_MINUTES=${INTERVAL_INPUT}
EOF

# -------------------------------------------------------------
# 5. Permission
# -------------------------------------------------------------
echo "==> Mengatur permission"
chmod +x "$INSTALL_DIR"/*.sh
chmod 600 "$INSTALL_DIR/.env"

# -------------------------------------------------------------
# 6. Pasang unit systemd - interval heartbeat langsung disesuaikan
#    dengan jawaban interaktif (tidak perlu edit .timer manual).
# -------------------------------------------------------------
echo "==> Memasang unit systemd (interval heartbeat: ${INTERVAL_INPUT} menit)"
cp "$INSTALL_DIR/systemd/vps-power-notify.service" "$SYSTEMD_DIR/"
cp "$INSTALL_DIR/systemd/vps-heartbeat.service" "$SYSTEMD_DIR/"
sed "s/^OnUnitActiveSec=.*/OnUnitActiveSec=${INTERVAL_INPUT}min/" \
    "$INSTALL_DIR/systemd/vps-heartbeat.timer" > "$SYSTEMD_DIR/vps-heartbeat.timer"

systemctl daemon-reload

# -------------------------------------------------------------
# 7. Enable + start sekarang juga - otomatis jalan lagi tiap reboot
# -------------------------------------------------------------
echo "==> Mengaktifkan service & timer (otomatis jalan lagi tiap reboot, tanpa campur tangan manual)"
systemctl enable --now vps-power-notify.service
systemctl enable --now vps-heartbeat.timer

echo
echo "=============================================================="
echo " Instalasi selesai."
echo " VPS Monitor aktif dan akan otomatis jalan lagi kapan pun VPS"
echo " ini reboot, tanpa perlu setup ulang secara manual."
echo "=============================================================="
echo
echo "Cek status kapan saja:"
echo "  systemctl status vps-power-notify.service"
echo "  systemctl list-timers vps-heartbeat.timer"
echo
echo "Tes kirim laporan lengkap sekarang juga:"
echo "  sudo ${INSTALL_DIR}/notify-heartbeat.sh"
