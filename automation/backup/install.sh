#!/usr/bin/env bash
# Instalasi INTERAKTIF VPS Backup Otomatis.
# Jalankan dari dalam folder backup/ ini sebagai root: sudo ./install.sh
#
# PRASYARAT: rclone remote SUDAH dikonfigurasi (`rclone config`) untuk storage tujuan
# (Cloudflare R2 / AWS S3 / GCS / IDCloudHost S3) - lihat README.md bagian "Setup rclone"
# untuk panduan tiap provider. Script ini akan menawarkan memasang rclone kalau belum ada,
# tapi konfigurasi remote (kredensial provider) tetap perlu Anda lakukan sendiri lewat
# `rclone config` karena tiap provider beda field-nya.
set -euo pipefail

INSTALL_DIR="/opt/vps-backup"
SYSTEMD_DIR="/etc/systemd/system"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $EUID -ne 0 ]]; then
    echo "Script ini harus dijalankan sebagai root, contoh: sudo ./install.sh" >&2
    exit 1
fi

echo "=============================================================="
echo " VPS Backup Otomatis - Instalasi Interaktif"
echo "=============================================================="
echo

# -------------------------------------------------------------
# 1. Pastikan rclone terpasang
# -------------------------------------------------------------
if ! command -v rclone >/dev/null 2>&1; then
    echo "rclone belum terpasang."
    read -rp "Pasang rclone sekarang lewat installer resmi (curl https://rclone.org/install.sh | sudo bash)? (Y/n): " INSTALL_RCLONE
    if [[ "$INSTALL_RCLONE" =~ ^[Nn]$ ]]; then
        echo "Instalasi dibatalkan - pasang rclone manual dulu lalu jalankan ulang ./install.sh" >&2
        exit 1
    fi
    curl -sS https://rclone.org/install.sh | bash
fi

# -------------------------------------------------------------
# 2. Pastikan ada rclone remote yang sudah dikonfigurasi
# -------------------------------------------------------------
echo
echo "Remote rclone yang sudah dikonfigurasi di VPS ini:"
if ! rclone listremotes 2>/dev/null | sed 's/^/  - /'; then
    :
fi
if [[ -z "$(rclone listremotes 2>/dev/null)" ]]; then
    echo "  (belum ada remote sama sekali)"
    echo
    echo "Anda perlu setup remote dulu lewat 'rclone config' sebelum lanjut - lihat README.md" >&2
    echo "bagian 'Setup rclone' untuk panduan tiap provider (R2/S3/GCS/IDCloudHost)." >&2
    exit 1
fi

# -------------------------------------------------------------
# 3. Kumpulkan konfigurasi
# -------------------------------------------------------------
DEFAULT_LABEL="$(hostname)"

read -rp "Label VPS ini [default: ${DEFAULT_LABEL}]: " VPS_LABEL_INPUT
VPS_LABEL_INPUT="${VPS_LABEL_INPUT:-$DEFAULT_LABEL}"

RCLONE_REMOTE_PATH_INPUT=""
while [[ -z "$RCLONE_REMOTE_PATH_INPUT" ]]; do
    read -rp "Remote + path tujuan (contoh: r2:nama-bucket/backups): " RCLONE_REMOTE_PATH_INPUT
done

RETENTION_INPUT=""
while true; do
    read -rp "Retensi backup dalam hari [default: 14]: " RETENTION_INPUT
    RETENTION_INPUT="${RETENTION_INPUT:-14}"
    [[ "$RETENTION_INPUT" =~ ^[0-9]+$ ]] && [[ "$RETENTION_INPUT" -ge 1 ]] && break
    echo "  Harus berupa angka hari (contoh: 7, 14, 30)."
done

echo
echo "==> Menguji akses ke ${RCLONE_REMOTE_PATH_INPUT}..."
if rclone mkdir "$RCLONE_REMOTE_PATH_INPUT" 2>/dev/null; then
    echo "    Berhasil! Remote bisa diakses & folder tujuan siap."
else
    echo "!! Gagal mengakses/membuat folder di remote tersebut." >&2
    read -rp "Lanjutkan instalasi meski uji akses gagal? (y/N): " CONTINUE_ANYWAY
    if [[ ! "$CONTINUE_ANYWAY" =~ ^[Yy]$ ]]; then
        echo "Instalasi dibatalkan. Cek konfigurasi remote (rclone config) lalu jalankan ulang." >&2
        exit 1
    fi
fi

echo
echo "-- Opsional: database yang mau di-backup (kosongkan kalau tidak dipakai) --"
read -rp "MySQL/MariaDB - user backup (kosongkan utk pakai auth root ~/.my.cnf): " MYSQL_USER_INPUT
MYSQL_PASSWORD_INPUT=""
if [[ -n "$MYSQL_USER_INPUT" ]]; then
    read -rp "MySQL/MariaDB - password: " MYSQL_PASSWORD_INPUT
fi

read -rp "PostgreSQL - user backup [default: postgres, kosongkan utk pakai default]: " PG_USER_INPUT
PG_USER_INPUT="${PG_USER_INPUT:-postgres}"

read -rp "MongoDB - URI (kosongkan utk default mongodb://localhost:27017): " MONGO_URI_INPUT

echo
echo "-- Opsional: Docker volume & data NPM --"
read -rp "Nama Docker volume yang mau di-backup, pisahkan koma (kosongkan kalau tidak ada): " DOCKER_VOLUMES_INPUT
read -rp "Path NPM_DATA_DIR di host (kosongkan kalau tidak pakai NPM): " NPM_DATA_DIR_INPUT
read -rp "Path NPM_LETSENCRYPT_DIR di host (kosongkan kalau tidak pakai NPM): " NPM_LETSENCRYPT_DIR_INPUT

echo
echo "-- Opsional: notifikasi Telegram (boleh sama dengan bot vps-monitor) --"
read -rp "Telegram Bot Token (kosongkan utk skip notifikasi): " BOT_TOKEN_INPUT
CHAT_ID_INPUT=""
NOTIFY_SUCCESS_INPUT="false"
if [[ -n "$BOT_TOKEN_INPUT" ]]; then
    read -rp "Telegram Chat ID: " CHAT_ID_INPUT
    read -rp "Kirim notifikasi juga saat backup SUKSES, bukan cuma saat gagal? (y/N): " NOTIFY_SUCCESS_YN
    [[ "$NOTIFY_SUCCESS_YN" =~ ^[Yy]$ ]] && NOTIFY_SUCCESS_INPUT="true"
fi

# -------------------------------------------------------------
# 4. Salin file & tulis .env
# -------------------------------------------------------------
echo
echo "==> Menyalin file ke ${INSTALL_DIR}"
mkdir -p "$INSTALL_DIR"
cp -r "$SCRIPT_DIR"/. "$INSTALL_DIR"/

echo "==> Menulis konfigurasi ke ${INSTALL_DIR}/.env"
cat > "$INSTALL_DIR/.env" <<EOF
VPS_LABEL=${VPS_LABEL_INPUT}
RCLONE_REMOTE_PATH=${RCLONE_REMOTE_PATH_INPUT}
RETENTION_DAYS=${RETENTION_INPUT}

MYSQL_BACKUP_USER=${MYSQL_USER_INPUT}
MYSQL_BACKUP_PASSWORD=${MYSQL_PASSWORD_INPUT}

POSTGRES_BACKUP_USER=${PG_USER_INPUT}

MONGODB_URI=${MONGO_URI_INPUT}

DOCKER_VOLUMES=${DOCKER_VOLUMES_INPUT}

NPM_DATA_DIR=${NPM_DATA_DIR_INPUT}
NPM_LETSENCRYPT_DIR=${NPM_LETSENCRYPT_DIR_INPUT}

TELEGRAM_BOT_TOKEN=${BOT_TOKEN_INPUT}
TELEGRAM_CHAT_ID=${CHAT_ID_INPUT}
NOTIFY_ON_SUCCESS=${NOTIFY_SUCCESS_INPUT}
EOF

# -------------------------------------------------------------
# 5. Permission
# -------------------------------------------------------------
echo "==> Mengatur permission"
chmod +x "$INSTALL_DIR"/*.sh
chmod 600 "$INSTALL_DIR/.env"

# -------------------------------------------------------------
# 6. Pasang unit systemd
# -------------------------------------------------------------
echo "==> Memasang unit systemd (jadwal harian, 03:00)"
cp "$INSTALL_DIR/systemd/vps-backup.service" "$SYSTEMD_DIR/"
cp "$INSTALL_DIR/systemd/vps-backup.timer" "$SYSTEMD_DIR/"
systemctl daemon-reload
systemctl enable --now vps-backup.timer

echo
echo "=============================================================="
echo " Instalasi selesai. Backup terjadwal otomatis tiap hari 03:00,"
echo " dan tetap jalan lagi walau VPS reboot kapan pun."
echo "=============================================================="
echo
echo "Cek jadwal:"
echo "  systemctl list-timers vps-backup.timer"
echo

read -rp "Jalankan 1x backup percobaan sekarang? (Y/n): " RUN_NOW
if [[ ! "$RUN_NOW" =~ ^[Nn]$ ]]; then
    echo "==> Menjalankan backup percobaan (bisa makan waktu tergantung ukuran data)..."
    "$INSTALL_DIR/run-backup.sh"
fi
