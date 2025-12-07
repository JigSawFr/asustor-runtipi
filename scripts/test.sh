#!/bin/sh
# ============================================================================
# TEST.SH - Comprehensive test suite for Runtipi ASUSTOR package
# This script can be run in two modes:
#   - Development mode: Tests syntax, JSON validation, Python compilation
#   - Runtime mode: Tests on actual ASUSTOR NAS (requires APKG_PKG_DIR)
#
# Usage:
#   sh scripts/test.sh          # Run development tests
#   sh scripts/test.sh --runtime  # Run runtime tests (on NAS only)
# ============================================================================
set -eu

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Test output
print_header() {
    printf "\n${CYAN}══════════════════════════════════════════════════════════════${NC}\n"
    printf "${CYAN}  %s${NC}\n" "$1"
    printf "${CYAN}══════════════════════════════════════════════════════════════${NC}\n"
}

print_result() {
    if [ "$1" = "pass" ]; then
        printf "${GREEN}✓${NC} %s\n" "$2"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    elif [ "$1" = "fail" ]; then
        printf "${RED}✗${NC} %s\n" "$2"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    else
        printf "${YELLOW}○${NC} %s (skipped)\n" "$2"
        TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
    fi
}

run_test() {
    name="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        print_result "pass" "$name"
        return 0
    else
        print_result "fail" "$name"
        return 1
    fi
}

# ============================================================================
# DEVELOPMENT TESTS (run without NAS environment)
# ============================================================================
run_dev_tests() {
    print_header "Shell Script Syntax Tests"

    # Test shell script syntax
    for script in "$PROJECT_ROOT"/apk/CONTROL/*.sh; do
        if [ -f "$script" ]; then
            run_test "Syntax: $(basename "$script")" sh -n "$script"
        fi
    done

    for script in "$PROJECT_ROOT"/scripts/*.sh; do
        if [ -f "$script" ]; then
            run_test "Syntax: $(basename "$script")" sh -n "$script"
        fi
    done

    print_header "JSON Validation Tests"

    # Test JSON files are valid
    for json in "$PROJECT_ROOT"/apk/CONTROL/*.json; do
        if [ -f "$json" ]; then
            if command -v jq >/dev/null 2>&1; then
                run_test "JSON: $(basename "$json")" jq . "$json"
            elif command -v python3 >/dev/null 2>&1; then
                run_test "JSON: $(basename "$json")" python3 -c "import json; json.load(open('$json'))"
            else
                print_result "skip" "JSON: $(basename "$json") - no validator available"
            fi
        fi
    done

    print_header "Python Script Tests"

    # Test Python syntax
    if command -v python3 >/dev/null 2>&1; then
        for py in "$PROJECT_ROOT"/build/*.py; do
            if [ -f "$py" ]; then
                run_test "Python syntax: $(basename "$py")" python3 -m py_compile "$py"
            fi
        done

        # Test Python imports work
        run_test "Import build.py" python3 -c "import sys; sys.path.insert(0, '$PROJECT_ROOT/build'); import build"

        # Test version-manager --current
        run_test "version-manager --current" python3 "$PROJECT_ROOT/build/version-manager.py" --current -q

        # Test build.py --version
        run_test "build.py --version" python3 "$PROJECT_ROOT/build/build.py" --version
    else
        print_result "skip" "Python tests - python3 not available"
    fi

    print_header "Configuration Validation Tests"

    # Validate config.json structure
    if command -v python3 >/dev/null 2>&1; then
        run_test "config.json structure" python3 -c "
import json
with open('$PROJECT_ROOT/apk/CONTROL/config.json') as f:
    config = json.load(f)
    g = config.get('general', {})
    assert 'general' in config, 'Missing general section'
    assert g.get('version'), 'Missing version'
    assert g.get('package'), 'Missing package name'
    assert g.get('name'), 'Missing name'
    assert g.get('architecture'), 'Missing architecture'
"
    fi

    # Check required files exist
    required_files="
        apk/CONTROL/config.json
        apk/CONTROL/description.json
        apk/CONTROL/common.sh
        apk/CONTROL/bootstrap-logging.sh
        apk/CONTROL/pre-install.sh
        apk/CONTROL/post-install.sh
        apk/CONTROL/start-stop.sh
        apk/CONTROL/icon.png
        build/build.py
        build/version-manager.py
        README.md
        LICENSE
    "

    print_header "Required Files Check"

    for file in $required_files; do
        if [ -f "$PROJECT_ROOT/$file" ]; then
            print_result "pass" "File exists: $file"
        else
            print_result "fail" "File missing: $file"
        fi
    done

    # Check icon size if ImageMagick is available
    if command -v identify >/dev/null 2>&1; then
        icon_size=$(identify -format "%wx%h" "$PROJECT_ROOT/apk/CONTROL/icon.png" 2>/dev/null || echo "unknown")
        if [ "$icon_size" = "90x90" ]; then
            print_result "pass" "Icon size: 90x90"
        else
            print_result "fail" "Icon size should be 90x90, got: $icon_size"
        fi
    fi

    print_header "Line Endings Check"

    # Check for CRLF line endings in shell scripts
    crlf_found=false
    for script in "$PROJECT_ROOT"/apk/CONTROL/*.sh "$PROJECT_ROOT"/scripts/*.sh; do
        if [ -f "$script" ]; then
            # Use file command to detect CRLF line terminators
            if file "$script" | grep -qi "CRLF"; then
                print_result "fail" "CRLF in: $(basename "$script")"
                crlf_found=true
            fi
        fi
    done
    if [ "$crlf_found" = "false" ]; then
        print_result "pass" "No CRLF line endings in shell scripts"
    fi
}

# ============================================================================
# RUNTIME TESTS (run on actual ASUSTOR NAS)
# ============================================================================
run_runtime_tests() {
    print_header "Runtime Tests (NAS Environment)"

    # Check APKG_PKG_DIR is set
    if [ -z "${APKG_PKG_DIR:-}" ]; then
        printf "${RED}Error: APKG_PKG_DIR not set. Run with --dev for development tests.${NC}\n"
        exit 1
    fi

    # Check dependencies
    print_header "Dependency Check"
    for dep in docker jq git curl openssl; do
        run_test "Dependency: $dep" command -v "$dep"
    done

    # Check CLI
    print_header "CLI Tests"
    if [ -x "$APKG_PKG_DIR/runtipi-cli" ]; then
        print_result "pass" "CLI is executable"
        run_test "CLI version" "$APKG_PKG_DIR/runtipi-cli" --version
    else
        print_result "fail" "CLI not found or not executable"
    fi

    # Check persistent files
    print_header "File System Tests"
    if [ -f "$APKG_PKG_DIR/.env" ]; then
        print_result "pass" ".env exists"
    else
        print_result "fail" ".env missing"
    fi

    if [ -d "/share/Docker/RunTipi" ]; then
        print_result "pass" "RunTipi directory exists"
    else
        print_result "fail" "RunTipi directory missing"
    fi

    # Check permissions
    if [ -f "$APKG_PKG_DIR/.env" ]; then
        perms=$(stat -c "%a" "$APKG_PKG_DIR/.env" 2>/dev/null || stat -f "%OLp" "$APKG_PKG_DIR/.env" 2>/dev/null || echo "unknown")
        if [ "$perms" = "600" ]; then
            print_result "pass" ".env permissions: 600"
        else
            print_result "fail" ".env permissions should be 600, got: $perms"
        fi
    fi
}

# ============================================================================
# MAIN
# ============================================================================
main() {
    printf "${CYAN}🧪 Runtipi ASUSTOR Package Test Suite${NC}\n"
    printf "Started: $(date)\n"

    if [ "${1:-}" = "--runtime" ]; then
        run_runtime_tests
    else
        run_dev_tests
    fi

    # Summary
    print_header "Test Results Summary"
    printf "${GREEN}Passed:  %d${NC}\n" "$TESTS_PASSED"
    printf "${RED}Failed:  %d${NC}\n" "$TESTS_FAILED"
    printf "${YELLOW}Skipped: %d${NC}\n" "$TESTS_SKIPPED"

    total=$((TESTS_PASSED + TESTS_FAILED))
    if [ "$TESTS_FAILED" -eq 0 ]; then
        printf "\n${GREEN}✅ All tests passed!${NC}\n"
        exit 0
    else
        printf "\n${RED}❌ %d of %d tests failed${NC}\n" "$TESTS_FAILED" "$total"
        exit 1
    fi
}

main "$@"
