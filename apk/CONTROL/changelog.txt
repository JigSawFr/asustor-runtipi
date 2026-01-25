# 📋 Changelog

> All notable changes to Runtipi for ASUSTOR are documented here.

---

## [4.7.1] - 2026-01-25

### 🚀 Runtipi v4.7.1

> 🚨 **Critical security patch** - Update strongly recommended

| Type | Description |
|------|-------------|
| 🔒 Security | Fix authenticated RCE vulnerability via backup filenames (GHSA-vrgf-rcj5-6gv9) |
| ✨ Feature | Native `docker-compose.yml` support with `x-runtipi` meta tags for custom apps |
| ✨ Feature | View docker-compose and app.env files in new "Files" tab |
| ✨ Feature | "Force Pull" option to force Docker image download |
| 🐛 Fix | Fix UDP ports regression in generated compose files |

### 📦 ASUSTOR Package

#### 🔧 Changed

| Area | Description |
|------|-------------|
| 🐳 Traefik | Update v3.6.1 → v3.6.7 (CVE-2025-66490, CVE-2025-66491, CVE-2026-22045) |
| 🔄 ENV Mapping | Fix `listenIp` → `INTERNAL_IP` (was incorrectly mapped to `SERVER_ADDR`) |
| ➕ Variable | Add `MAX_BACKUPS` support to limit backup retention |

## [4.6.5.r2] - 2026-01-25

> 📦 **Package revision** - Runtipi version unchanged (v4.6.5)

### 📦 ASUSTOR Package

#### 🐛 Fixed

| Fix | Description |
|-----|-------------|
| 🔄 Sync Workflow | Fixed authentication and push issues in sync-upstream workflow |
| 🛠️ Build Path | Fixed artifact path issue in sync-upstream workflow |
| 🏪 Custom Store | Fixed custom store hook execution in start-stop script |

## [4.6.5.r1] - 2025-12-10

> 📦 **Package revision** - Runtipi version unchanged (v4.6.5)

### 📦 ASUSTOR Package

#### ✨ Added

| Feature | Description |
|---------|-------------|
| 🖥️ Compatible Models | Added compatibility table for ASUSTOR NAS models in README |
| 📝 tipi-compose.yml | Auto-created during install for correct Traefik volume mounts |
| 🔄 Sync tipi-compose.yml | User config file now synced between AppCentral and RunTipi paths |

#### 🔧 Changed

| Area | Description |
|------|-------------|
| 🐳 Docker | Minimum version lowered to **28.0.0** (was 28.1.1) |
| 🔨 Build System | Changelog now manually maintained (no longer auto-generated) |

#### 🐛 Fixed

| Issue | Description |
|-------|-------------|
| 🔧 Traefik Volumes | Fixed Traefik config path mounting via tipi-compose.yml |

#### ⚠️ Known Issues

| Issue | Workaround |
|-------|------------|
| `memory-advice` | Temporarily removed from config.json due to ASUSTOR App Central bug (#91706) |

---

## [4.6.5] - 2025-11-28

### 🚀 Runtipi v4.6.5

- Update traefik to v3.6.1. This fixes an upstream issue that was preventing the use of latest Docker v29
- `./runtipi-cli update v4.6.5`

### 📦 ASUSTOR Package

#### 🎉 Initial Public Release

This is the **first public release** on GitHub!

#### ✨ Added

| Feature | Description |
|---------|-------------|
| 💾 Auto Backup | Automatic pre-upgrade backup before package updates |
| 🌐 Cloudflare DNS | Setup script (`scripts/cloudflare-setup.sh`) |
| 📦 Enhanced Backup | `--full`, `--destination`, `--max-backups` options |
| 🔄 Enhanced Restore | `--list`, `--dry-run`, `--file` options |
| 🏗️ ARM64 Support | For AS33xx, AS11xx, AS67xx series |
| ⚙️ Environment Variables | `RUNTIPI_BACKUP_PATH` and `RUNTIPI_MAX_BACKUPS` |
| 🔗 CLI Symlink | Symbolic link for runtipi-cli in `/usr/local/bin` |
| 🤖 GitHub Actions | CI/CD workflows for automation |
| 🔨 Build System | Cross-platform APK builder (build.py v1.5.0) |
| 🧪 Dev Builds | Dev build mode with auto-increment counter |

#### 🔧 Improved

| Area | Description |
|------|-------------|
| 📊 Logging | Separate log files - `package.log` for package, `cli.log` for CLI |
| 🎨 Emoji Logging | Unified emoji logging across all scripts |
| 📋 CLI Output | Parsed for clean logging |
| 📝 Changelog | Auto-generated from GitHub releases + package notes |
| 🐚 POSIX | POSIX/sh compatibility for all scripts (ADM 5.x BusyBox) |
| 🔍 Port Detection | Port conflict detection before service start |
| 🔐 Security | Sensitive variables masking in logs |
| 📚 Documentation | Comprehensive README with upgrade guide and Cloudflare setup |

#### 🐛 Fixed

| Issue | Description |
|-------|-------------|
| 📄 Line Endings | CRLF line endings in shell scripts (build validation) |
| 🖼️ Icon Size | Icon size validation (90x90 per ASUSTOR spec) |
| 📁 Paths | CONTROL_DIR paths in start-stop.sh |

---

## 📚 More Information

- [Runtipi Releases](https://github.com/runtipi/runtipi/releases)
- [ASUSTOR Package Releases](https://github.com/JigSawFr/asustor-runtipi/releases)
