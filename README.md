# Runtipi for ASUSTOR

<p align="center">
  <img src="logo/icon-256x256.png" alt="Runtipi for ASUSTOR" width="128" height="128">
</p>

<p align="center">
  <strong>🏠 Homeserver management made easy on your ASUSTOR NAS</strong>
</p>

<p align="center">
  <a href="https://github.com/JigSawFr/asustor-runtipi/actions/workflows/ci.yml"><img alt="CI" src="https://img.shields.io/github/actions/workflow/status/JigSawFr/asustor-runtipi/ci.yml?label=CI&logo=githubactions&style=for-the-badge&color=4B8DF8"></a>
  <a href="https://github.com/JigSawFr/asustor-runtipi/actions/workflows/release.yml"><img alt="Release" src="https://img.shields.io/github/actions/workflow/status/JigSawFr/asustor-runtipi/release.yml?label=Release&logo=githubactions&style=for-the-badge&color=28A745"></a>
  <a href="https://github.com/JigSawFr/asustor-runtipi/releases"><img alt="Version" src="https://img.shields.io/github/v/release/JigSawFr/asustor-runtipi?include_prereleases&style=for-the-badge&color=blue"></a>
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge"></a>
</p>

<p align="center">
  <a href="https://github.com/JigSawFr/asustor-runtipi/stargazers"><img alt="Stars" src="https://img.shields.io/github/stars/JigSawFr/asustor-runtipi?style=for-the-badge&logo=star&color=FFD700"></a>
  <a href="https://github.com/JigSawFr/asustor-runtipi/pulls"><img alt="Pull Requests" src="https://img.shields.io/github/issues-pr/JigSawFr/asustor-runtipi?style=for-the-badge&logo=gitbook&color=purple"></a>
  <a href="https://github.com/JigSawFr/asustor-runtipi/issues"><img alt="Issues" src="https://img.shields.io/github/issues/JigSawFr/asustor-runtipi?color=7842f5&style=for-the-badge"></a>
  <a href="https://discord.gg/xPtEFWEcjT"><img alt="Discord" src="https://img.shields.io/badge/Discord-ASUSTOR-5865F2?style=for-the-badge&logo=discord&logoColor=white"></a>
  <a href="https://ko-fi.com/jigsawfr"><img alt="Ko-fi" src="https://img.shields.io/badge/Ko--fi-Support-FF5E5B?style=for-the-badge&logo=ko-fi&logoColor=white"></a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/ADM-5.x-0078D4?style=for-the-badge" alt="ADM 5.x">
  <img src="https://img.shields.io/badge/arch-x86--64-green?style=for-the-badge" alt="x86-64">
  <img src="https://img.shields.io/badge/arch-ARM64-green?style=for-the-badge" alt="ARM64">
</p>

---

## 📚 Table of Contents

- 🤔 [What is Runtipi?](#-what-is-runtipi)
- 🏪 [Custom App Stores](#-custom-app-stores)
- ⚠️ [Prerequisites](#️-prerequisites)
- ⚡ [Quick Start](#-quick-start)
- ✨ [Features](#-features)
- ⚙️ [Configuration](#️-configuration)
- 💾 [Backup & Restore](#-backup--restore)
- 🔐 [Cloudflare SSL Setup](#-cloudflare-ssl-setup)
- 🔄 [Upgrade Guide](#-upgrade-guide)
- 🔧 [Troubleshooting](#-troubleshooting)
- 🛠️ [Developer Guide](#️-developer-guide)
- 🙏 [Acknowledgements](#-acknowledgements)

---

## 🤔 What is Runtipi?

[**Runtipi**](https://runtipi.io/) is an open-source homeserver management platform that makes self-hosting easy and accessible to everyone.

<p align="center">
  <img src="https://runtipi.io/_next/static/media/appstore-dark.28579c10.png" alt="Runtipi Dashboard" width="600">
</p>

**With Runtipi, you can:**
- 🚀 **Install 200+ apps** with one click (Plex, Nextcloud, Home Assistant, etc.)
- 🔒 **Automatic HTTPS** with built-in Traefik reverse proxy
- 🌐 **Custom domains** for each app (e.g., `plex.yourdomain.com`)
- 💾 **Easy backups** and app management
- 🎨 **Beautiful web UI** - no command line needed!

> [!TIP]
> This package brings Runtipi to your **ASUSTOR NAS**, fully integrated with ADM!

---

## 🏪 Custom App Stores

One of Runtipi's best features is the ability to **add third-party app stores** alongside the official one! This means you can access hundreds of additional apps curated by the community.

Simply go to **Settings** → **App Repositories** → **Add** and paste any compatible store URL.

### 🎯 JigSaw's Tipi Store

<p align="center">
  <a href="https://github.com/JigSawFr/tipi-store">
    <img src="https://img.shields.io/badge/🏪_JigSaw's_Tipi_Store-Explore_Apps-FF6B6B?style=for-the-badge" alt="JigSaw's Tipi Store">
  </a>
</p>

<p align="center">
  <a href="https://github.com/JigSawFr/tipi-store"><img alt="Tipi Store Stars" src="https://img.shields.io/github/stars/JigSawFr/tipi-store?style=for-the-badge&logo=star&color=FFD700"></a>
  <a href="https://github.com/JigSawFr/tipi-store/tree/main/apps"><img alt="Apps Count" src="https://img.shields.io/badge/Apps-29+-28A745?style=for-the-badge&logo=docker"></a>
</p>

**[JigSaw's Tipi Store](https://github.com/JigSawFr/tipi-store)** is a community-driven app repository featuring:

- 🎬 **Media apps** - Plex, Sonarr, Radarr, Prowlarr, Tautulli, Overseerr
- 🔥 **Debrid tools** - RDT-Client, Decypharr, Byparr
- ⚙️ **Automation** - Recyclarr, Configarr, Profilarr, Huntarr, autobrr
- 📊 **Monitoring** - Beszel, Beszel Agent
- 🔐 **Auth & Security** - Pocket ID, TinyAuth
- 📄 **Utilities** - Paperless-ngx, Paperless-AI, HomeBox, LubeLogger

#### Add JigSaw's Store

```
https://github.com/JigSawFr/tipi-store
```

> [!NOTE]
> Works perfectly on your ASUSTOR NAS with this package! 🎉

---

## ⚠️ Prerequisites

| Requirement | Minimum Version |
|-------------|-----------------|
| ASUSTOR ADM | 5.1.0+ |
| Docker CE | 28.1.1+ |
| jq | 1.7.1+ |
| Git | 2.45.2+ |
| RAM | 4GB (8GB recommended) |

> [!NOTE]
> Install Docker CE, jq, and Git via **App Central** before installing Runtipi.

---

## ⚡ Quick Start

1. **Download** the `.apk` for your architecture from [Releases](https://github.com/JigSawFr/asustor-runtipi/releases):
   - `io.runtipi_x.x.x_x86-64.apk` for Intel/AMD NAS
   - `io.runtipi_x.x.x_arm64.apk` for ARM64 NAS (AS33xx, AS11xx, etc.)

2. **Install** via App Central → Manual Install → Select the `.apk` file

3. **Access** Runtipi at `https://<NAS_IP>:4443`

| Setting | Default |
|---------|---------|
| 📁 Data directory | `/share/Docker/RunTipi` |
| 🌐 HTTP port | 8880 |
| 🔒 HTTPS port | 4443 |

---

## ✨ Features

- 🚀 **One-click app installation** via beautiful web UI
- 🔒 **Automatic HTTPS** with Traefik reverse proxy
- 💾 **Pre-upgrade backups** created automatically
- 🔄 **Easy upgrades** preserving all your data
- 📊 **Unified logging** with emoji indicators
- 🌐 **Cloudflare DNS** challenge support for wildcard SSL
- 🏗️ **ARM64 support** for AS33xx, AS11xx, AS67xx series

---

## ⚙️ Configuration

Edit `/share/Docker/RunTipi/.env` to customize:

| Variable | Default | Description |
|----------|---------|-------------|
| `NGINX_PORT` | 8880 | HTTP port |
| `NGINX_PORT_SSL` | 4443 | HTTPS port |
| `DOMAIN` | NAS hostname | Your domain for SSL |
| `LOCAL_DOMAIN` | tipi.local | Local domain suffix |
| `GUEST_DASHBOARD` | true | Allow guest access |
| `PERSIST_TRAEFIK_CONFIG` | false | Keep custom Traefik config |
| `RUNTIPI_BACKUP_PATH` | auto | Custom backup location |
| `RUNTIPI_MAX_BACKUPS` | 5 | Max backups to keep |

### Custom Ports

```bash
# Edit .env and restart
NGINX_PORT=8080
NGINX_PORT_SSL=8443
```

---

## 💾 Backup & Restore

### Automatic Pre-Upgrade Backup

Runtipi automatically creates a backup before each upgrade:
`/share/Docker/RunTipi/backup/runtipi-pre-upgrade-*.tar.gz`

### Manual Backup

```bash
# Basic backup (config + state)
/volume1/.@plugins/AppCentral/io.runtipi/scripts/backup.sh

# Full backup (includes app-data)
/volume1/.@plugins/AppCentral/io.runtipi/scripts/backup.sh --full

# Custom destination & retention
/volume1/.@plugins/AppCentral/io.runtipi/scripts/backup.sh -d /share/Backup -m 10
```

### Restore

```bash
# List available backups
/volume1/.@plugins/AppCentral/io.runtipi/scripts/restore.sh --list

# Restore latest
/volume1/.@plugins/AppCentral/io.runtipi/scripts/restore.sh

# Restore specific backup (with dry-run preview)
/volume1/.@plugins/AppCentral/io.runtipi/scripts/restore.sh --dry-run -f /path/to/backup.tar.gz
```

---

## 🔐 Cloudflare SSL Setup

Get wildcard SSL certificates without exposing ports 80/443:

1. **Create Cloudflare API Token** at https://dash.cloudflare.com/profile/api-tokens
   - Permission: `Zone:DNS:Edit`

2. **Run the helper script**:
```bash
/volume1/.@plugins/AppCentral/io.runtipi/scripts/cloudflare-setup.sh \
  -e your@email.com \
  -t cf_your_api_token_here \
  -d yourdomain.com
```

3. **Restart** and access apps via `https://app.yourdomain.com`

---

## 🔄 Upgrade Guide

### What's Preserved

| ✅ Preserved | 🔄 Reset |
|-------------|----------|
| All apps and data (`app-data/`) | CLI binary (updated) |
| Configuration (`.env`, `user-config/`) | Package files |
| Traefik config (`traefik/`) | Forced env vars |
| Application state (`state/`) | |

### Rollback

```bash
# List backups
/volume1/.@plugins/AppCentral/io.runtipi/scripts/restore.sh --list

# Restore pre-upgrade backup
/volume1/.@plugins/AppCentral/io.runtipi/scripts/restore.sh -f /share/Docker/RunTipi/backup/runtipi-pre-upgrade-*.tar.gz
```

---

## 🔧 Troubleshooting

### Log Locations

| Log | Path |
|-----|------|
| 📦 Package logs | `/share/Docker/RunTipi/logs/package.log` |
| 🖥️ CLI logs | `/share/Docker/RunTipi/logs/cli.log` |
| 🌐 Traefik logs | `/share/Docker/RunTipi/traefik/logs/traefik.log` |

### Health Check

```bash
/volume1/.@plugins/AppCentral/io.runtipi/scripts/status.sh
```

### Common Issues

| Error | Solution |
|-------|----------|
| `Port already in use` | Change ports in `.env` |
| `Docker missing` | Install Docker CE via App Central |
| `CLI not found` | Reinstall package or `chmod +x` the CLI |

### 💬 Need Help?

[![Discord](https://img.shields.io/badge/Discord-ASUSTOR%20Channel-5865F2?style=for-the-badge&logo=discord&logoColor=white)](https://discord.gg/xPtEFWEcjT)

Ask questions on the dedicated **#asustor** channel in the Runtipi Discord!

---

## 🛠️ Developer Guide

See [DEVELOPER.md](DEVELOPER.md) for:
- 🔨 Build system (`python build/build.py`)
- 🏷️ Version management
- 📝 Changelog generation
- 🧪 Testing procedures

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines.

---

## 🙏 Acknowledgements

- [Runtipi](https://runtipi.io/) - The amazing homeserver platform
- [ASUSTOR](https://www.asustor.com/) - NAS hardware and ADM
- ❤️ My friends from the [Runtipi dev team & contributors](https://github.com/runtipi/runtipi/graphs/contributors) - For their awesome work and support!
- All contributors and testers!

---

## 🏗️ Built With

<p align="left">
  <a href="https://runtipi.io/"><img src="https://img.shields.io/badge/%E2%9B%BA%20Runtipi-2C2C32?style=for-the-badge" alt="Runtipi" height="28"/></a>
  <a href="https://www.docker.com/"><img src="https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white" alt="Docker" height="28"/></a>
  <a href="https://github.com/features/actions"><img src="https://img.shields.io/badge/GitHub%20Actions-2088FF?style=for-the-badge&logo=githubactions&logoColor=white" alt="GitHub Actions" height="28"/></a>
  <a href="https://www.python.org/"><img src="https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white" alt="Python" height="28"/></a>
  <a href="https://www.shellscript.sh/"><img src="https://img.shields.io/badge/Shell-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white" alt="Shell" height="28"/></a>
</p>

---

<p align="center">
  <a href="https://github.com/JigSawFr/asustor-runtipi/releases">📦 Releases</a> •
  <a href="https://github.com/JigSawFr/asustor-runtipi/issues">🐛 Issues</a> •
  <a href="CHANGELOG.md">📋 Changelog</a> •
  <a href="https://discord.gg/xPtEFWEcjT">💬 Discord</a> •
  <a href="https://ko-fi.com/jigsawfr">☕ Support</a> •
  <a href="https://runtipi.io/docs">📚 Runtipi Docs</a>
</p>
