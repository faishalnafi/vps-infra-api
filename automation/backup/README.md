# VPS Backup Otomatis

Panduan lengkap untuk memasang ulang sistem backup otomatis: dump database, volume Docker, dan data Nginx Proxy Manager (NPM), lalu diunggah ke object storage (Cloudflare R2 / AWS S3 / GCS / IDCloudHost S3) lewat `rclone`, dengan retensi otomatis dan notifikasi Telegram kalau ada yang gagal.

## Instalasi 1-baris (paling cepat)

```bash
curl -sSL https://raw.githubusercontent.com/faishalnafi/vps-infra-api/pro/automation/backup/bootstrap.sh | sudo bash
```

atau lewat `wget`:

```bash
wget -qO- https://raw.githubusercontent.com/faishalnafi/vps-infra-api/pro/automation/backup/bootstrap.sh | sudo bash
```

> ⚠️ **Prasyarat sebelum menjalankan 1-baris di atas**: remote `rclone` untuk storage tujuan **harus sudah dikonfigurasi** (lihat bagian "Setup rclone" di bawah) - installer akan berhenti dan minta Anda setup dulu kalau belum ada remote sama sekali.

> Kalau lebih suka baca dulu isinya sebelum eksekusi: unduh `bootstrap.sh` manual, `cat` untuk baca, baru `sudo bash bootstrap.sh`.

## 1. Apa saja yang di-backup

| Sumber | Format file | Kondisi |
|---|---|---|
| MySQL/MariaDB (per database) | `.sql.gz` | Otomatis dilewati kalau tidak terpasang/tidak aktif |
| PostgreSQL (per database) | `.sql.gz` | Otomatis dilewati kalau tidak terpasang/tidak aktif |
| MongoDB (semua database dalam 1 arsip) | `.archive.gz` (format native `mongodump`, bukan SQL) | Otomatis dilewati kalau tidak terpasang/tidak aktif |
| Docker volume (yang didaftarkan di `.env`) | `.tar.gz` per volume | Hanya volume yang eksplisit didaftarkan di `DOCKER_VOLUMES` |
| Data Nginx Proxy Manager (SQLite + config proxy + sertifikat SSL) | `.tar.gz` | Hanya kalau `NPM_DATA_DIR`/`NPM_LETSENCRYPT_DIR` diisi |

**Sengaja TIDAK di-backup**: kode aplikasi/config yang sudah ada di git (tinggal `git clone` lagi), file OS/sistem, package cache, log - semuanya reproducible atau memang boleh hilang.

### Konvensi nama file

```
{VPS_LABEL}_{jenis}_{nama-spesifik}_{YYYYMMDD_HHMMSS}.{ext}

Contoh:
vps-jakarta-01_mysql_wordpress_db_20260909_030000.sql.gz
vps-jakarta-01_postgres_analytics_20260909_030000.sql.gz
vps-jakarta-01_mongodb_all_20260909_030000.archive.gz
vps-jakarta-01_volume_app-uploads_20260909_030000.tar.gz
vps-jakarta-01_npm-data_20260909_030000.tar.gz
```

Format tanggal `YYYYMMDD_HHMMSS` sengaja dipilih supaya urutan abjad = urutan waktu.

## 2. Struktur folder

```text
backup/
├── README.md                      # panduan ini
├── .env.example                   # template konfigurasi (copy jadi .env)
├── bootstrap.sh                   # instalasi 1-baris
├── install.sh                     # instalasi interaktif
├── lib/
│   └── common.sh                  # load .env, logging, notifikasi Telegram
├── backup-mysql.sh                # dump MySQL/MariaDB per database
├── backup-postgres.sh             # dump PostgreSQL per database
├── backup-mongodb.sh              # dump MongoDB (1 arsip semua database)
├── backup-docker-volumes.sh       # tar.gz volume Docker yang didaftarkan
├── backup-npm-data.sh             # tar.gz data NPM (config + SSL)
├── run-backup.sh                  # orchestrator: jalankan semua step -> upload -> retensi -> notifikasi
├── systemd/
│   ├── vps-backup.service         # trigger backup (dipanggil oleh timer)
│   └── vps-backup.timer           # jadwal (default: tiap hari jam 03:00)
└── cron/
    └── crontab.sample             # alternatif non-systemd
```

## 3. Prasyarat

- VPS Linux dengan `bash`, `curl`, `tar`, `gzip` - sudah tersedia default hampir di semua distro.
- `rclone` (installer akan menawarkan pasang otomatis kalau belum ada).
- Tool dump sesuai database yang dipakai: `mysqldump` (paket `mysql-client`/`mariadb-client`), `pg_dump` (paket `postgresql-client`), `mongodump` (paket `mongodb-database-tools`). Yang tidak terpasang otomatis dilewati, tidak bikin backup gagal total.
- (Opsional) Docker, kalau mau backup volume.

### Setup rclone

Jalankan `rclone config` di VPS, lalu pilih provider sesuai yang Anda pakai:

**Cloudflare R2** (`n` new remote → type `s3` → provider `Cloudflare`):
```
rclone config
# n) New remote -> name: r2
# Storage: s3
# provider: Cloudflare
# access_key_id / secret_access_key: dari Cloudflare dashboard -> R2 -> Manage API Tokens
# endpoint: https://<ACCOUNT_ID>.r2.cloudflarestorage.com
```

**AWS S3** (`type: s3`, `provider: AWS`):
```
rclone config
# n) New remote -> name: s3
# Storage: s3
# provider: AWS
# access_key_id / secret_access_key: dari IAM
# region: sesuai bucket Anda
```

**Google Cloud Storage** (`type: google cloud storage`):
```
rclone config
# n) New remote -> name: gcs
# Storage: google cloud storage
# ikuti alur OAuth atau isi service_account_file (JSON key)
```

**IDCloudHost S3** (`type: s3`, `provider: Other`, endpoint custom):
```
rclone config
# n) New remote -> name: idcloudhost
# Storage: s3
# provider: Other
# access_key_id / secret_access_key: dari panel IDCloudHost
# endpoint: https://is3.cloudhost.id
```

Setelah dikonfigurasi, cek dengan `rclone listremotes` dan `rclone lsd <nama-remote>:` untuk memastikan bisa akses bucket-nya.

## 4. Instalasi

### 4a. Otomatis (`install.sh`) — rekomendasi

```bash
sudo ./install.sh
```

Akan menanyakan (setelah memastikan rclone remote sudah ada): label VPS, remote+path tujuan, retensi (hari), kredensial database (opsional, kosongkan kalau tidak dipakai), Docker volume yang mau di-backup (opsional), path data NPM (opsional), dan Telegram Bot Token/Chat ID (opsional, boleh reuse punya `automation/telegram/vps-monitor`). Uji akses ke remote dilakukan otomatis sebelum lanjut. Di akhir, ditawari langsung jalankan 1x backup percobaan.

### 4b. Manual

```bash
sudo mkdir -p /opt/vps-backup
sudo cp -r backup/* /opt/vps-backup/
cd /opt/vps-backup
sudo cp .env.example .env
sudo nano .env          # isi RCLONE_REMOTE_PATH dan konfigurasi lain
sudo chmod +x *.sh
sudo chmod 600 .env

sudo cp systemd/vps-backup.service /etc/systemd/system/
sudo cp systemd/vps-backup.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now vps-backup.timer
```

## 5. Setup via cron (alternatif, tanpa systemd)

```bash
crontab -e
# salin isi cron/crontab.sample, sesuaikan path kalau perlu
```

## 6. Verifikasi & tes manual

```bash
# Jalankan backup sekarang juga (tanpa menunggu jadwal)
sudo /opt/vps-backup/run-backup.sh

# Cek jadwal timer
systemctl list-timers vps-backup.timer

# Lihat isi remote setelah backup
rclone ls <RCLONE_REMOTE_PATH-tanpa-nama-file>
```

## 7. Restore

**MySQL/MariaDB:**
```bash
gunzip -c namafile.sql.gz | mysql -u root -p nama_database
```

**PostgreSQL:**
```bash
gunzip -c namafile.sql.gz | sudo -u postgres psql nama_database
```

**MongoDB** (arsip berisi SEMUA database sekaligus):
```bash
mongorestore --archive=namafile.archive.gz --gzip
```

**Docker volume:**
```bash
docker volume create nama_volume   # kalau volume belum ada
docker run --rm -v nama_volume:/target -v "$(pwd)":/backup alpine \
    tar xzf /backup/namafile.tar.gz -C /target
```

**Data NPM:**
```bash
sudo tar xzf namafile.tar.gz -C /   # arsip menyimpan path absolut aslinya
```

Unduh file dari remote dulu kalau belum ada di VPS: `rclone copy "<RCLONE_REMOTE_PATH>/namafile.sql.gz" .`

## 8. Retensi

`run-backup.sh` menjalankan `rclone delete <RCLONE_REMOTE_PATH> --min-age <RETENTION_DAYS>d` setiap kali selesai upload - otomatis menghapus file yang lebih tua dari `RETENTION_DAYS` (default 14 hari) di storage tujuan. Ini jalan di REMOTE, bukan di lokal VPS (tidak ada file backup yang disimpan permanen di VPS itu sendiri - staging cuma sementara di `/tmp`, dihapus lagi begitu proses selesai).

## 9. Keamanan

- Jangan pernah commit `.env` (berisi kredensial) ke git - hanya `.env.example` yang boleh masuk repo.
- `chmod 600 .env`.
- **Pakai user database khusus untuk backup, bukan root**, dengan privilege minimal. Contoh MySQL:
  ```sql
  CREATE USER 'backup_user'@'localhost' IDENTIFIED BY 'CHANGE_ME_STRONG_PASSWORD';
  GRANT SELECT, LOCK TABLES, SHOW VIEW, EVENT, TRIGGER ON *.* TO 'backup_user'@'localhost';
  FLUSH PRIVILEGES;
  ```
  lalu isi `MYSQL_BACKUP_USER=backup_user` dan `MYSQL_BACKUP_PASSWORD=...` di `.env`.
- Kredensial rclone (access key/secret tiap provider) tersimpan di `~/.config/rclone/rclone.conf` milik root - pastikan permission-nya default (`600`), jangan diubah jadi lebih terbuka.

## 10. Konsumsi resource

- Backup berjalan sebagai proses `oneshot` terjadwal (default tiap hari 03:00), bukan proses yang terus menyala - selesai jalan, langsung keluar dari memori.
- Beban resource sesungguhnya (CPU/IO) terjadi SAAT proses dump & kompresi berjalan (durasinya proporsional dengan ukuran database/volume Anda) - untuk database kecil-menengah biasanya selesai dalam hitungan detik-menit. Jadwalkan di jam sepi (default 03:00) untuk database besar supaya tidak mengganggu traffic produksi.
- File staging disimpan sementara di `/tmp` (auto-terhapus setelah upload) - pastikan `/tmp` (atau partisi yang menampungnya) punya ruang kosong cukup untuk menampung seluruh dump sebelum diupload.

## 11. Troubleshooting

| Gejala | Kemungkinan penyebab | Solusi |
|---|---|---|
| `rclone tidak terpasang` | Belum diinstall | Jalankan ulang `install.sh` dan pilih "Y" saat ditanya pasang rclone, atau manual: `curl https://rclone.org/install.sh \| sudo bash` |
| Upload gagal, backup lokal sukses | Kredensial rclone salah/expired, atau bucket permission kurang | `rclone lsd <remote>:` untuk tes koneksi manual |
| MySQL/PostgreSQL/MongoDB tidak muncul di backup | Service memang tidak aktif, atau tool dump (`mysqldump`/`pg_dump`/`mongodump`) belum terpasang | Cek `systemctl status <service>` dan pastikan client tools terpasang |
| Notifikasi Telegram tidak masuk | `TELEGRAM_BOT_TOKEN`/`TELEGRAM_CHAT_ID` kosong (memang opsional) atau salah | Isi di `.env`, ingat: notifikasi SUKSES hanya dikirim kalau `NOTIFY_ON_SUCCESS=true` |
| Retensi tidak menghapus file lama | `--min-age` menghitung dari waktu modifikasi file, bukan dari nama file | Pastikan `RETENTION_DAYS` sesuai ekspektasi; cek manual dengan `rclone lsl <remote>` |

## 12. Uninstall

```bash
sudo systemctl disable --now vps-backup.timer
sudo rm /etc/systemd/system/vps-backup.service
sudo rm /etc/systemd/system/vps-backup.timer
sudo systemctl daemon-reload
sudo rm -rf /opt/vps-backup
```

Backup yang sudah terlanjur ada di object storage TIDAK ikut terhapus oleh uninstall ini - hapus manual lewat `rclone` atau dashboard provider kalau memang tidak diperlukan lagi.
