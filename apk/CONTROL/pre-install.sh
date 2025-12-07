#!/bin/sh
# ============================================================================
# PRE-INSTALL.SH - Pre-installation tasks for Runtipi
# This script must remain POSIX/sh compatible for ADM 5.x (BusyBox/ash)
# ============================================================================
set -eu

# Source bootstrap logging (common.sh not available during first install)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/bootstrap-logging.sh" ]; then
    . "$SCRIPT_DIR/bootstrap-logging.sh"
else
    # Fallback if bootstrap-logging.sh not available
    RUNTIPI_PATH="/share/Docker/RunTipi"
    RUNTIPI_LOG_DIR="$RUNTIPI_PATH/logs"
    RUNTIPI_LOG="$RUNTIPI_LOG_DIR/package.log"
    RUNTIPI_BACKUP_DIR="$RUNTIPI_PATH/backup"
    mkdir -p "$RUNTIPI_LOG_DIR"
    _timestamp() { date '+%Y-%m-%d %H:%M:%S'; }
    log_info()    { printf '%s ℹ️  %s\n' "$(_timestamp)" "$1" >> "$RUNTIPI_LOG"; }
    log_success() { printf '%s ✅ %s\n' "$(_timestamp)" "$1" >> "$RUNTIPI_LOG"; }
    log_warn()    { printf '%s ⚠️  %s\n' "$(_timestamp)" "$1" >> "$RUNTIPI_LOG"; }
    log_error()   { printf '%s ❌ %s\n' "$(_timestamp)" "$1" >> "$RUNTIPI_LOG"; }
    log_section() {
        printf '\n' >> "$RUNTIPI_LOG"
        printf '%s ╔══════════════════════════════════════════════════════════╗\n' "$(_timestamp)" >> "$RUNTIPI_LOG"
        printf '%s ║  %s\n' "$(_timestamp)" "$1" >> "$RUNTIPI_LOG"
        printf '%s ╚══════════════════════════════════════════════════════════╝\n' "$(_timestamp)" >> "$RUNTIPI_LOG"
    }
    log_subsection() {
        printf '\n' >> "$RUNTIPI_LOG"
        printf '%s ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n' "$(_timestamp)" >> "$RUNTIPI_LOG"
        printf '%s %s\n' "$(_timestamp)" "$1" >> "$RUNTIPI_LOG"
        printf '%s ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n' "$(_timestamp)" >> "$RUNTIPI_LOG"
    }
    command_exists() { command -v "$1" >/dev/null 2>&1; }
fi

log_section "📦 PRE-INSTALL - Runtipi v${APKG_PKG_VER}"

# ============================================================================
# 🔍 DEPENDENCY CHECK
# ============================================================================
log_subsection "🔍 CHECK DEPENDENCIES"

if ! command_exists docker; then
    log_error "Docker is not installed"
    exit 1
fi
log_success "Docker found"

# Check Docker is running
if ! docker info >/dev/null 2>&1; then
    log_error "Docker is not running or accessible"
    exit 1
fi
log_success "Docker is running"

# ============================================================================
# 💾 PRE-UPGRADE BACKUP
# ============================================================================
log_subsection "💾 BACKUP CHECK"

# Check if this is an upgrade (previous version installed)
if [ -f "$APKG_PKG_DIR/VERSION" ] || [ -f "$RUNTIPI_PATH/.env" ]; then
    log_info "Upgrade detected - Creating pre-upgrade backup..."
    TS=$(date +%Y%m%d%H%M%S)
    PRE_BACKUP="$RUNTIPI_BACKUP_DIR/runtipi-pre-upgrade-$TS.tar.gz"
    mkdir -p "$RUNTIPI_BACKUP_DIR"

    # Backup critical configuration BEFORE $APKG_PKG_DIR is emptied
    if [ -d "$RUNTIPI_PATH" ]; then
        cd "$RUNTIPI_PATH" || exit 1
        if tar czf "$PRE_BACKUP" .env state traefik user-config 2>/dev/null; then
            log_success "Pre-upgrade backup: $PRE_BACKUP"
            # Secure backup file permissions
            chmod 600 "$PRE_BACKUP" 2>/dev/null || true
            # Keep only last 3 pre-upgrade backups
            find "$RUNTIPI_BACKUP_DIR" -name "runtipi-pre-upgrade-*.tar.gz" -type f 2>/dev/null | \
                sort -r | tail -n +4 | while read -r old; do rm -f "$old"; done
        else
            log_warn "Pre-upgrade backup failed (first install or no data)"
        fi
    fi
else
    log_info "Fresh install detected - no backup needed"
fi

# ============================================================================
# 🐳 DOCKER IMAGES PRE-PULL
# ============================================================================
log_subsection "🐳 PULL DOCKER IMAGES"

# Pull image with timeout and retry
# Usage: pull_image <image> <name> [timeout_seconds]
pull_image() {
    image="$1"
    name="$2"
    timeout_sec="${3:-180}"  # 3 minutes default

    log_info "Pulling $name..."

    # Check if timeout command is available
    if command_exists timeout; then
        if timeout "$timeout_sec" docker pull -q "$image" >/dev/null 2>&1; then
            log_success "  $name pulled"
            return 0
        else
            log_warn "  $name (timeout or failed, will retry at start)"
            return 1
        fi
    else
        # Fallback without timeout
        if docker pull -q "$image" >/dev/null 2>&1; then
            log_success "  $name pulled"
            return 0
        else
            log_warn "  $name (failed, will retry at start)"
            return 1
        fi
    fi
}

# Extract base version (remove .devN or .rN suffix for dev/revision builds)
# 4.6.5.dev3 -> 4.6.5, 4.6.5.r1 -> 4.6.5, 4.6.5 -> 4.6.5
RUNTIPI_VERSION=$(printf '%s' "$APKG_PKG_VER" | sed 's/\.[dr][ev]*[0-9]*$//')

# Pull core images (failures are non-fatal, they'll be pulled at start)
pull_image "traefik:v3.6.1" "Traefik" 120
pull_image "postgres:14" "PostgreSQL" 120
pull_image "rabbitmq:4-alpine" "RabbitMQ" 120
pull_image "ghcr.io/runtipi/runtipi:v${RUNTIPI_VERSION}" "Runtipi" 180

# ============================================================================
# ✅ COMPLETE
# ============================================================================
printf '\n' >> "$RUNTIPI_LOG"
log_success "🎉 Pre-install completed successfully!"
printf '\n' >> "$RUNTIPI_LOG"

exit 0
