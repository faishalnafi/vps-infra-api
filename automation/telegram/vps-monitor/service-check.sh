#!/usr/bin/env bash
# Deteksi service infrastruktur yang TERPASANG di VPS ini (Docker, DBMS, web server,
# PHP-FPM, dst.) lewat systemd unit, lalu cek status aktif/tidaknya + versinya.
# File ini di-"source" oleh notify-*.sh - TIDAK mengirim apa pun sendiri.
#
# Hanya service yang benar-benar terdeteksi terpasang yang dicek/dilaporkan - kalau VPS
# tidak punya PostgreSQL misalnya, PostgreSQL tidak akan muncul/ditunggu sama sekali.
#
# Tambahan service custom (opsional) lewat .env:
#   EXTRA_SERVICES="myapp.service,worker.service"

set -uo pipefail

declare -a SVC_LABELS=()
declare -a SVC_UNITS=()
declare -a SVC_ACTIVE=()
declare -a SVC_VERSIONS=()

# Kontrol internal: 1 = ambil string versi (agak berat, spawn proses "-v"/"--version"),
# 0 = lewati (dipakai saat polling cepat supaya sangat ringan). Diatur oleh detect_installed_services().
_SVC_FETCH_VERSIONS=1

# args: label, nama-unit-systemd (boleh pakai wildcard, mis. "php*-fpm.service"), perintah versi (opsional)
_svc_add_candidate() {
    local label="$1" unit_pattern="$2" ver_cmd="${3:-}"
    local unit_real=""

    if [[ "$unit_pattern" == *'*'* ]]; then
        unit_real=$(systemctl list-unit-files "$unit_pattern" --no-legend 2>/dev/null | awk '{print $1}' | head -1)
    elif systemctl list-unit-files "$unit_pattern" --no-legend 2>/dev/null | grep -q .; then
        unit_real="$unit_pattern"
    fi
    [[ -z "$unit_real" ]] && return 0

    # Lewati kalau unit yang sama sudah tercatat (mis. kandidat MySQL & MariaDB match unit yang sama)
    local i
    for i in "${!SVC_UNITS[@]}"; do
        [[ "${SVC_UNITS[$i]}" == "$unit_real" ]] && return 0
    done

    # Ini satu-satunya pengecekan yang jalan tiap polling - "systemctl is-active" sangat
    # ringan (baca state internal systemd, tanpa spawn proses berat).
    local active=0
    systemctl is-active --quiet "$unit_real" 2>/dev/null && active=1

    local ver="n/a"
    if [[ "$_SVC_FETCH_VERSIONS" -eq 1 && -n "$ver_cmd" ]]; then
        ver=$(eval "$ver_cmd" 2>/dev/null | head -1)
        [[ -z "$ver" ]] && ver="n/a"
    fi

    SVC_LABELS+=("$label")
    SVC_UNITS+=("$unit_real")
    SVC_ACTIVE+=("$active")
    SVC_VERSIONS+=("$ver")
}

# Isi ulang SVC_* dengan kondisi TERKINI.
# args: fetch_versions (1=ambil versi lengkap utk laporan akhir, 0=cek status saja/ringan utk polling). Default 1.
detect_installed_services() {
    _SVC_FETCH_VERSIONS="${1:-1}"
    SVC_LABELS=(); SVC_UNITS=(); SVC_ACTIVE=(); SVC_VERSIONS=()

    _svc_add_candidate "Docker"          "docker.service"        "docker --version"
    _svc_add_candidate "Nginx"           "nginx.service"         "nginx -v"
    _svc_add_candidate "Apache"          "apache2.service"       "apache2 -v | head -1"
    _svc_add_candidate "Apache (httpd)"  "httpd.service"         "httpd -v | head -1"
    _svc_add_candidate "MySQL/MariaDB"   "mysql.service"         "mysql --version"
    _svc_add_candidate "MariaDB"         "mariadb.service"       "mysql --version"
    _svc_add_candidate "PostgreSQL"      "postgresql.service"    "psql --version"
    _svc_add_candidate "MongoDB"         "mongod.service"        "mongod --version | head -1"
    _svc_add_candidate "Redis"           "redis-server.service"  "redis-server --version"
    _svc_add_candidate "Redis"           "redis.service"         "redis-server --version"
    _svc_add_candidate "PHP-FPM"         "php*-fpm.service"      "php -v | head -1"

    if [[ -n "${EXTRA_SERVICES:-}" ]]; then
        local IFS=','
        local raw_list=($EXTRA_SERVICES)
        local s
        for s in "${raw_list[@]}"; do
            s="$(echo "$s" | xargs)"
            [[ -n "$s" ]] && _svc_add_candidate "Custom: $s" "$s" ""
        done
    fi
}

# Return 0 kalau SEMUA service yang terdeteksi terpasang berstatus aktif.
# SENGAJA skip pengambilan versi (fetch_versions=0) - dipanggil berulang tiap
# CHECK_INTERVAL_SECONDS saat menunggu boot, jadi harus seringan mungkin.
all_services_active() {
    detect_installed_services 0
    local i
    for i in "${!SVC_ACTIVE[@]}"; do
        [[ "${SVC_ACTIVE[$i]}" -eq 0 ]] && return 1
    done
    return 0
}

# Deteksi control panel VPS yang umum dipakai, berdasarkan direktori instalasi khas
# masing-masing panel. Best-effort (bukan lewat API resmi tiap panel) tapi cukup akurat
# karena tiap panel punya lokasi instalasi yang khas & jarang bentrok satu sama lain.
# Sangat ringan - cuma beberapa "[[ -d ... ]]", tidak spawn proses apa pun.
detect_control_panel() {
    if [[ -d /www/server/panel ]]; then
        echo "aaPanel (terdeteksi: /www/server/panel)"
    elif [[ -d /usr/local/CyberPanel ]] || [[ -d /usr/local/CyberCP ]]; then
        echo "CyberPanel (terdeteksi: /usr/local/CyberPanel)"
    elif [[ -d /usr/local/psa ]]; then
        echo "Plesk (terdeteksi: /usr/local/psa)"
    elif [[ -d /usr/local/cpanel ]]; then
        echo "cPanel/WHM (terdeteksi: /usr/local/cpanel)"
    elif [[ -d /usr/local/directadmin ]]; then
        echo "DirectAdmin (terdeteksi: /usr/local/directadmin)"
    elif [[ -d /usr/local/hestia ]]; then
        echo "HestiaCP (terdeteksi: /usr/local/hestia)"
    elif [[ -d /usr/local/vesta ]]; then
        echo "VestaCP (terdeteksi: /usr/local/vesta)"
    elif [[ -d /usr/share/webmin ]] || [[ -d /etc/webmin ]]; then
        echo "Webmin (terdeteksi: /usr/share/webmin)"
    else
        echo "Tidak terdeteksi (kemungkinan tanpa panel / dikelola lewat CLI-SSH langsung)"
    fi
}

# Bangun teks laporan OS + panel + service (panggil SETELAH detect_installed_services / all_services_active)
build_services_report() {
    local os_pretty="n/a" kernel_ver arch panel_info
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        os_pretty="$(. /etc/os-release && echo "$PRETTY_NAME")"
    fi
    kernel_ver=$(uname -r)
    arch=$(uname -m)
    panel_info=$(detect_control_panel)

    local out="<b>OS</b>: ${os_pretty}
<b>Kernel</b>: ${kernel_ver} (${arch})
<b>Control Panel</b>: ${panel_info}

<b>Service Terdeteksi</b>:"

    if [[ "${#SVC_LABELS[@]}" -eq 0 ]]; then
        out="${out}
  • Tidak ada service infrastruktur yang terdeteksi (Docker/DBMS/web server/PHP-FPM)"
    else
        local i icon
        for i in "${!SVC_LABELS[@]}"; do
            icon="✅"
            [[ "${SVC_ACTIVE[$i]}" -eq 0 ]] && icon="❌"
            out="${out}
  ${icon} ${SVC_LABELS[$i]} (${SVC_UNITS[$i]}) — ${SVC_VERSIONS[$i]}"
        done
    fi

    echo "$out"
}

# Ringkasan nama service yang SEDANG TIDAK aktif (string kosong kalau semua aktif)
build_down_services_summary() {
    local i down=()
    for i in "${!SVC_LABELS[@]}"; do
        [[ "${SVC_ACTIVE[$i]}" -eq 0 ]] && down+=("${SVC_LABELS[$i]}")
    done
    if [[ "${#down[@]}" -eq 0 ]]; then
        echo ""
    else
        local IFS=', '
        echo "${down[*]}"
    fi
}
