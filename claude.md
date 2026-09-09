claude_md_content = """# CLAUDE.md - Agent Instructions & Project Guidelines

## 📌 Repository Context
- **Repository URL**: `https://github.com/faishalnafi/vps-infra-api`
- **Purpose**: Infrastructure as Code (IaC), Docker Compose orchestration, advanced Nginx Proxy Manager (NPM) routing/security snippets, server automation scripts, and Telegram notification bots for Linux VPS environments.
- **Canonical Domain**: `faishalnafi.com` (Subdomains for examples/templates: `api.faishalnafi.com`, `npm.faishalnafi.com`, `status.faishalnafi.com`, `auth.faishalnafi.com`, `app.faishalnafi.com`).

---

## 🚨 CRITICAL SANITIZATION & SECURITY RULES (MANDATORY)
When processing real-world configurations, pasted snippets, or imported server files, the agent **MUST ALWAYS** sanitize and convert all sensitive production data into safe templated placeholders:

1. **API Keys, Secrets & Passwords**:
   - Replace with: `CHANGE_ME_STRONG_PASSWORD`, `YOUR_DB_PASSWORD`, `YOUR_API_SECRET_KEY`
2. **Telegram Bot & Alert Credentials**:
   - Bot Token: `${TELEGRAM_BOT_TOKEN}` or `YOUR_TELEGRAM_BOT_TOKEN`
   - Chat ID: `${TELEGRAM_CHAT_ID}` or `YOUR_TELEGRAM_CHAT_ID`
3. **Domains & Hostnames**:
   - Replace all real-world domains with `faishalnafi.com` or relevant subdomains (`api.faishalnafi.com`, `npm.faishalnafi.com`, etc.).
4. **IP Addresses**:
   - Public Server IP: `<YOUR_SERVER_PUBLIC_IP>` or `203.0.113.1` (RFC 5737 documentation IP).
   - Private / Docker Subnets: `192.168.1.100`, `172.20.0.0/16`, `10.0.0.1`.
5. **Certificates & Private Keys**:
   - Never output real private keys. Use placeholder blocks:
     `-----BEGIN PRIVATE KEY----- ... YOUR_PRIVATE_KEY ... -----END PRIVATE KEY-----`
6. **Email Addresses**:
   - Replace with `admin@faishalnafi.com` or `alerts@faishalnafi.com`.

---

## 📁 Repository Directory Structure

```text
vps-infra-api/
├── .gitignore
├── LICENSE
├── README.md
├── claude.md
├── docker-compose/
│   ├── base-infra/            # NPM, Portainer, Watchtower
│   │   ├── docker-compose.yml
│   │   └── .env.example
│   ├── api-services/          # Custom API services & microservices
│   │   ├── docker-compose.yml
│   │   └── .env.example
│   └── monitoring/            # Uptime Kuma, Prometheus, Grafana
│       ├── docker-compose.yml
│       └── .env.example
├── nginx-proxy-manager/
│   ├── advanced-snippets/     # Modular Nginx configs to include in NPM
│   │   ├── cors-headers.conf
│   │   ├── security-headers.conf
│   │   ├── websocket-proxy.conf
│   │   └── rate-limit.conf
│   └── custom-locations/      # Specific path routing & reverse proxy rules
├── automation/
│   ├── telegram/              # Bot alert handlers & push notify scripts
│   │   ├── notify.sh
│   │   ├── server-health-alert.sh
│   │   └── ssh-login-alert.sh
│   ├── backup/                # Automated database & volume backups
│   │   ├── backup-db.sh
│   │   └── backup-prune.sh
│   └── cron/                  # Maintenance crontab definitions
│       └── crontab.sample
└── templates/
    └── .env.example
