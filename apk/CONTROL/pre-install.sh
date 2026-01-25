#!/bin/sh
# ============================================================================
# PRE-INSTALL.SH - Pre-installation tasks for Runtipi
# This script must remain POSIX/sh compatible for ADM 5.x (BusyBox/ash)
# ============================================================================
set -eu

# Initialize logging (common.sh not available yet during first install)
RUNTIPI_PATH="/share/Docker/RunTipi"
RUNTIPI_LOG_DIR="$RUNTIPI_PATH/logs"
RUNTIPI_LOG="$RUNTIPI_LOG_DIR/package.log"
BACKUP_DIR="$RUNTIPI_PATH/backup"

# Ensure log directory exists
mkdir -p "$RUNTIPI_LOG_DIR"

# Logging helpers
_timestamp() { date '+%Y-%m-%d %H:%M:%S'; }
log_info()    { echo "$(_timestamp) ℹ️  $1" >> "$RUNTIPI_LOG"; }
log_success() { echo "$(_timestamp) ✅ $1" >> "$RUNTIPI_LOG"; }
log_warn()    { echo "$(_timestamp) ⚠️  $1" >> "$RUNTIPI_LOG"; }
log_error()   { echo "$(_timestamp) ❌ $1" >> "$RUNTIPI_LOG"; }

echo "" >> "$RUNTIPI_LOG"
echo "$(_timestamp) ╔══════════════════════════════════════════════════════════════╗" >> "$RUNTIPI_LOG"
echo "$(_timestamp) ║  📦 PRE-INSTALL - Runtipi v${APKG_PKG_VER}" >> "$RUNTIPI_LOG"
echo "$(_timestamp) ╚══════════════════════════════════════════════════════════════╝" >> "$RUNTIPI_LOG"

# ============================================================================
# 🔍 DEPENDENCY CHECK
# ============================================================================
echo "" >> "$RUNTIPI_LOG"
log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_info "🔍 CHECK DEPENDENCIES"
log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if ! command -v docker >/dev/null 2>&1; then
    log_error "Docker is not installed"
    exit 1
fi
log_success "Docker found"

# ============================================================================
# 💾 PRE-UPGRADE BACKUP
# ============================================================================
echo "" >> "$RUNTIPI_LOG"
log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_info "💾 BACKUP CHECK"
log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if this is an upgrade (previous version installed)
if [ -f "$APKG_PKG_DIR/VERSION" ] || [ -f "$RUNTIPI_PATH/.env" ]; then
    log_info "Upgrade detected - Creating pre-upgrade backup..."
    TS=$(date +%Y%m%d%H%M%S)
    PRE_BACKUP="$BACKUP_DIR/runtipi-pre-upgrade-$TS.tar.gz"
    mkdir -p "$BACKUP_DIR"
    
    # Backup critical configuration BEFORE $APKG_PKG_DIR is emptied
    if [ -d "$RUNTIPI_PATH" ]; then
        cd "$RUNTIPI_PATH"
        if tar czf "$PRE_BACKUP" .env state traefik user-config 2>/dev/null; then
            log_success "Pre-upgrade backup: $PRE_BACKUP"
            # Keep only last 3 pre-upgrade backups
            find "$BACKUP_DIR" -name "runtipi-pre-upgrade-*.tar.gz" -type f 2>/dev/null | \
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
echo "" >> "$RUNTIPI_LOG"
log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_info "🐳 PULL DOCKER IMAGES"
log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

pull_image() {
    image="$1"
    name="$2"
    if docker pull -q "$image" >/dev/null 2>&1; then
        log_success "  $name pulled"
    else
        log_warn "  $name (will retry at start)"
    fi
}

pull_image "traefik:v3.6.7" "Traefik"
pull_image "postgres:14" "PostgreSQL"
pull_image "rabbitmq:4-alpine" "RabbitMQ"

# Extract base version (remove .devN or .rN suffix for dev/revision builds)
# 4.6.5.dev3 -> 4.6.5, 4.6.5.r1 -> 4.6.5, 4.6.5 -> 4.6.5
RUNTIPI_VERSION=$(echo "$APKG_PKG_VER" | sed 's/\.[dr][ev]*[0-9]*$//')
pull_image "ghcr.io/runtipi/runtipi:v${RUNTIPI_VERSION}" "Runtipi"

# ============================================================================
# ✅ COMPLETE
# ============================================================================
echo "" >> "$RUNTIPI_LOG"
log_success "🎉 Pre-install completed successfully!"
echo "" >> "$RUNTIPI_LOG"

exit 0
