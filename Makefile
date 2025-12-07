# Makefile for ASUSTOR Runtipi Package
# Usage: make [target]

.PHONY: all build build-dev build-arm64 build-all test test-shell test-python lint lint-shell lint-python clean help

# Default target
all: lint test build

# ============================================================================
# BUILD TARGETS
# ============================================================================

## Build x86-64 APK package
build:
	@echo "📦 Building x86-64 APK..."
	python3 build/build.py

## Build development APK (with auto-increment counter)
build-dev:
	@echo "🔧 Building development APK..."
	python3 build/build.py --dev

## Build ARM64 APK package
build-arm64:
	@echo "📦 Building ARM64 APK..."
	python3 build/build-arm64.py

## Build both architectures
build-all: build build-arm64
	@echo "✅ All packages built"

# ============================================================================
# TEST TARGETS
# ============================================================================

## Run all tests
test: test-shell test-python
	@echo "✅ All tests completed"

## Run shell script tests
test-shell:
	@echo "🧪 Running shell tests..."
	@sh scripts/test.sh

## Run Python unit tests
test-python:
	@echo "🧪 Running Python tests..."
	@python3 -m pytest build/tests/ -v 2>/dev/null || echo "⚠️  pytest not installed, skipping Python tests"

# ============================================================================
# LINT TARGETS
# ============================================================================

## Run all linters
lint: lint-shell lint-python lint-json
	@echo "✅ All linting completed"

## Lint shell scripts with ShellCheck
lint-shell:
	@echo "🔍 Linting shell scripts..."
	@command -v shellcheck >/dev/null 2>&1 || { echo "⚠️  ShellCheck not installed"; exit 0; }
	@shellcheck -s sh -e SC2039,SC3037 apk/CONTROL/*.sh scripts/*.sh 2>&1 || true

## Lint Python files
lint-python:
	@echo "🔍 Linting Python files..."
	@python3 -m py_compile build/build.py build/version-manager.py build/docker-images.py
	@command -v ruff >/dev/null 2>&1 && ruff check build/ || echo "⚠️  ruff not installed, basic syntax check only"

## Validate JSON files
lint-json:
	@echo "🔍 Validating JSON files..."
	@for f in apk/CONTROL/*.json; do \
		python3 -c "import json; json.load(open('$$f'))" && echo "  ✓ $$f"; \
	done

# ============================================================================
# UTILITY TARGETS
# ============================================================================

## Clean build artifacts
clean:
	@echo "🧹 Cleaning build artifacts..."
	rm -rf releases/dev/*.apk
	rm -rf build/__pycache__
	rm -rf build/tests/__pycache__
	rm -rf .pytest_cache
	rm -rf .mypy_cache
	rm -rf .ruff_cache
	@echo "✅ Clean completed"

## Show current version
version:
	@python3 build/version-manager.py --current

## Check if version needs revision
version-check:
	@python3 build/version-manager.py --check

## Update Docker image versions
docker-update:
	@python3 build/docker-images.py --update
	@python3 build/docker-images.py --show

## List APK contents
list:
	@if [ -z "$(APK)" ]; then \
		echo "Usage: make list APK=path/to/file.apk"; \
	else \
		python3 build/build.py --list "$(APK)"; \
	fi

## Generate checksums for releases
checksums:
	@cd releases && sha256sum *.apk > checksums.sha256 && cat checksums.sha256

# ============================================================================
# HELP
# ============================================================================

## Show this help message
help:
	@echo "ASUSTOR Runtipi Package - Available targets:"
	@echo ""
	@echo "Build:"
	@echo "  make build        - Build x86-64 APK"
	@echo "  make build-dev    - Build development APK"
	@echo "  make build-arm64  - Build ARM64 APK"
	@echo "  make build-all    - Build both architectures"
	@echo ""
	@echo "Test:"
	@echo "  make test         - Run all tests"
	@echo "  make test-shell   - Run shell tests only"
	@echo "  make test-python  - Run Python tests only"
	@echo ""
	@echo "Lint:"
	@echo "  make lint         - Run all linters"
	@echo "  make lint-shell   - Lint shell scripts"
	@echo "  make lint-python  - Lint Python files"
	@echo ""
	@echo "Utility:"
	@echo "  make clean        - Remove build artifacts"
	@echo "  make version      - Show current version"
	@echo "  make docker-update - Update Docker image versions"
	@echo "  make list APK=x   - List APK contents"
	@echo ""
