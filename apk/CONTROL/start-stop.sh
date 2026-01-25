#!/bin/sh
# ============================================================================
# START-STOP.SH - Service lifecycle management for Runtipi
# This script must remain POSIX/sh compatible for ADM 5.x (BusyBox/ash)
# ============================================================================

# ADM copies start-stop.sh to /etc/script/, so we must use APKG_PKG_DIR to find common.sh
CONTROL_DIR="$APKG_PKG_DIR/CONTROL"

if [ ! -f "$CONTROL_DIR/common.sh" ]; then
    echo "ERROR: common.sh not found at $CONTROL_DIR/common.sh" >&2
    exit 1
fi

. "$CONTROL_DIR/common.sh"

# Redirect output to package log
exec 1>>"$RUNTIPI_LOG" 2>&1

# Enable strict mode after redirection is set up
set -eu

# ============================================================================
# SERVICE FUNCTIONS
# ============================================================================
do_start() {
    log_section "🚀 Starting Runtipi Service"
    
    log_info "📂 Syncing persistent files..."
    sync_to_appcentral "$APKG_PKG_DIR"
    
    cd "$APKG_PKG_DIR" || {
        log_error "Cannot change to $APKG_PKG_DIR"
        exit 1
    }
    
    # Verify CLI exists
    if [ ! -x "$APKG_PKG_DIR/runtipi-cli" ]; then
        log_error "runtipi-cli not found or not executable"
        notify_admin "Runtipi failed to start: CLI not found"
        exit 1
    fi
    log_info "✓ CLI found"
    
    # Check ports before starting
    log_info "🔌 Checking required ports..."
    if ! check_required_ports; then
        exit 1
    fi
    
    # Start the service
    log_info "🐳 Starting Docker containers..."
    if run_cli start --env-file="$APKG_PKG_DIR/.env"; then
        log_success "🎉 Service started successfully!"
        sleep 3
        log_info "🔒 Securing permissions..."
        secure_permissions
        
        # Run first-start hook (add custom app store) in background
        # This runs asynchronously to not block the service start
        (run_first_start_hook) &
    else
        log_error "Failed to start service"
        notify_admin "Runtipi failed to start: CLI error"
        exit 1
    fi
}

do_stop() {
    log_section "🛑 Stopping Runtipi Service"
    
    cd "$APKG_PKG_DIR" || {
        log_error "Cannot change to $APKG_PKG_DIR"
        exit 1
    }
    
    # Verify CLI exists
    if [ ! -x "$APKG_PKG_DIR/runtipi-cli" ]; then
        log_error "runtipi-cli not found or not executable"
        exit 1
    fi
    
    # Backup .env to bin folder before stop (if exists)
    if [ -f "$APKG_PKG_DIR/.env" ]; then
        log_info "💾 Backing up environment..."
        cp -f "$APKG_PKG_DIR/.env" "$APKG_PKG_DIR/bin/.env" 2>/dev/null || true
    fi
    
    # Stop the service
    log_info "🐳 Stopping Docker containers..."
    if run_cli stop; then
        log_success "Service stopped"
    else
        log_error "Failed to stop service"
        exit 1
    fi
    
    # Sync settings back to .env
    log_info "📝 Syncing settings..."
    sync_settings_to_env "$APKG_PKG_DIR/.env"
    
    log_success "🎉 Service stopped successfully!"
    sleep 3
}

do_restart() {
    log_section "🔁 Restarting Runtipi Service"
    log_info "This may take a moment..."
    do_stop
    do_start
    log_success "🎉 Service restarted successfully!"
}

# ============================================================================
# MAIN
# ============================================================================
case "${1:-}" in
    start)
        do_start
        ;;
    stop)
        do_stop
        ;;
    restart)
        do_restart
        ;;
    *)
        echo "Usage: $0 {start|stop|restart}"
        exit 1
        ;;
esac

exit 0
