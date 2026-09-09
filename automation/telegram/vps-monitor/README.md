# VPS Monitor — Notifikasi Telegram

Panduan lengkap untuk merekonstruksi/memasang ulang sistem notifikasi status VPS via Telegram: mengirim kondisi VPS **sangat detail** ke chat Telegram Anda saat VPS baru **menyala**, saat **dimatikan**, dan secara **berkala** selama VPS menyala (default tiap **1 jam**, bisa diubah).

## Instalasi 1-baris (paling cepat)

Tidak perlu clone/copy manual - jalankan langsung dari VPS sebagai root:

```bash
curl -sSL https://raw.githubusercontent.com/faishalnafi/vps-infra-api/pro/automation/telegram/vps-monitor/bootstrap.sh | sudo bash
```

Perintah ini mengunduh repo (branch `pro`), lalu langsung menjalankan `install.sh` interaktif (bagian 4a) - tanya Bot Token, Chat ID, dst., seperti biasa. Kalau `curl` tidak tersedia, pakai `wget` sebagai gantinya:

```bash
wget -qO- https://raw.githubusercontent.com/faishalnafi/vps-infra-api/pro/automation/telegram/vps-monitor/bootstrap.sh | sudo bash
```

> ⚠️ **Catatan keamanan**: perintah di atas menjalankan script langsung dari internet sebagai root (`curl | sudo bash`). Ini praktik umum (aaPanel, Docker, dll. juga pakai pola yang sama), tapi kalau Anda lebih hati-hati, unduh dulu lalu baca isinya sebelum eksekusi:
> ```bash
> curl -sSL -o bootstrap.sh https://raw.githubusercontent.com/faishalnafi/vps-infra-api/pro/automation/telegram/vps-monitor/bootstrap.sh
> cat bootstrap.sh   # baca dulu isinya
> sudo bash bootstrap.sh
> ```

> **Tiga jalur instalasi tersedia — pilih salah satu:**
> - **1-baris di atas** — paling cepat, langsung dari GitHub, tanpa clone manual.
> - **[Opsi A — Otomatis (`install.sh`)](#4a-opsi-a--otomatis-installsh--rekomendasi)**: sama seperti di atas tapi Anda yang unduh foldernya sendiri dulu (mis. sudah punya salinan lokal, atau tidak mau eksekusi langsung dari internet).
> - **[Opsi B — Manual](#4b-opsi-b--manual-step-by-step)**: tiap langkah dilakukan sendiri, cocok kalau ingin paham detail atau kustomisasi di luar yang ditanyakan `install.sh`.

## 1. Fitur

| Event | Trigger | Script | Contoh judul pesan |
|---|---|---|---|
| VPS baru menyala | boot (systemd `ExecStart` / cron `@reboot`) | `notify-startup.sh` | 🟢 SEMUA SERVICE NORMAL / 🟡 ADA YANG BELUM NORMAL |
| VPS sedang dimatikan/reboot | shutdown (systemd `ExecStop`, **VPS menunggu sampai ini selesai**) | `notify-shutdown.sh` | 🔴 VPS SEDANG DIMATIKAN |
| Laporan rutin | tiap interval (systemd timer / cron) | `notify-heartbeat.sh` | 📡 Status Berkala |

Setiap notifikasi berisi 2 blok laporan:

1. **Laporan resource** (`vps-status-report.sh`): hostname, waktu, uptime, load average, CPU usage, RAM, swap, disk `/`, IP private & public, jumlah systemd unit yang gagal, status container Docker, top 3 proses berdasarkan CPU dan RAM.
2. **Laporan infrastruktur** (`service-check.sh`, **baru**): OS + versi lengkap, kernel, **control panel yang terpasang** (aaPanel, CyberPanel, Plesk, cPanel/WHM, DirectAdmin, HestiaCP, VestaCP, Webmin — atau "tidak terdeteksi" kalau VPS dikelola langsung lewat SSH/CLI), dan status ✅/❌ tiap service yang terdeteksi terpasang — Docker, web server (Nginx/Apache), DBMS (MySQL/MariaDB/PostgreSQL/MongoDB/Redis), PHP-FPM, plus service custom Anda sendiri lewat `EXTRA_SERVICES` di `.env`.

**Khusus notifikasi startup**, pesan **tidak langsung dikirim begitu OS boot** — script menunggu (dengan batas waktu) sampai semua service di atas benar-benar aktif, supaya begitu pesan 🟢 masuk, itu benar-benar berarti seluruh infrastruktur VPS sudah siap dipakai, bukan cuma OS-nya yang nyala. Detail mekanismenya di bagian 8.

**Format ini SAMA di ketiga jenis notifikasi** (startup/shutdown/heartbeat) — jadi tiap heartbeat berkala (default tiap 1 jam) juga otomatis menampilkan service mana saja yang lagi bermasalah (❌ + ringkasan di header pesan), bukan cuma sekali saat boot.

## 2. Struktur folder

```text
vps-monitor/
├── README.md                      # panduan ini
├── .env.example                   # template kredensial & konfigurasi (copy jadi .env)
├── bootstrap.sh                   # instalasi 1-baris (download repo lalu jalankan install.sh)
├── install.sh                     # instalasi interaktif (Opsi A)
├── lib/
│   └── telegram.sh                # fungsi kirim pesan ke Telegram Bot API
├── vps-status-report.sh           # kumpulkan metrik resource VPS -> teks HTML
├── service-check.sh               # deteksi OS/Docker/DBMS/web server/PHP-FPM + status -> teks HTML
├── notify-startup.sh              # notifikasi saat boot (dengan readiness-gate)
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

**Startup — semua service normal (kondisi ideal, 🟢):**

```
🟢 VPS-Production-01 BARU MENYALA — SEMUA SERVICE NORMAL
✅ Semua service infrastruktur yang terdeteksi sudah berjalan normal (dikonfirmasi dalam 45s).

OS: Ubuntu 22.04.3 LTS
Kernel: 5.15.0-91-generic (x86_64)
Control Panel: aaPanel (terdeteksi: /www/server/panel)

Service Terdeteksi:
  ✅ Docker (docker.service) — Docker version 24.0.7, build afdd53b
  ✅ Nginx (nginx.service) — nginx version: nginx/1.18.0 (Ubuntu)
  ✅ MySQL/MariaDB (mysql.service) — mysql  Ver 8.0.35 for Linux
  ✅ PHP-FPM (php8.1-fpm.service) — PHP 8.1.2 (cli) (built: Nov 14 2023)
  ✅ Redis (redis-server.service) — Redis server v=7.0.11

🖥 vps-jakarta-01
🕒 2026-09-09 14:00:03 WIB
Uptime: up 3 minutes
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

**Startup — ada yang belum normal setelah batas waktu (🟡):**

```
🟡 VPS-Production-01 BARU MENYALA — ADA SERVICE BELUM NORMAL
⚠️ Setelah menunggu 300s, service berikut BELUM aktif: MySQL/MariaDB, PHP-FPM

OS: Ubuntu 22.04.3 LTS
Kernel: 5.15.0-91-generic (x86_64)
Control Panel: aaPanel (terdeteksi: /www/server/panel)

Service Terdeteksi:
  ✅ Docker (docker.service) — Docker version 24.0.7, build afdd53b
  ✅ Nginx (nginx.service) — nginx version: nginx/1.18.0 (Ubuntu)
  ❌ MySQL/MariaDB (mysql.service) — mysql  Ver 8.0.35 for Linux
  ❌ PHP-FPM (php8.1-fpm.service) — PHP 8.1.2 (cli) (built: Nov 14 2023)
...
```

Header 🟢 vs 🟡 (dan ✅/❌ per baris service) itulah sinyal cepat bagi devops: kalau 🟢, seluruh infrastruktur dipastikan sudah siap; kalau 🟡, langsung terlihat jelas apa saja yang perlu dicek manual.

## 8. Readiness Gate & Konsumsi Resource

### Bagaimana readiness-gate bekerja (khusus startup)

`notify-startup.sh` tidak langsung kirim pesan begitu OS selesai boot. Alurnya:

1. Tunggu 15 detik awal (jaringan/DNS baru siap).
2. Polling tiap `READY_CHECK_INTERVAL_SECONDS` (default **10 detik**): cek SEMUA service yang terdeteksi terpasang via `systemctl is-active` saja (lihat catatan resource di bawah).
3. Begitu semua aktif → langsung kirim pesan 🟢 (tidak menunggu sampai batas waktu habis).
4. Kalau sampai `READY_MAX_WAIT_SECONDS` (default **300 detik / 5 menit**) masih ada yang belum aktif → tetap kirim pesan, tapi ditandai 🟡 dengan daftar service yang belum aktif. **Tidak pernah didiamkan tanpa notifikasi sama sekali.**

Kedua nilai ini bisa diubah lewat `.env` (`READY_MAX_WAIT_SECONDS`, `READY_CHECK_INTERVAL_SECONDS`) — lihat `.env.example`.

### Deteksi control panel

`service-check.sh` juga mengenali control panel VPS yang umum dipakai, berdasarkan direktori instalasi khasnya masing-masing (bukan lewat API resmi tiap panel, jadi sifatnya best-effort — tapi tiap panel biasanya punya lokasi instalasi unik yang jarang bentrok):

| Panel | Ditandai lewat |
|---|---|
| aaPanel | `/www/server/panel` |
| CyberPanel | `/usr/local/CyberPanel` |
| Plesk | `/usr/local/psa` |
| cPanel/WHM | `/usr/local/cpanel` |
| DirectAdmin | `/usr/local/directadmin` |
| HestiaCP | `/usr/local/hestia` |
| VestaCP | `/usr/local/vesta` |
| Webmin | `/usr/share/webmin` |

Kalau tidak ada satu pun yang cocok, laporan akan menampilkan `Tidak terdeteksi (kemungkinan tanpa panel / dikelola lewat CLI-SSH langsung)`. Pengecekan ini hanya beberapa `[[ -d ... ]]` (test direktori) — tidak spawn proses sama sekali, jadi tidak menambah beban apa pun.

### Bagaimana notifikasi shutdown dijamin terkirim sebelum VPS benar-benar mati

`vps-power-notify.service` diset `Before=shutdown.target reboot.target halt.target` + `DefaultDependencies=no`. Artinya systemd **wajib menjalankan `ExecStop` (notify-shutdown.sh) dan menunggunya selesai — atau timeout — sebelum proses shutdown/reboot lanjut ke tahap power-off**. VPS tidak langsung mati begitu perintah shutdown diberikan; ia menunggu skrip ini dulu. Kombinasi dengan `After=network-online.target` juga membuat jaringan baru dimatikan **setelah** service ini selesai, jadi script masih sempat kirim ke internet. Batas waktu totalnya `TimeoutStopSec=30` di `vps-power-notify.service` (bisa diubah kalau perlu margin lebih besar).

### Konsumsi resource — dipastikan ringan

- **Bukan daemon.** Semua script (`notify-startup.sh`, `notify-heartbeat.sh`, `notify-shutdown.sh`) dijalankan systemd sebagai proses **sekali-jalan (`Type=oneshot`)** — begitu selesai, prosesnya keluar total dari memori. Tidak ada yang "nempel" resident di RAM di antara dua kejadian.
- **Heartbeat & shutdown**: total eksekusi biasanya **di bawah 2 detik** (beberapa `systemctl is-active`/perintah versi ringan + 1 request HTTP ke Telegram).
- **Startup (readiness-gate)**: bisa berlangsung sampai `READY_MAX_WAIT_SECONDS` (default 5 menit) kalau ada service yang lambat siap, TAPI hampir seluruh waktu itu adalah `sleep` (CPU ~0%), bukan polling berat. Tiap siklus polling hanya memanggil `systemctl is-active` (baca state internal systemd, sangat murah) — perintah yang lebih berat seperti `docker --version`/`nginx -v`/`php -v` **hanya dijalankan sekali di akhir**, untuk isi laporan final, bukan di setiap iterasi polling.
- **Di luar 3 kejadian ini, tidak ada proses berjalan sama sekali** — heartbeat berikutnya baru aktif lagi sesuai jadwal timer (default tiap 1 jam), lalu selesai dan hilang lagi dari memori.

## 9. Troubleshooting

| Gejala | Kemungkinan penyebab | Solusi |
|---|---|---|
| Tidak ada pesan masuk sama sekali | Token/Chat ID salah, atau belum pernah chat bot-nya duluan | Cek ulang `.env`, pastikan sudah kirim `/start` ke bot Anda |
| `Telegram API menolak pesan` di log | Format token salah, atau bot diblokir user | Jalankan manual `bash -x notify-heartbeat.sh` untuk lihat respons API |
| VPS terasa lambat mati/reboot (~sampai 30 detik) | Normal — systemd sengaja menunggu `notify-shutdown.sh` (lihat bagian 8) sebelum lanjut power-off | Bukan bug. Bisa dipercepat dengan mengecilkan `TimeoutStopSec` di `vps-power-notify.service` (risiko: notifikasi shutdown lebih sering gagal kalau Telegram API lambat merespons) |
| Notifikasi shutdown tidak pernah sampai meski sudah menunggu | Telegram API sendiri yang tidak terjangkau (bukan soal timing lagi — lihat bagian 8) | Cek `curl -sS https://api.telegram.org` dari VPS; kalau VPS memang tanpa akses internet keluar saat shutdown, ini di luar kendali script |
| Pesan startup 🟡 padahal service sebenarnya sudah aktif | `READY_MAX_WAIT_SECONDS` terlalu pendek untuk service yang lambat start (mis. DB besar yang lama recovery) | Perbesar `READY_MAX_WAIT_SECONDS` di `.env`, lalu `systemctl restart vps-power-notify.service` |
| `docker: command not found` / service tidak muncul di laporan | Service memang tidak terpasang di VPS ini, atau tidak terdaftar sebagai unit systemd (mis. dijalankan manual/di dalam container) | Normal untuk yang memang tidak terpasang; untuk service custom, daftarkan lewat `EXTRA_SERVICES` di `.env` |
| Log heartbeat (mode cron) tidak ada | Folder log belum dibuat | `sudo mkdir -p /var/log/vps-monitor` |

## 10. Keterbatasan

- **Notifikasi shutdown terjamin *dicoba* sebelum VPS power-off (systemd menunggu, lihat bagian 8), tapi pengiriman ke Telegram sendiri tetap bergantung pada Telegram API bisa dijangkau.** Kalau VPS benar-benar kehilangan akses internet sebelum `TimeoutStopSec` habis, pesan itu tetap bisa gagal — itu bukan lagi soal timing/urutan (yang sudah dijamin), melainkan ketersediaan jaringan/API di luar kendali script.
- Deteksi service (bagian 8) hanya mengenali yang terdaftar sebagai **unit systemd**. Aplikasi yang dijalankan manual, lewat `screen`/`tmux`, atau di dalam container tanpa unit systemd sendiri tidak akan otomatis terdeteksi — tambahkan lewat `EXTRA_SERVICES` di `.env` kalau ingin ikut dipantau.
- Metrik "CPU Usage" adalah snapshot sesaat (`top -bn1`), bukan rata-rata — bisa fluktuatif antar pemanggilan.
- IP publik diambil dari `api.ipify.org`; kalau VPS tidak punya akses internet keluar (atau IP publik memang tidak relevan, misalnya di belakang NAT), field ini akan tampil `n/a`.

## 11. Keamanan

- Jangan pernah commit file `.env` (berisi token bot asli) ke git — hanya `.env.example` yang boleh masuk repo (`.gitignore` di root repo sudah memblokir ini).
- `chmod 600 .env` agar hanya root yang bisa membacanya.
- Token bot yang bocor bisa dicabut/diganti kapan saja lewat @BotFather → `/revoke`.

## 12. Uninstall

```bash
sudo systemctl disable --now vps-power-notify.service vps-heartbeat.timer
sudo rm /etc/systemd/system/vps-power-notify.service
sudo rm /etc/systemd/system/vps-heartbeat.service
sudo rm /etc/systemd/system/vps-heartbeat.timer
sudo systemctl daemon-reload
sudo rm -rf /opt/vps-monitor
```
