#!/bin/sh
# ============================================================================
# COMMON FUNCTIONS - Shared library for Runtipi ADM package scripts
# This script must remain POSIX/sh compatible for ADM 5.x (BusyBox/ash)
# ============================================================================
# Usage: . "$APKG_PKG_DIR/CONTROL/common.sh" (or source during install)
# ============================================================================

# ============================================================================
# CONFIGURATION
# ============================================================================
RUNTIPI_PATH="/share/Docker/RunTipi"
RUNTIPI_LOG_DIR="$RUNTIPI_PATH/logs"
RUNTIPI_BACKUP_DIR="$RUNTIPI_PATH/backup"
RUNTIPI_LOG="$RUNTIPI_LOG_DIR/package.log"
CLI_LOG="$RUNTIPI_LOG_DIR/cli.log"

# ============================================================================
# INITIALIZATION
# ============================================================================
# Create log directory if it doesn't exist
init_logging() {
    if [ ! -d "$RUNTIPI_LOG_DIR" ]; then
        mkdir -p "$RUNTIPI_LOG_DIR"
        chmod 755 "$RUNTIPI_LOG_DIR"
    fi
}

# Auto-initialize logging when script is sourced
init_logging

# Get current timestamp
_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# ============================================================================
# LOGGING FUNCTIONS (all go to single log file with timestamps)
# ============================================================================
log_info() {
    echo "$(_timestamp) ℹ️  $1" >> "$RUNTIPI_LOG"
}

log_success() {
    echo "$(_timestamp) ✅ $1" >> "$RUNTIPI_LOG"
}

log_warn() {
    echo "$(_timestamp) ⚠️  $1" >> "$RUNTIPI_LOG"
}

log_error() {
    echo "$(_timestamp) ❌ $1" >> "$RUNTIPI_LOG"
}

log_debug() {
    echo "$(_timestamp) 🐛 $1" >> "$RUNTIPI_LOG"
}

log_section() {
    {
        echo ""
        echo "$(_timestamp) ╔══════════════════════════════════════════════════════════╗"
        echo "$(_timestamp) ║  $1"
        echo "$(_timestamp) ╚══════════════════════════════════════════════════════════╝"
    } >> "$RUNTIPI_LOG"
}

# ============================================================================
# ADM INTEGRATION
# ============================================================================
# Notify ADM admin via system notification (if available)
notify_admin() {
    msg="$1"
    if command -v /usr/syno/bin/synodsmnotify >/dev/null 2>&1; then
        # Synology-style notification (shouldn't be on ASUSTOR but just in case)
        /usr/syno/bin/synodsmnotify -c "Runtipi" "$msg" 2>/dev/null || true
    fi
    # ASUSTOR notification method (if it exists in future ADM versions)
    if command -v notify_admin >/dev/null 2>&1; then
        notify_admin -t "Runtipi" -m "$msg" 2>/dev/null || true
    fi
    # Always log the notification
    log_warn "NOTIFICATION: $msg"
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================
# Mask sensitive values for logging
mask_secret() {
    value="$1"
    if [ "${#value}" -gt 4 ]; then
        # Show first 4 chars + ***
        echo "${value%${value#????}}***"
    else
        echo "***"
    fi
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if running as root
is_root() {
    [ "$(id -u)" = "0" ]
}

# Get file size in human readable format
get_file_size() {
    if [ -f "$1" ]; then
        size=$(stat -c%s "$1" 2>/dev/null || stat -f%z "$1" 2>/dev/null || echo "0")
        if [ "$size" -gt 1073741824 ]; then
            echo "$((size / 1073741824)) GB"
        elif [ "$size" -gt 1048576 ]; then
            echo "$((size / 1048576)) MB"
        elif [ "$size" -gt 1024 ]; then
            echo "$((size / 1024)) KB"
        else
            echo "$size B"
        fi
    else
        echo "N/A"
    fi
}

# ============================================================================
# FILE SYNC FUNCTIONS
# ============================================================================
# Sync persistent files from RunTipi to AppCentral
sync_to_appcentral() {
    pkg_dir="${1:-$APKG_PKG_DIR}"
    # Use explicit if/then to avoid shell syntax issues with && on BusyBox
    if [ -f "$RUNTIPI_PATH/.env" ]; then
        cp -f "$RUNTIPI_PATH/.env" "$pkg_dir/.env" 2>/dev/null || true
    fi
    if [ -d "$RUNTIPI_PATH/traefik/" ]; then
        cp -rf "$RUNTIPI_PATH/traefik/" "$pkg_dir/traefik/" 2>/dev/null || true
    fi
    if [ -e "$RUNTIPI_PATH/state" ]; then
        cp -rf "$RUNTIPI_PATH/state" "$pkg_dir/" 2>/dev/null || true
    fi
    if [ -f "$RUNTIPI_PATH/user-config/tipi-compose.yml" ]; then
        mkdir -p "$pkg_dir/user-config"
        cp -f "$RUNTIPI_PATH/user-config/tipi-compose.yml" "$pkg_dir/user-config/tipi-compose.yml" 2>/dev/null || true
    fi
    log_info "Synced persistent files to $pkg_dir"
}

# Sync persistent files from AppCentral to RunTipi
sync_to_runtipi() {
    pkg_dir="${1:-$APKG_PKG_DIR}"
    # Use explicit if/then to avoid shell syntax issues with && on BusyBox
    if [ -f "$pkg_dir/.env" ]; then
        cp -f "$pkg_dir/.env" "$RUNTIPI_PATH/.env" 2>/dev/null || true
    fi
    if [ -d "$pkg_dir/traefik/" ]; then
        cp -rf "$pkg_dir/traefik/" "$RUNTIPI_PATH/traefik/" 2>/dev/null || true
    fi
    if [ -e "$pkg_dir/state" ]; then
        cp -rf "$pkg_dir/state" "$RUNTIPI_PATH/" 2>/dev/null || true
    fi
    if [ -f "$pkg_dir/user-config/tipi-compose.yml" ]; then
        mkdir -p "$RUNTIPI_PATH/user-config"
        cp -f "$pkg_dir/user-config/tipi-compose.yml" "$RUNTIPI_PATH/user-config/tipi-compose.yml" 2>/dev/null || true
    fi
    log_info "Synced persistent files to $RUNTIPI_PATH"
}

# ============================================================================
# SETTINGS SYNC (settings.json → .env)
# ============================================================================
sync_settings_to_env() {
    settings_json="$RUNTIPI_PATH/state/settings.json"
    env_file="${1:-$APKG_PKG_DIR/.env}"

    # Check if jq is installed
    if ! command_exists jq; then
        log_error "jq is not installed - cannot sync settings"
        return 1
    fi

    [ ! -f "$settings_json" ] && {
        log_warn "settings.json not found: $settings_json"
        return 0
    }

    # Backup .env before modification (skip if file doesn't exist)
    if [ -f "$env_file" ]; then
        backup_name="$env_file.bak.$(date +%Y%m%d%H%M%S)"
        cp "$env_file" "$backup_name" 2>/dev/null || true
        # Keep only the 5 most recent backups
        ls -1t "$env_file.bak."* 2>/dev/null | tail -n +6 | while read -r old; do
            rm -f "$old"
        done
    else
        # No .env file yet, nothing to sync
        log_info "No .env file to sync settings to"
        return 0
    fi

    # Map JSON keys to ENV keys
    keys="internalIp:INTERNAL_IP appsRepoUrl:APPS_REPO_URL domain:DOMAIN appDataPath:RUNTIPI_APP_DATA_PATH localDomain:LOCAL_DOMAIN guestDashboard:GUEST_DASHBOARD allowAutoThemes:ALLOW_AUTO_THEMES allowErrorMonitoring:ALLOW_ERROR_MONITORING persistTraefikConfig:PERSIST_TRAEFIK_CONFIG port:NGINX_PORT sslPort:NGINX_PORT_SSL listenIp:SERVER_ADDR timeZone:TZ eventsTimeout:QUEUE_TIMEOUT_IN_MINUTES advancedSettings:ADVANCED_SETTINGS forwardAuthUrl:RUNTIPI_FORWARD_AUTH_URL logLevel:LOG_LEVEL themeBase:THEME_BASE themeColor:THEME_COLOR"

    for mapping in $keys; do
        json_key="${mapping%%:*}"
        env_key="${mapping##*:}"
        json_value=$(jq -r --arg key "$json_key" '.[$key]' "$settings_json")
        
        # Ignore null, undefined or empty values
        if [ "$json_value" = "null" ] || [ "$json_value" = "undefined" ] || [ -z "$json_value" ]; then
            continue
        fi

        # Convert true/false to lowercase
        case "$json_value" in
            true|false) json_value=$(echo "$json_value" | tr '[:upper:]' '[:lower:]');;
        esac

        # Only update existing variables
        if grep -q "^$env_key=" "$env_file" 2>/dev/null; then
            current_value=$(grep -E "^$env_key=" "$env_file" | cut -d'=' -f2-)
            if [ "$current_value" != "$json_value" ]; then
                sed -i "s|^$env_key=.*|$env_key=$json_value|" "$env_file"
                log_info "Updated $env_key in .env ($current_value → $json_value)"
            fi
        fi
    done
}

# ============================================================================
# PORT CHECKING
# ============================================================================
check_port_available() {
    port="$1"
    if command_exists netstat; then
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            return 1
        fi
    elif command_exists ss; then
        if ss -tuln 2>/dev/null | grep -q ":$port "; then
            return 1
        fi
    fi
    return 0
}

check_required_ports() {
    for port in 8880 4443; do
        if ! check_port_available "$port"; then
            log_error "Port $port is already in use"
            notify_admin "Runtipi failed to start: port $port is already in use."
            return 1
        fi
    done
    return 0
}

# ============================================================================
# BACKUP FUNCTIONS
# ============================================================================
create_backup() {
    backup_name="${1:-runtipi-backup-$(date +%Y%m%d%H%M%S).tar.gz}"
    backup_path="$RUNTIPI_BACKUP_DIR/$backup_name"
    max_backups="${2:-5}"
    
    mkdir -p "$RUNTIPI_BACKUP_DIR"
    
    if [ -d "$RUNTIPI_PATH" ]; then
        cd "$RUNTIPI_PATH" || return 1
        if tar czf "$backup_path" .env state traefik user-config 2>/dev/null; then
            log_success "Backup created: $backup_path"
            # Cleanup old backups
            ls -1t "$RUNTIPI_BACKUP_DIR"/runtipi-backup-*.tar.gz 2>/dev/null | \
                tail -n +"$((max_backups + 1))" | while read -r old; do
                rm -f "$old"
            done
            return 0
        fi
    fi
    log_warn "Backup failed or no data to backup"
    return 1
}

# ============================================================================
# LOG ROTATION
# ============================================================================
rotate_logs() {
    max_size="${1:-10485760}"  # 10MB default
    max_keep="${2:-1000}"      # Keep last 1000 lines after rotation
    
    # Rotate package.log
    if [ -f "$RUNTIPI_LOG" ]; then
        size=$(stat -c%s "$RUNTIPI_LOG" 2>/dev/null || echo "0")
        if [ "$size" -gt "$max_size" ]; then
            tail -n "$max_keep" "$RUNTIPI_LOG" > "$RUNTIPI_LOG.tmp"
            mv "$RUNTIPI_LOG.tmp" "$RUNTIPI_LOG"
            log_info "📋 package.log rotated (kept last $max_keep lines)"
        fi
    fi
    
    # Rotate cli.log
    if [ -f "$CLI_LOG" ]; then
        size=$(stat -c%s "$CLI_LOG" 2>/dev/null || echo "0")
        if [ "$size" -gt "$max_size" ]; then
            tail -n "$max_keep" "$CLI_LOG" > "$CLI_LOG.tmp"
            mv "$CLI_LOG.tmp" "$CLI_LOG"
            log_info "📋 cli.log rotated (kept last $max_keep lines)"
        fi
    fi
}

# ============================================================================
# SECURE FILE PERMISSIONS
# ============================================================================
secure_permissions() {
    # Secure sensitive files (read/write for owner only)
    chmod 600 "$APKG_PKG_DIR/.env" 2>/dev/null || true
    chmod 600 "$RUNTIPI_PATH/.env" 2>/dev/null || true
    chmod 600 "$RUNTIPI_PATH/state/settings.json" 2>/dev/null || true
    
    # Ensure state directory and database files are writable
    if [ -d "$RUNTIPI_PATH/state" ]; then
        chmod 755 "$RUNTIPI_PATH/state" 2>/dev/null || true
        # SQLite databases need to be writable (also for journal/wal files)
        find "$RUNTIPI_PATH/state" -type f \( -name "*.db" -o -name "*.sqlite" -o -name "*.sqlite3" \) \
            -exec chmod 644 {} \; 2>/dev/null || true
    fi
    
    # Ensure state in AppCentral is also writable
    if [ -d "$APKG_PKG_DIR/state" ]; then
        chmod 755 "$APKG_PKG_DIR/state" 2>/dev/null || true
        find "$APKG_PKG_DIR/state" -type f \( -name "*.db" -o -name "*.sqlite" -o -name "*.sqlite3" \) \
            -exec chmod 644 {} \; 2>/dev/null || true
    fi
    
    # Secure backup files
    find "$APKG_PKG_DIR" -maxdepth 1 -name '.env.bak.*' -exec chmod 600 {} \; 2>/dev/null || true
}

# ============================================================================
# DEPENDENCY CHECKS
# ============================================================================
check_dependencies() {
    missing=""
    for cmd in docker curl openssl jq git; do
        if ! command_exists "$cmd"; then
            missing="$missing $cmd"
        fi
    done
    
    if [ -n "$missing" ]; then
        log_error "Missing dependencies:$missing"
        return 1
    fi
    log_success "All dependencies found"
    return 0
}

check_docker() {
    if ! command_exists docker; then
        log_error "Docker is not installed"
        return 1
    fi
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker is not running or user has no permission"
        return 1
    fi
    log_success "Docker is available"
    return 0
}

# ============================================================================
# ARCHITECTURE DETECTION
# ============================================================================
get_architecture() {
    arch=$(uname -m)
    case "$arch" in
        x86_64|amd64) echo "x86-64" ;;
        aarch64|arm64) echo "arm64" ;;
        armv7*|armhf) echo "armv7" ;;
        i686|i386) echo "i386" ;;
        *) echo "$arch" ;;
    esac
}

is_supported_architecture() {
    arch=$(get_architecture)
    case "$arch" in
        x86-64|arm64) return 0 ;;
        *) return 1 ;;
    esac
}

# ============================================================================
# CLI BINARY SELECTION
# ============================================================================
get_cli_asset_name() {
    arch=$(get_architecture)
    case "$arch" in
        x86-64) echo "runtipi-cli-linux-x86_64" ;;
        arm64) echo "runtipi-cli-linux-aarch64" ;;
        *) echo "" ;;
    esac
}

# ============================================================================
# CLI WRAPPER - Run CLI commands with clean logging
# ============================================================================
# Usage: run_cli start|stop [args...]
# Returns: 0 on success, 1 on failure
# CLI output is logged to cli.log, parsed results to package.log
run_cli() {
    action="$1"
    shift
    cli_path="${APKG_PKG_DIR:-/usr/local/AppCentral/io.runtipi}/runtipi-cli"
    
    if [ ! -x "$cli_path" ]; then
        log_error "CLI not found: $cli_path"
        return 1
    fi
    
    # Log CLI command execution
    {
        echo ""
        echo "═══════════════════════════════════════════════════════════════"
        echo "$(date '+%Y-%m-%d %H:%M:%S') CLI: $action $*"
        echo "═══════════════════════════════════════════════════════════════"
    } >> "$CLI_LOG"
    
    # Run CLI and capture output to cli.log
    if "$cli_path" "$action" "$@" >> "$CLI_LOG" 2>&1; then
        # Parse cli.log for success lines (last command output)
        # Extract lines starting with ✓ from the end of the file
        tail -50 "$CLI_LOG" 2>/dev/null | grep -E "^✓|^✔" | while read -r line; do
            # Remove the checkmark and trim
            msg=$(echo "$line" | sed 's/^[✓✔][[:space:]]*//')
            [ -n "$msg" ] && log_info "  ✓ $msg"
        done
        
        case "$action" in
            start)
                log_success "Docker containers started"
                ;;
            stop)
                log_success "Docker containers stopped"
                ;;
            restart)
                log_success "Docker containers restarted"
                ;;
            *)
                log_success "CLI command '$action' completed"
                ;;
        esac
        return 0
    else
        # On failure, extract errors from cli.log
        tail -20 "$CLI_LOG" 2>/dev/null | grep -iE "error|failed|cannot|unable" | head -5 | while read -r line; do
            log_error "  $line"
        done
        log_error "CLI command '$action' failed (see cli.log for details)"
        return 1
    fi
}

# ============================================================================
# VERSION HELPERS
# ============================================================================
get_installed_version() {
    if [ -f "$APKG_PKG_DIR/VERSION" ]; then
        cat "$APKG_PKG_DIR/VERSION"
    else
        echo "unknown"
    fi
}

# ============================================================================
# CUSTOM APP STORE - Auto-add JigSaw's tipi-store on first start
# ============================================================================
CUSTOM_STORE_URL="https://github.com/JigSawFr/tipi-store"
CUSTOM_STORE_BRANCH="main"
CUSTOM_STORE_FLAG="$RUNTIPI_PATH/.custom-store-added"

# Wait for the database container to be healthy
wait_for_db() {
    max_attempts="${1:-30}"
    attempt=0
    
    log_info "⏳ Waiting for database to be ready..."
    
    while [ "$attempt" -lt "$max_attempts" ]; do
        # Check if container exists and get health status
        health=$(docker inspect --format='{{.State.Health.Status}}' runtipi-db 2>/dev/null || echo "not-found")
        
        case "$health" in
            healthy)
                log_success "Database container is healthy"
                return 0
                ;;
            not-found)
                # Container doesn't exist yet, wait
                ;;
            *)
                # starting, unhealthy, etc.
                ;;
        esac
        
        attempt=$((attempt + 1))
        log_info "  Waiting for database... ($attempt/$max_attempts) [status: $health]"
        sleep 2
    done
    
    log_warn "Database did not become healthy in time"
    return 1
}

# Generate SHA256 hash for store URL (same as Runtipi does)
generate_store_hash() {
    url="$1"
    echo -n "$url" | sha256sum | cut -d' ' -f1
}

# Add custom tipi-store to database
add_custom_store() {
    store_url="${1:-$CUSTOM_STORE_URL}"
    store_branch="${2:-$CUSTOM_STORE_BRANCH}"
    store_name="${3:-JigSaw Store}"
    
    # Generate hash (same method as Runtipi: SHA256 of URL)
    store_hash=$(generate_store_hash "$store_url")
    store_slug=$(echo "$store_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
    
    log_info "🏪 Adding custom app store: $store_name"
    log_info "   URL: $store_url"
    log_info "   Branch: $store_branch"
    log_info "   Hash: $(mask_secret "$store_hash")"
    
    # Check if store already exists
    exists=$(docker exec runtipi-db psql -U tipi -d tipi -tAc \
        "SELECT COUNT(*) FROM app_store WHERE url = '$store_url';" 2>/dev/null || echo "0")
    
    if [ "$exists" != "0" ] && [ -n "$exists" ]; then
        log_info "   Store already exists in database, skipping"
        return 0
    fi
    
    # Insert into database
    if docker exec runtipi-db psql -U tipi -d tipi -c \
        "INSERT INTO app_store (slug, hash, name, enabled, url, branch, created_at) 
         VALUES ('$store_slug', '$store_hash', '$store_name', true, '$store_url', '$store_branch', NOW())
         ON CONFLICT (url) DO NOTHING;" 2>/dev/null; then
        log_success "   Store added to database"
    else
        log_error "   Failed to add store to database"
        return 1
    fi
    
    # Clone the repository
    repos_dir="$RUNTIPI_PATH/repos/$store_hash"
    if [ ! -d "$repos_dir" ]; then
        log_info "   Cloning repository..."
        if git clone --depth 1 --branch "$store_branch" "$store_url" "$repos_dir" 2>/dev/null; then
            log_success "   Repository cloned to $repos_dir"
        else
            log_warn "   Failed to clone repository (will be cloned by Runtipi on next refresh)"
        fi
    else
        log_info "   Repository already exists at $repos_dir"
    fi
    
    return 0
}

# First-start hook: add custom store if not already done
run_first_start_hook() {
    # Skip if already done
    if [ -f "$CUSTOM_STORE_FLAG" ]; then
        log_info "🏪 Custom store already configured (skipping)"
        return 0
    fi
    
    log_section "🏪 First Start Hook - Adding Custom App Store"
    
    # Wait for database to be ready
    if ! wait_for_db 30; then
        log_warn "Could not add custom store: database not ready"
        log_info "You can add it manually later via the Runtipi UI"
        return 1
    fi
    
    # Small delay to ensure DB is fully initialized
    sleep 2
    
    # Add the custom store
    if add_custom_store "$CUSTOM_STORE_URL" "$CUSTOM_STORE_BRANCH" "JigSaw Store"; then
        # Create flag to prevent re-running
        touch "$CUSTOM_STORE_FLAG"
        log_success "🎉 Custom app store configured successfully!"
        log_info "   Refresh the App Store in Runtipi UI to see new apps"
        return 0
    else
        log_warn "Custom store could not be added automatically"
        log_info "You can add it manually via Settings > App Stores in Runtipi UI"
        return 1
    fi
}

# ============================================================================
# INITIALIZATION (call this at script start)
# ============================================================================
# Initialize logging when this file is sourced
init_logging
