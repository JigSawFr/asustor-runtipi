#!/bin/sh
# ============================================================================
# BOOTSTRAP-LOGGING.SH - Minimal logging for pre/post install scripts
# This script provides logging before common.sh is available
# Must remain POSIX/sh compatible for ADM 5.x (BusyBox/ash)
# ============================================================================

# Configuration
RUNTIPI_PATH="/share/Docker/RunTipi"
RUNTIPI_LOG_DIR="$RUNTIPI_PATH/logs"
RUNTIPI_LOG="$RUNTIPI_LOG_DIR/package.log"
RUNTIPI_BACKUP_DIR="$RUNTIPI_PATH/backup"

# Ensure log directory exists
mkdir -p "$RUNTIPI_LOG_DIR" 2>/dev/null || true

# Timestamp function
_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Logging functions
log_info() {
    printf '%s ℹ️  %s\n' "$(_timestamp)" "$1" >> "$RUNTIPI_LOG"
}

log_success() {
    printf '%s ✅ %s\n' "$(_timestamp)" "$1" >> "$RUNTIPI_LOG"
}

log_warn() {
    printf '%s ⚠️  %s\n' "$(_timestamp)" "$1" >> "$RUNTIPI_LOG"
}

log_error() {
    printf '%s ❌ %s\n' "$(_timestamp)" "$1" >> "$RUNTIPI_LOG"
}

log_section() {
    {
        printf '\n'
        printf '%s ╔══════════════════════════════════════════════════════════╗\n' "$(_timestamp)"
        printf '%s ║  %s\n' "$(_timestamp)" "$1"
        printf '%s ╚══════════════════════════════════════════════════════════╝\n' "$(_timestamp)"
    } >> "$RUNTIPI_LOG"
}

log_subsection() {
    {
        printf '\n'
        printf '%s ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n' "$(_timestamp)"
        printf '%s %s\n' "$(_timestamp)" "$1"
        printf '%s ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n' "$(_timestamp)"
    } >> "$RUNTIPI_LOG"
}

# Architecture detection
get_architecture() {
    arch=$(uname -m)
    case "$arch" in
        x86_64|amd64) printf 'x86-64' ;;
        aarch64|arm64) printf 'arm64' ;;
        armv7*|armhf) printf 'armv7' ;;
        i686|i386) printf 'i386' ;;
        *) printf '%s' "$arch" ;;
    esac
}

is_supported_architecture() {
    arch=$(get_architecture)
    case "$arch" in
        x86-64|arm64) return 0 ;;
        *) return 1 ;;
    esac
}

get_cli_asset_name() {
    arch=$(get_architecture)
    case "$arch" in
        x86-64) printf 'runtipi-cli-linux-x86_64' ;;
        arm64) printf 'runtipi-cli-linux-aarch64' ;;
        *) printf '' ;;
    esac
}

# Command existence check
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Validate port number
validate_port() {
    port="$1"
    case "$port" in
        ''|*[!0-9]*) return 1 ;;
        *)
            [ "$port" -ge 1 ] && [ "$port" -le 65535 ]
            ;;
    esac
}

# Validate environment value (prevent injection)
validate_env_value() {
    value="$1"
    # Reject values with shell metacharacters
    case "$value" in
        *'$('*|*'`'*|*';'*|*'|'*|*'>'*|*'<'*|*'&'*)
            return 1
            ;;
    esac
    return 0
}
