# VPS Monitor — Notifikasi Telegram

Panduan lengkap untuk merekonstruksi/memasang ulang sistem notifikasi status VPS via Telegram: mengirim kondisi VPS **sangat detail** ke chat Telegram Anda saat VPS baru **menyala**, saat **dimatikan**, dan secara **berkala** selama VPS menyala (default tiap **1 jam**, bisa diubah).

> **Dua jalur instalasi tersedia — pilih salah satu:**
> - **[Opsi A — Otomatis (`install.sh`)](#4a-opsi-a--otomatis-installsh--rekomendasi)**: interaktif, tinggal jawab beberapa pertanyaan (Bot Token, Chat ID, dst.), langsung teruji & jalan stabil dalam sekali eksekusi.
> - **[Opsi B — Manual](#4b-opsi-b--manual-step-by-step)**: tiap langkah dilakukan sendiri, cocok kalau ingin paham detail atau kustomisasi di luar yang ditanyakan `install.sh`.

## 1. Fitur

| Event | Trigger | Script | Contoh judul pesan |
|---|---|---|---|
| VPS baru menyala | boot (systemd `ExecStart` / cron `@reboot`) | `notify-startup.sh` | 🟢 VPS BARU MENYALA |
| VPS sedang dimatikan/reboot | shutdown (systemd `ExecStop`) | `notify-shutdown.sh` | 🔴 VPS SEDANG DIMATIKAN |
| Laporan rutin | tiap interval (systemd timer / cron) | `notify-heartbeat.sh` | 📡 Status Berkala |

Setiap notifikasi berisi laporan kondisi VPS yang sama (dibangun oleh `vps-status-report.sh`):
hostname, waktu, uptime, load average, CPU usage, RAM, swap, disk `/`, IP private & public, jumlah systemd unit yang gagal, status container Docker, serta top 3 proses berdasarkan CPU dan RAM.

## 2. Struktur folder

```text
vps-monitor/
├── README.md                      # panduan ini
├── .env.example                   # template kredensial & konfigurasi (copy jadi .env)
├── lib/
│   └── telegram.sh                # fungsi kirim pesan ke Telegram Bot API
├── vps-status-report.sh           # kumpulkan metrik VPS -> teks HTML
├── notify-startup.sh              # notifikasi saat boot
├── notify-shutdown.sh             # notifikasi saat shutdown/reboot
├── notify-heartbeat.sh            # notifikasi berkala
├── systemd/
│   ├── vps-power-notify.service   # trigger startup + shutdown (1 service, 2 event)
│   ├── vps-heartbeat.service      # trigger heartbeat (dipanggil oleh timer)
│   └── vps-heartbeat.timer        # jadwal heartbeat (default: tiap 1 jam)
└── cron/
    └── crontab.sample             # alternatif non-systemd untuk heartbeat + startup
```

## 3. Prasyarat

- VPS Linux dengan `bash`, `curl`, `coreutils` (`free`, `df`, `ps`, `awk`) — sudah tersedia default di hampir semua distro.
- Disarankan systemd (Ubuntu/Debian/CentOS modern semua sudah pakai systemd). Kalau tidak ada systemd, gunakan alternatif cron (lihat bagian 6), tapi notifikasi shutdown tidak akan tersedia.
- Bot Telegram:
  1. Chat **@BotFather** di Telegram → kirim `/newbot` → ikuti instruksi (nama & username bot) → BotFather akan membalas dengan **token** bot.
  2. Dapatkan **Chat ID** tujuan:
     - Cara cepat: chat **@userinfobot**, dia akan membalas dengan Chat ID akun Anda.
     - Cara manual: kirim pesan apa saja ke bot yang baru dibuat, lalu buka `https://api.telegram.org/bot<TOKEN_ANDA>/getUpdates` di browser, cari `"chat":{"id": ...}`.

## 4. Instalasi

### 4a. Opsi A — Otomatis (`install.sh`) — rekomendasi

Siapkan dulu **Bot Token** dan **Chat ID** dari bagian 3 (Prasyarat), lalu salin folder `vps-monitor/` ini ke VPS. Dari dalam folder tersebut, jalankan:

```bash
sudo ./install.sh
```

Script akan bertanya secara interaktif, lalu mengerjakan sisanya sendiri:

```text
Telegram Bot Token (dari @BotFather): ..........
Telegram Chat ID (dari @userinfobot / getUpdates): ..........
Label VPS ini [default: <hostname>]: ..........
Interval heartbeat dalam menit [default: 60]: ..........
```

Setelah dijawab, `install.sh` otomatis:

1. **Menguji koneksi ke Telegram API** dengan token & chat ID yang baru diisi — kalau salah, langsung ketahuan sekarang juga (ada opsi lanjut/batalkan), bukan baru sadar setelah reboot dan tidak ada notifikasi masuk.
2. Menyalin semua file ke `/opt/vps-monitor`.
3. Menulis `.env` langsung dari jawaban Anda (tidak perlu buka `nano` sama sekali).
4. Mengatur permission (`chmod +x` untuk script, `chmod 600` untuk `.env`).
5. Memasang unit systemd, dengan interval heartbeat **langsung disesuaikan** ke angka yang Anda masukkan (tidak perlu edit file `.timer` manual).
6. `systemctl enable --now` untuk service startup/shutdown dan timer heartbeat — otomatis jalan lagi kapan pun VPS reboot, tanpa campur tangan manual lagi.

Kalau uji koneksi di langkah 1 berhasil, instalasi ini **satu kali jalan langsung stabil** — lewati bagian 4b dan 5, langsung ke bagian 7 untuk lihat contoh hasilnya atau bagian 8 kalau ada kendala.

### 4b. Opsi B — Manual (step by step)

```bash
# 1. Salin folder ini ke VPS, misalnya ke /opt/vps-monitor
sudo mkdir -p /opt/vps-monitor
sudo cp -r vps-monitor/* /opt/vps-monitor/

# 2. Buat file konfigurasi dari template, lalu isi TELEGRAM_BOT_TOKEN & TELEGRAM_CHAT_ID
cd /opt/vps-monitor
sudo cp .env.example .env
sudo nano .env

# 3. Jadikan semua script bisa dieksekusi
sudo chmod +x /opt/vps-monitor/*.sh

# 4. Amankan file .env (berisi token bot) - hanya root yang boleh baca
sudo chmod 600 /opt/vps-monitor/.env
```

## 5. Setup via systemd (rekomendasi — dilewati kalau sudah pakai `install.sh`)

```bash
# Salin unit files ke systemd
sudo cp /opt/vps-monitor/systemd/vps-power-notify.service /etc/systemd/system/
sudo cp /opt/vps-monitor/systemd/vps-heartbeat.service /etc/systemd/system/
sudo cp /opt/vps-monitor/systemd/vps-heartbeat.timer /etc/systemd/system/

sudo systemctl daemon-reload

# Aktifkan notifikasi startup + shutdown (jalan otomatis tiap boot & tiap kali mati)
sudo systemctl enable --now vps-power-notify.service

# Aktifkan jadwal heartbeat berkala
sudo systemctl enable --now vps-heartbeat.timer
```

Verifikasi:

```bash
# Cek status service/timer
systemctl status vps-power-notify.service
systemctl list-timers vps-heartbeat.timer

# Tes manual tanpa reboot (langsung kirim pesan startup/heartbeat sekarang)
sudo /opt/vps-monitor/notify-startup.sh
sudo /opt/vps-monitor/notify-heartbeat.sh

# Tes notifikasi shutdown tanpa benar-benar mematikan VPS
sudo systemctl stop vps-power-notify.service
```

### Mengubah interval heartbeat

Edit `OnUnitActiveSec` di `/etc/systemd/system/vps-heartbeat.timer` (contoh: `30min`, `2h`, `15min`), lalu:

```bash
sudo systemctl daemon-reload
sudo systemctl restart vps-heartbeat.timer
```

## 6. Setup via cron (alternatif, tanpa systemd)

```bash
crontab -e
# salin isi cron/crontab.sample yang relevan ke sini, sesuaikan path jika perlu
```

**Keterbatasan cron**: tidak ada event "shutdown" di cron, jadi notifikasi saat VPS dimatikan **tidak bisa** dibuat lewat cron — wajib pakai `systemd/vps-power-notify.service`. Cron hanya bisa menggantikan bagian startup (`@reboot`) dan heartbeat.

## 7. Contoh pesan yang dikirim

```
📡 VPS-Production-01 - Status Berkala

🖥 vps-jakarta-01
🕒 2026-09-09 14:00:03 WIB

Uptime: up 3 days, 4 hours, 12 minutes
Load Average (1/5/15m): 0.15 0.22 0.18
CPU Usage: 12%
RAM: 1.2G / 3.8G terpakai
Swap: 0B / 0B terpakai
Disk (/): 18G / 40G (46%)
IP Private: 10.0.0.5
IP Public: 203.0.113.1
Systemd Failed Units: 0
Docker Containers: 6 berjalan / 7 total

Top 3 proses (CPU):
  • docker-proxy    3.2%
  • node            2.1%
  • nginx           0.8%
Top 3 proses (RAM):
  • node            18.4%
  • mysqld          12.1%
  • docker-proxy    2.0%
```

## 8. Troubleshooting

| Gejala | Kemungkinan penyebab | Solusi |
|---|---|---|
| Tidak ada pesan masuk sama sekali | Token/Chat ID salah, atau belum pernah chat bot-nya duluan | Cek ulang `.env`, pastikan sudah kirim `/start` ke bot Anda |
| `Telegram API menolak pesan` di log | Format token salah, atau bot diblokir user | Jalankan manual `bash -x notify-heartbeat.sh` untuk lihat respons API |
| Notifikasi shutdown tidak pernah sampai | Jaringan sudah mati duluan sebelum `ExecStop` selesai kirim (lihat bagian 9) | Ini keterbatasan bawaan, bukan bug — lihat bagian 9 |
| `docker: command not found` muncul di laporan | Docker memang tidak terpasang di VPS ini | Normal, baris "Docker Containers" akan menampilkan "docker tidak terpasang" |
| Log heartbeat (mode cron) tidak ada | Folder log belum dibuat | `sudo mkdir -p /var/log/vps-monitor` |

## 9. Keterbatasan

- **Notifikasi shutdown bersifat best-effort.** Karena dikirim di detik-detik terakhir proses shutdown (lewat `ExecStop`), jika jaringan/DNS VPS sudah mati duluan sebelum `curl` sempat menghubungi Telegram API, pesan itu bisa gagal terkirim. Ini bukan bug, melainkan keterbatasan mekanisme shutdown itu sendiri.
- Metrik "CPU Usage" adalah snapshot sesaat (`top -bn1`), bukan rata-rata — bisa fluktuatif antar pemanggilan.
- IP publik diambil dari `api.ipify.org`; kalau VPS tidak punya akses internet keluar (atau IP publik memang tidak relevan, misalnya di belakang NAT), field ini akan tampil `n/a`.

## 10. Keamanan

- Jangan pernah commit file `.env` (berisi token bot asli) ke git — hanya `.env.example` yang boleh masuk repo.
- `chmod 600 .env` agar hanya root yang bisa membacanya.
- Token bot yang bocor bisa dicabut/diganti kapan saja lewat @BotFather → `/revoke`.

## 11. Uninstall

```bash
sudo systemctl disable --now vps-power-notify.service vps-heartbeat.timer
sudo rm /etc/systemd/system/vps-power-notify.service
sudo rm /etc/systemd/system/vps-heartbeat.service
sudo rm /etc/systemd/system/vps-heartbeat.timer
sudo systemctl daemon-reload
sudo rm -rf /opt/vps-monitor
```
