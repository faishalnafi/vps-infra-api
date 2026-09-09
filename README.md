# vps-infra-api

Infrastructure as Code (IaC), Docker Compose orchestration, advanced Nginx Proxy Manager (NPM) routing/security snippets, server automation scripts, and Telegram notification bots for Linux VPS environments.

**Canonical domain**: `faishalnafi.com` (examples/templates use subdomains like `api.faishalnafi.com`, `npm.faishalnafi.com`, `status.faishalnafi.com`, `auth.faishalnafi.com`, `app.faishalnafi.com`).

## Repository layout

```text
vps-infra-api/
├── claude.md                  # Agent instructions & sanitization rules
├── nginx-proxy-manager/
│   ├── advanced-snippets/     # Modular Nginx configs to include in NPM
│   └── custom-locations/      # Path-based routing & reverse proxy rules
│       ├── object-storage-proxy-private.conf  # Referer-locked proxy to object storage
│       └── object-storage-proxy-public.conf   # Open/direct-access proxy to object storage
├── automation/
│   └── telegram/
│       └── vps-monitor/       # Notifikasi Telegram: startup, shutdown, heartbeat berkala
├── docker-compose/            # (planned) NPM, Portainer, Watchtower, monitoring stacks
└── templates/                 # (planned) .env examples
```

## NPM object storage proxy

The two `.conf` files under `nginx-proxy-manager/custom-locations/` route path-based upstreams (`/orca/`, `/marlin/`, `/kraken/`, `/leviathan/`) to Cloudflare R2, Google Cloud Storage, AWS S3, and IDCloudHost S3, so object storage can be exposed through a single NPM host.

- **`object-storage-proxy-private.conf`** — restricts access with `valid_referers`; requests from disallowed domains get a `403`. Use this when the storage should only be embeddable/loadable from your own sites.
- **`object-storage-proxy-public.conf`** — no referer check; any client can hit the paths directly. Use this for public assets (e.g. CDN-style delivery) where open access is intended.

Each provider block supports two upstream options (custom domain vs. the provider's default endpoint) — toggle between them by commenting/uncommenting the relevant lines. See the inline guides in each file for renaming a path (e.g. `/orca/` → `/kelp/`) and for adding a new provider from the dummy template block.

## Telegram VPS monitor

[`automation/telegram/vps-monitor/`](automation/telegram/vps-monitor/) sends VPS status notifications to Telegram: on boot, on shutdown/reboot, and on a recurring heartbeat (default every 1 hour). Each notification includes a detailed status report (uptime, load, CPU, RAM, disk, IPs, Docker containers, top processes). See its own [README](automation/telegram/vps-monitor/README.md) for full setup instructions (systemd or cron).

## Security & sanitization

This repository is public. Before committing real server configs, secrets, domains, or credentials, they must be sanitized per the rules in [`claude.md`](claude.md) — placeholder values for API keys/passwords, `${TELEGRAM_BOT_TOKEN}`/`${TELEGRAM_CHAT_ID}` for bot credentials, `faishalnafi.com` subdomains in place of real domains, documentation IPs (`203.0.113.1`) or private ranges (`192.168.1.100`, `172.20.0.0/16`) in place of real IPs, and placeholder blocks in place of real certificates/keys.

## License

[MIT](LICENSE)
