#!/bin/sh
# ============================================================================
# POST-INSTALL.SH - Post-installation tasks for Runtipi
# This script must remain POSIX/sh compatible for ADM 5.x (BusyBox/ash)
# ============================================================================
set -eu

# Source common functions (now available after package extraction)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/common.sh" ]; then
    . "$SCRIPT_DIR/common.sh"
elif [ -f "$SCRIPT_DIR/bootstrap-logging.sh" ]; then
    . "$SCRIPT_DIR/bootstrap-logging.sh"
    secure_permissions() { chmod 600 "$APKG_PKG_DIR/.env" 2>/dev/null || true; }
else
    # Fallback if no scripts available
    RUNTIPI_PATH="/share/Docker/RunTipi"
    RUNTIPI_LOG="$RUNTIPI_PATH/logs/package.log"
    mkdir -p "$RUNTIPI_PATH/logs"
    _timestamp() { date '+%Y-%m-%d %H:%M:%S'; }
    log_info() { printf '%s ℹ️  %s\n' "$(_timestamp)" "$1" >> "$RUNTIPI_LOG"; }
    log_success() { printf '%s ✅ %s\n' "$(_timestamp)" "$1" >> "$RUNTIPI_LOG"; }
    log_warn() { printf '%s ⚠️  %s\n' "$(_timestamp)" "$1" >> "$RUNTIPI_LOG"; }
    log_error() { printf '%s ❌ %s\n' "$(_timestamp)" "$1" >> "$RUNTIPI_LOG"; }
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
    get_architecture() { uname -m | sed 's/x86_64/x86-64/;s/aarch64/arm64/'; }
    is_supported_architecture() { arch=$(get_architecture); [ "$arch" = "x86-64" ] || [ "$arch" = "arm64" ]; }
    get_cli_asset_name() { arch=$(get_architecture); [ "$arch" = "arm64" ] && printf 'runtipi-cli-linux-aarch64' || printf 'runtipi-cli-linux-x86_64'; }
    secure_permissions() { chmod 600 "$APKG_PKG_DIR/.env" 2>/dev/null || true; }
    command_exists() { command -v "$1" >/dev/null 2>&1; }
    validate_env_value() {
        case "$1" in *'$('*|*'`'*|*';'*|*'|'*|*'>'*|*'<'*|*'&'*) return 1 ;; esac
        return 0
    }
fi

log_section "⚙️  POST-INSTALL v${APKG_PKG_VER}"

# ============================================================================
# 📋 LOG ADM VERSION
# ============================================================================
if [ -f /etc/VERSION ]; then
    log_info "ADM version: $(cat /etc/VERSION)"
fi

# ============================================================================
# 🔍 DEPENDENCY CHECK
# ============================================================================
log_subsection "🔍 CHECK DEPENDENCIES"

log_info "Checking dependencies..."
for cmd in openssl curl; do
    if ! command_exists "$cmd"; then
        log_error "$cmd is missing"
        exit 1
    fi
done
log_success "Dependencies OK"

# ============================================================================
# 🖥️ ARCHITECTURE CHECK
# ============================================================================
log_info "Checking architecture..."
if ! is_supported_architecture; then
    log_error "Runtipi is not supported on $(get_architecture) architecture"
    exit 1
fi
log_success "Architecture: $(get_architecture)"

# ============================================================================
# 🔐 GENERATE SECRETS
# ============================================================================
log_subsection "🔐 GENERATE SECRETS"

log_info "Generating secrets..."
POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d '\n')
JWT_SECRET=$(openssl rand -base64 32 | tr -d '\n')
RABBITMQ_PASSWORD=$(openssl rand -base64 32 | tr -d '\n')
log_success "Secrets generated"

# ============================================================================
# ⬇️ DOWNLOAD CLI
# ============================================================================
log_subsection "⬇️ DOWNLOAD RUNTIPI CLI"

ASSET=$(get_cli_asset_name)
if [ -z "$ASSET" ]; then
    log_error "No CLI available for architecture: $(get_architecture)"
    exit 1
fi
log_info "CLI asset: $ASSET"

# Create bin directory
mkdir -p "$APKG_PKG_DIR/bin"

# Extract base version (remove .devN or .rN suffix for dev/revision builds)
# 4.6.5.dev3 -> 4.6.5, 4.6.5.r1 -> 4.6.5, 4.6.5 -> 4.6.5
CLI_VERSION=$(printf '%s' "$APKG_PKG_VER" | sed 's/\.[dr][ev]*[0-9]*$//')

# Download CLI with retry
URL="https://github.com/runtipi/runtipi/releases/download/v$CLI_VERSION/$ASSET.tar.gz"
log_info "📥 Downloading from GitHub..."
log_info "   URL: $URL"

download_cli() {
    max_retries=3
    retry=0
    while [ $retry -lt $max_retries ]; do
        if curl -fsSL --connect-timeout 30 --max-time 120 "$URL" -o "$APKG_PKG_DIR/runtipi-cli.tar.gz"; then
            return 0
        fi
        retry=$((retry + 1))
        log_warn "Download attempt $retry failed, retrying..."
        sleep 2
    done
    return 1
}

if ! download_cli; then
    log_error "Failed to download CLI after 3 attempts"
    exit 1
fi

# Verify download (basic check)
if [ ! -s "$APKG_PKG_DIR/runtipi-cli.tar.gz" ]; then
    log_error "Downloaded file is empty"
    exit 1
fi

# Extract CLI
log_info "📦 Extracting CLI..."
if ! tar -xzf "$APKG_PKG_DIR/runtipi-cli.tar.gz" -C "$APKG_PKG_DIR/"; then
    log_error "Failed to extract CLI"
    exit 1
fi

mv "$APKG_PKG_DIR/$ASSET" "$APKG_PKG_DIR/runtipi-cli"
rm -f "$APKG_PKG_DIR/runtipi-cli.tar.gz"
chmod 755 "$APKG_PKG_DIR/runtipi-cli"
log_success "🎯 CLI v${CLI_VERSION} installed"

# ============================================================================
# 📂 CREATE RUNTIPI DIRECTORY
# ============================================================================
log_subsection "📂 CREATE DIRECTORIES"

if [ ! -d "$RUNTIPI_PATH" ]; then
    log_info "Creating RunTipi directory..."
    mkdir -p "$RUNTIPI_PATH"
    log_success "RunTipi directory created: $RUNTIPI_PATH"
else
    log_info "✓ RunTipi directory exists"
fi

# Create state directory with proper permissions for SQLite databases
if [ ! -d "$RUNTIPI_PATH/state" ]; then
    log_info "Creating state directory..."
    mkdir -p "$RUNTIPI_PATH/state"
    chmod 755 "$RUNTIPI_PATH/state"
    log_success "State directory created"
else
    log_info "✓ State directory exists"
fi

# ============================================================================
# 📝 ENVIRONMENT FILE MANAGEMENT
# ============================================================================
log_subsection "📝 CONFIGURE ENVIRONMENT"

ENV_FILE="$RUNTIPI_PATH/.env"

# Create .env if it doesn't exist
[ ! -f "$ENV_FILE" ] && touch "$ENV_FILE"

# Variables to always replace on install/upgrade
FORCE_VARS="TZ TIPI_VERSION DEMO_MODE INTERNAL_IP NODE_ENV"

# Helper to get existing value or use default
get_or_default() {
    var_name="$1"
    default_val="$2"
    existing=$(grep -E "^${var_name}=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2- || printf '')

    # Force replace certain variables
    case " $FORCE_VARS " in
        *" $var_name "*) printf '%s' "$default_val" ;;
        *)
            if [ -n "$existing" ]; then
                printf '%s' "$existing"
            else
                printf '%s' "$default_val"
            fi
            ;;
    esac
}

# Set variable in .env with validation
set_env_var() {
    var_name="$1"
    value="$2"

    # Validate value to prevent injection
    if ! validate_env_value "$value"; then
        log_warn "Invalid value for $var_name, using safe default"
        return 1
    fi

    if grep -q "^${var_name}=" "$ENV_FILE" 2>/dev/null; then
        sed -i "s|^${var_name}=.*|${var_name}=${value}|" "$ENV_FILE"
    else
        printf '%s=%s\n' "$var_name" "$value" >> "$ENV_FILE"
    fi
}

log_info "Configuring environment..."

# Core settings
set_env_var "ADVANCED_SETTINGS" "$(get_or_default ADVANCED_SETTINGS false)"
set_env_var "ALLOW_AUTO_THEMES" "$(get_or_default ALLOW_AUTO_THEMES true)"
set_env_var "ALLOW_ERROR_MONITORING" "$(get_or_default ALLOW_ERROR_MONITORING false)"
set_env_var "APPS_REPO_ID" "$(get_or_default APPS_REPO_ID 29ca930bfdaffa1dfabf5726336380ede7066bc53297e3c0c868b27c97282903)"
set_env_var "APPS_REPO_URL" "$(get_or_default APPS_REPO_URL https://github.com/runtipi/runtipi-appstore)"
set_env_var "DEMO_MODE" "false"
set_env_var "DNS_IP" "$(get_or_default DNS_IP 9.9.9.9)"
set_env_var "DOMAIN" "$(get_or_default DOMAIN "${SERVER_NAME:-localhost}")"
set_env_var "EXPERIMENTAL_INSECURE_COOKIE" "$(get_or_default EXPERIMENTAL_INSECURE_COOKIE false)"
set_env_var "GUEST_DASHBOARD" "$(get_or_default GUEST_DASHBOARD true)"
set_env_var "INTERNAL_IP" "${SERVER_ADDR:-127.0.0.1}"
set_env_var "LOCAL_DOMAIN" "$(get_or_default LOCAL_DOMAIN tipi.local)"
set_env_var "LOG_LEVEL" "$(get_or_default LOG_LEVEL info)"
set_env_var "NGINX_PORT" "$(get_or_default NGINX_PORT 8880)"
set_env_var "NGINX_PORT_SSL" "$(get_or_default NGINX_PORT_SSL 4443)"
set_env_var "NODE_ENV" "production"
set_env_var "PERSIST_TRAEFIK_CONFIG" "$(get_or_default PERSIST_TRAEFIK_CONFIG false)"
set_env_var "QUEUE_TIMEOUT_IN_MINUTES" "$(get_or_default QUEUE_TIMEOUT_IN_MINUTES 10)"
set_env_var "THEME_BASE" "$(get_or_default THEME_BASE gray)"
set_env_var "THEME_COLOR" "$(get_or_default THEME_COLOR blue)"
set_env_var "TIPI_VERSION" "v${CLI_VERSION}"
set_env_var "TZ" "${AS_NAS_TIMEZONE:-UTC}"

# Database settings (preserve passwords if they exist)
existing_pg_pass=$(grep -E "^POSTGRES_PASSWORD=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2- || printf '')
existing_jwt=$(grep -E "^JWT_SECRET=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2- || printf '')
existing_rmq_pass=$(grep -E "^RABBITMQ_PASSWORD=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2- || printf '')

set_env_var "POSTGRES_DBNAME" "tipi"
set_env_var "POSTGRES_HOST" "runtipi-db"
set_env_var "POSTGRES_PASSWORD" "${existing_pg_pass:-$POSTGRES_PASSWORD}"
set_env_var "POSTGRES_PORT" "5432"
set_env_var "POSTGRES_USERNAME" "tipi"
set_env_var "JWT_SECRET" "${existing_jwt:-$JWT_SECRET}"
set_env_var "RABBITMQ_HOST" "runtipi-queue"
set_env_var "RABBITMQ_PASSWORD" "${existing_rmq_pass:-$RABBITMQ_PASSWORD}"
set_env_var "RABBITMQ_USERNAME" "tipi"

# Path settings
set_env_var "ROOT_FOLDER_HOST" "$RUNTIPI_PATH"
set_env_var "RUNTIPI_APP_DATA_PATH" "$RUNTIPI_PATH"
set_env_var "RUNTIPI_APPS_PATH" "$RUNTIPI_PATH"
set_env_var "RUNTIPI_FORWARD_AUTH_URL" "http://runtipi:3000/api/auth/traefik"
set_env_var "RUNTIPI_LOGS_PATH" "$RUNTIPI_PATH"
set_env_var "RUNTIPI_MEDIA_PATH" "/share/Media"
set_env_var "RUNTIPI_REPOS_PATH" "$RUNTIPI_PATH"
set_env_var "RUNTIPI_STATE_PATH" "$RUNTIPI_PATH"
set_env_var "RUNTIPI_TRAEFIK_PATH" "$RUNTIPI_PATH"
set_env_var "RUNTIPI_USER_CONFIG_PATH" "$RUNTIPI_PATH"

log_success "📄 .env configured"

# ============================================================================
# 💾 SAVE VERSION
# ============================================================================
log_subsection "💾 FINALIZE INSTALLATION"

printf '%s' "$APKG_PKG_VER" > "$APKG_PKG_DIR/VERSION"
log_info "Version saved: $APKG_PKG_VER"

# ============================================================================
# ✅ COMPLETE
# ============================================================================
log_info "🔒 Securing permissions..."
secure_permissions

printf '\n' >> "$RUNTIPI_LOG"
log_success "🎉 Post-install completed successfully!"
log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_info "📍 Data location: $RUNTIPI_PATH"
log_info "🌐 Access Runtipi at http://NAS_IP:8880 after starting"
printf '\n' >> "$RUNTIPI_LOG"

exit 0
