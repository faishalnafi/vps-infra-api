#!/usr/bin/env bash
# Mengumpulkan kondisi VPS terkini dan mencetaknya sebagai teks HTML siap kirim ke Telegram.
# File ini di-"source" oleh notify-*.sh - TIDAK mengirim apa pun sendiri, hanya membangun teks.

set -uo pipefail

build_status_report() {
    local hostname_str now_str uptime_str load_str cpu_pct
    local mem_line swap_line disk_line private_ip public_ip
    local failed_units docker_line top_cpu top_mem

    hostname_str=$(hostname)
    now_str=$(date '+%Y-%m-%d %H:%M:%S %Z')
    uptime_str=$(uptime -p 2>/dev/null || echo "n/a")
    load_str=$(cut -d ' ' -f1-3 /proc/loadavg 2>/dev/null || echo "n/a")

    # Persentase CPU idle -> dipakai (100 - idle)
    cpu_pct=$(top -bn1 2>/dev/null | awk -F'[,:]' '/%Cpu/ {for(i=1;i<=NF;i++) if ($i ~ /id/) {gsub(/[^0-9.]/,"",$i); print 100-$i"%"}}')
    [[ -z "$cpu_pct" ]] && cpu_pct="n/a"

    mem_line=$(free -h 2>/dev/null | awk '/^Mem:/ {printf "%s / %s terpakai", $3, $2}')
    swap_line=$(free -h 2>/dev/null | awk '/^Swap:/ {printf "%s / %s terpakai", $3, $2}')
    disk_line=$(df -h / 2>/dev/null | awk 'NR==2 {printf "%s / %s (%s)", $3, $2, $5}')

    private_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    public_ip=$(curl -sS --max-time 5 https://api.ipify.org 2>/dev/null)

    failed_units=$(systemctl --failed --no-legend 2>/dev/null | wc -l | tr -d ' ')

    if command -v docker >/dev/null 2>&1; then
        local running total
        running=$(docker ps -q 2>/dev/null | wc -l | tr -d ' ')
        total=$(docker ps -aq 2>/dev/null | wc -l | tr -d ' ')
        docker_line="${running} berjalan / ${total} total"
    else
        docker_line="docker tidak terpasang"
    fi

    top_cpu=$(ps -eo comm,%cpu --sort=-%cpu --no-headers 2>/dev/null | head -3 | awk '{printf "  • %-15s %s%%\n", $1, $2}')
    top_mem=$(ps -eo comm,%mem --sort=-%mem --no-headers 2>/dev/null | head -3 | awk '{printf "  • %-15s %s%%\n", $1, $2}')

    cat <<EOF
🖥 <b>${hostname_str}</b>
🕒 ${now_str}

<b>Uptime</b>: ${uptime_str}
<b>Load Average (1/5/15m)</b>: ${load_str}
<b>CPU Usage</b>: ${cpu_pct}
<b>RAM</b>: ${mem_line:-n/a}
<b>Swap</b>: ${swap_line:-n/a}
<b>Disk (/)</b>: ${disk_line:-n/a}
<b>IP Private</b>: ${private_ip:-n/a}
<b>IP Public</b>: ${public_ip:-n/a}
<b>Systemd Failed Units</b>: ${failed_units:-n/a}
<b>Docker Containers</b>: ${docker_line}

<b>Top 3 proses (CPU)</b>:
${top_cpu:-  • n/a}
<b>Top 3 proses (RAM)</b>:
${top_mem:-  • n/a}
EOF
}
