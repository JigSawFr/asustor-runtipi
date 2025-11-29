#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ASUSTOR APK Builder - Cross-platform version (Windows/Linux/Mac)
Based on official apkg-tools_py3.py but adapted for Windows compatibility.

Usage:
    python build.py [--destination <folder>]
    
Requirements:
    - Python 3.7+
    - No external dependencies (uses only standard library)
"""

import os
import sys
import argparse
import zipfile
import tarfile
import tempfile
import shutil
import json
import re
import hashlib
import struct
import urllib.request
import urllib.error
from datetime import datetime
from pathlib import Path

__version__ = '1.5.0'

# Resolve paths - script is in build/ folder, project root is parent
SCRIPT_DIR = Path(__file__).parent.resolve()
PROJECT_ROOT = SCRIPT_DIR.parent
RELEASES_DIR = PROJECT_ROOT / 'releases'
DEV_RELEASES_DIR = RELEASES_DIR / 'dev'
DEV_BUILD_COUNTER_FILE = SCRIPT_DIR / '.dev-build-counter'
CHANGELOG_MD = PROJECT_ROOT / 'CHANGELOG.md'  # Main changelog (GitHub visible)
CHANGELOG_TXT = PROJECT_ROOT / 'apk' / 'CONTROL' / 'changelog.txt'  # APK copy
LICENSE_SRC = PROJECT_ROOT / 'LICENSE'  # Main license (GitHub visible)
LICENSE_TXT = PROJECT_ROOT / 'apk' / 'CONTROL' / 'license.txt'  # APK copy
PACKAGE_NOTES_FILE = SCRIPT_DIR / 'package-notes.md'

# Configuration
MAX_DEV_BUILDS = 5  # Keep only the last N dev builds
GITHUB_REPO = 'runtipi/runtipi'  # For fetching release notes


class Colors:
    """ANSI color codes for terminal output."""
    RESET = '\033[0m'
    GREEN = '\033[92m'
    CYAN = '\033[96m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    BLUE = '\033[94m'
    GRAY = '\033[90m'
    
    @classmethod
    def enable(cls):
        """Enable colors on Windows."""
        if sys.platform == 'win32':
            try:
                import ctypes
                kernel32 = ctypes.windll.kernel32
                kernel32.SetConsoleMode(kernel32.GetStdHandle(-11), 7)
            except Exception:
                # Disable colors if we can't enable ANSI on Windows
                cls.RESET = cls.GREEN = cls.CYAN = cls.YELLOW = ''
                cls.RED = cls.BLUE = cls.GRAY = ''


def print_success(msg):
    print(f"{Colors.GREEN}✅ {msg}{Colors.RESET}")


def print_info(msg):
    print(f"{Colors.CYAN}🔹 {msg}{Colors.RESET}")


def print_warn(msg):
    print(f"{Colors.YELLOW}⚠️  {msg}{Colors.RESET}")


def print_error(msg):
    print(f"{Colors.RED}❌ {msg}{Colors.RESET}")


# ============================================================================
# CHANGELOG GENERATION
# ============================================================================

def fetch_github_release_notes(version: str) -> str:
    """Fetch release notes from GitHub for a specific version."""
    url = f"https://api.github.com/repos/{GITHUB_REPO}/releases/tags/v{version}"
    
    try:
        req = urllib.request.Request(url, headers={
            'Accept': 'application/vnd.github.v3+json',
            'User-Agent': 'ASUSTOR-APK-Builder'
        })
        with urllib.request.urlopen(req, timeout=10) as response:
            data = json.loads(response.read().decode('utf-8'))
            return data.get('body', '')
    except urllib.error.HTTPError as e:
        if e.code == 404:
            print_warn(f"No GitHub release found for v{version}")
        else:
            print_warn(f"GitHub API error: {e.code}")
        return ''
    except Exception as e:
        print_warn(f"Could not fetch release notes: {e}")
        return ''


def parse_github_release_notes(body: str) -> dict:
    """Parse GitHub release notes into sections."""
    sections = {
        'added': [],
        'fixed': [],
        'improved': [],
        'updated': [],
        'other': []
    }
    
    if not body:
        return sections
    
    current_section = 'other'
    
    for line in body.split('\n'):
        line = line.strip()
        
        # Detect section headers
        lower_line = line.lower()
        if '## added' in lower_line or '### added' in lower_line or '**added**' in lower_line:
            current_section = 'added'
            continue
        elif '## fixed' in lower_line or '### fixed' in lower_line or '**fixed**' in lower_line:
            current_section = 'fixed'
            continue
        elif '## improved' in lower_line or '### improved' in lower_line or '**improved**' in lower_line:
            current_section = 'improved'
            continue
        elif '## updated' in lower_line or '### updated' in lower_line or '**updated**' in lower_line:
            current_section = 'updated'
            continue
        elif line.startswith('## ') or line.startswith('### '):
            current_section = 'other'
            continue
        
        # Extract bullet points
        if line.startswith('- ') or line.startswith('* '):
            item = line[2:].strip()
            if item:
                sections[current_section].append(item)
    
    return sections


def load_package_notes() -> dict:
    """Load package-specific notes from package-notes.md."""
    notes = {
        'current': [],
        'history': {}  # version -> list of notes
    }
    
    if not PACKAGE_NOTES_FILE.exists():
        return notes
    
    try:
        content = PACKAGE_NOTES_FILE.read_text(encoding='utf-8')
        current_version = None
        
        for line in content.split('\n'):
            line = line.strip()
            
            # Version header: ## [4.6.5] or ## Current
            if line.startswith('## '):
                header = line[3:].strip()
                if header.lower() == 'current':
                    current_version = 'current'
                else:
                    # Extract version from [4.6.5] format
                    match = re.search(r'\[?([\d.]+)\]?', header)
                    if match:
                        current_version = match.group(1)
                        notes['history'][current_version] = []
                continue
            
            # Bullet points
            if line.startswith('- ') or line.startswith('* '):
                item = line[2:].strip()
                if item:
                    if current_version == 'current':
                        notes['current'].append(item)
                    elif current_version and current_version in notes['history']:
                        notes['history'][current_version].append(item)
        
    except Exception as e:
        print_warn(f"Could not load package notes: {e}")
    
    return notes


def generate_changelog(version: str, package_version: str = None, is_dev: bool = False) -> str:
    """Generate changelog.txt content.
    
    Args:
        version: Base Runtipi version (e.g., "4.6.5")
        package_version: Full package version (e.g., "4.6.5.r1" or "4.6.5.dev3")
        is_dev: Whether this is a dev build
    """
    today = datetime.now().strftime('%Y-%m-%d')
    lines = []
    
    lines.append("# Changelog - Runtipi for ASUSTOR")
    lines.append("")
    lines.append("This changelog is auto-generated during build.")
    lines.append("")
    
    # Current version section
    display_version = package_version or version
    lines.append(f"## [{display_version}] - {today}")
    lines.append("")
    
    # Package-specific notes for current version
    pkg_notes = load_package_notes()
    
    # Fetch and parse GitHub release notes (Runtipi first)
    github_notes = fetch_github_release_notes(version)
    sections = parse_github_release_notes(github_notes)
    
    if any(sections.values()):
        lines.append(f"### Runtipi v{version}")
        
        if sections['added']:
            for item in sections['added']:
                lines.append(f"- Added: {item}")
        
        if sections['improved']:
            for item in sections['improved']:
                lines.append(f"- Improved: {item}")
        
        if sections['fixed']:
            for item in sections['fixed']:
                lines.append(f"- Fixed: {item}")
        
        if sections['updated']:
            for item in sections['updated']:
                lines.append(f"- Updated: {item}")
        
        if sections['other']:
            for item in sections['other'][:5]:  # Limit other items
                lines.append(f"- {item}")
        
        lines.append("")
    else:
        lines.append(f"### Runtipi v{version}")
        lines.append(f"- Core: Runtipi v{version} release")
        lines.append("")
    
    # ASUSTOR package-specific notes (after Runtipi notes)
    if pkg_notes['current']:
        lines.append("### ASUSTOR Package")
        for note in pkg_notes['current']:
            lines.append(f"- {note}")
        lines.append("")
    
    # Historical package notes
    if pkg_notes['history']:
        lines.append("---")
        lines.append("")
        lines.append("## Previous Versions")
        lines.append("")
        
        for hist_version, hist_notes in sorted(pkg_notes['history'].items(), reverse=True):
            if hist_notes:
                lines.append(f"### [{hist_version}]")
                for note in hist_notes:
                    lines.append(f"- {note}")
                lines.append("")
    
    # Footer
    lines.append("---")
    lines.append("")
    lines.append("For full Runtipi changelog, see [GitHub Releases](https://github.com/runtipi/runtipi/releases).")
    lines.append("")
    
    return '\n'.join(lines)


def update_changelog(version: str, package_version: str = None, is_dev: bool = False):
    """Update CHANGELOG.md and copy to changelog.txt. Skip for dev builds."""
    if is_dev:
        print_info("Skipping changelog (dev build)")
        return
    
    print_info("Generating changelog...")
    
    content = generate_changelog(version, package_version, is_dev)
    
    # Write main CHANGELOG.md with Unix line endings
    CHANGELOG_MD.write_text(content, encoding='utf-8', newline='\n')
    
    # Copy to APK changelog.txt
    CHANGELOG_TXT.write_text(content, encoding='utf-8', newline='\n')
    
    print_success("Changelog updated")


def copy_license():
    """Copy LICENSE to apk/CONTROL/license.txt with current year."""
    if not LICENSE_SRC.exists():
        print_warn("LICENSE file not found, skipping")
        return
    
    content = LICENSE_SRC.read_text(encoding='utf-8')
    
    # Update copyright year to current year
    current_year = datetime.now().year
    content = re.sub(r'Copyright \(c\) \d{4}', f'Copyright (c) {current_year}', content)
    
    LICENSE_TXT.write_text(content, encoding='utf-8', newline='\n')
    
    # Also update source LICENSE if year changed
    original = LICENSE_SRC.read_text(encoding='utf-8')
    if original != content:
        LICENSE_SRC.write_text(content, encoding='utf-8', newline='\n')
        print_info(f"Updated copyright year to {current_year}")


# ============================================================================
# FILE UTILITIES
# ============================================================================


def safe_extract_zip(zip_path: Path, dest_path: Path):
    """Safely extract a ZIP file, preventing path traversal attacks (zip slip).
    
    This function validates that all extracted files stay within the destination
    directory, preventing malicious archives from writing files outside the
    intended location.
    
    Args:
        zip_path: Path to the ZIP file to extract
        dest_path: Destination directory for extraction
    
    Raises:
        ValueError: If a path traversal attempt is detected
    """
    dest_path = dest_path.resolve()
    
    with zipfile.ZipFile(zip_path, 'r') as zip_file:
        for member in zip_file.namelist():
            # Compute the full path where the file would be extracted
            member_path = (dest_path / member).resolve()
            
            # Check that the path is within the destination directory
            try:
                member_path.relative_to(dest_path)
            except ValueError:
                raise ValueError(f"Path traversal detected in ZIP: {member}")
            
            # Extract the member
            zip_file.extract(member, dest_path)


def convert_to_unix_line_endings(file_path: Path):
    """Convert a file from Windows (CRLF) to Unix (LF) line endings."""
    try:
        content = file_path.read_bytes()
        if b'\r\n' in content:
            content = content.replace(b'\r\n', b'\n')
            file_path.write_bytes(content)
            return True
    except Exception as e:
        print_warn(f"Could not convert {file_path.name}: {e}")
    return False


class ApkBuilder:
    """Cross-platform ASUSTOR APK package builder."""
    
    APK_VERSION = '2.0'
    APK_CONTENTS = {
        'version': 'apkg-version',
        'data': 'data.tar.gz',
        'control': 'control.tar.gz'
    }
    # Required fields per ASUSTOR Developer Guide
    REQUIRED_FIELDS = ['package', 'name', 'version', 'developer', 'maintainer', 
                       'email', 'website', 'architecture', 'firmware']
    VALID_PACKAGE_PATTERN = re.compile(r'^[a-zA-Z0-9.+-]+$')
    VALID_VERSION_PATTERN = re.compile(r'^\d+(\.\d+){1,3}(\.r\d+)?$')  # X.Y.Z or X.Y.Z.rNNNN
    VALID_FIRMWARE_PATTERN = re.compile(r'^\d+\.\d+(\.\d+)?$')
    VALID_ARCHITECTURES = ['x86-64', 'arm64', 'any']  # Per ASUSTOR spec
    VALID_MODELS = ['11xx', '33xx', '52xx', '53xx', '54xx', '63xx', '64xx', 
                    '65xx', '66xx', '67xx', '68xx', '71xx', '72xx', '1axx', '3axx', '12xx']
    
    # Required control files (per ASUSTOR specification)
    REQUIRED_CONTROL_FILES = ['config.json', 'icon.png']
    
    # Optional but recommended control files
    OPTIONAL_CONTROL_FILES = [
        'start-stop.sh',  # Required for daemon apps
        'pre-install.sh', 'post-install.sh', 
        'pre-uninstall.sh', 'post-uninstall.sh',
        'pre-snapshot-restore.sh', 'post-snapshot-restore.sh',
        'changelog.txt', 'description.json', 'description.txt',
        'license.txt'
    ]
    
    # Icon requirements (per ASUSTOR specification)
    # APK package: MUST be 90x90 pixels
    # Developer Corner upload: 256x256 for better quality
    ICON_REQUIRED_SIZE = 90
    ICON_RECOMMENDED_SIZE = 256
    
    def __init__(self, source_dir: Path, verbose: bool = False):
        self.source_dir = source_dir.resolve()
        self.apk_dir = self.source_dir / 'apk'
        self.control_dir = self.apk_dir / 'CONTROL'
        self.config_file = self.control_dir / 'config.json'
        self.verbose = verbose
        
    def validate(self) -> bool:
        """Validate package structure and required files."""
        if not self.control_dir.is_dir():
            print_error(f"CONTROL folder not found: {self.control_dir}")
            return False
        
        # Check required control files
        for filename in self.REQUIRED_CONTROL_FILES:
            filepath = self.control_dir / filename
            if not filepath.is_file():
                print_error(f"Required file not found: CONTROL/{filename}")
                return False
        
        # Warn about missing optional files
        for filename in self.OPTIONAL_CONTROL_FILES:
            filepath = self.control_dir / filename
            if not filepath.is_file():
                if self.verbose:
                    print_warn(f"Optional file missing: CONTROL/{filename}")
        
        # Validate icon.png dimensions (ASUSTOR requires exactly 90x90 for APK)
        icon_path = self.control_dir / 'icon.png'
        if icon_path.is_file():
            width, height = self._get_png_dimensions(icon_path)
            if width and height:
                if width != height:
                    print_warn(f"Icon should be square: {width}x{height}")
                elif width != self.ICON_REQUIRED_SIZE:
                    if width == self.ICON_RECOMMENDED_SIZE:
                        print_warn(f"Icon is {width}x{height} (256x256 is for Developer Corner, APK requires 90x90)")
                    else:
                        print_warn(f"Icon size: {width}x{height} (ASUSTOR requires exactly 90x90 for APK package)")
                elif self.verbose:
                    print_info(f"Icon size: {width}x{height} ✓")
        
        # Validate shell scripts have proper shebang and Unix line endings
        for sh_file in self.control_dir.glob('*.sh'):
            if not self._has_valid_shebang(sh_file):
                print_warn(f"Script missing shebang: {sh_file.name}")
            if self._has_crlf_endings(sh_file):
                print_warn(f"Script has Windows line endings (CRLF): {sh_file.name} (will be converted)")
            
        return True
    
    def _get_png_dimensions(self, png_path: Path) -> tuple:
        """Read PNG dimensions from header."""
        try:
            with open(png_path, 'rb') as f:
                header = f.read(24)
                if header[:8] == b'\x89PNG\r\n\x1a\n':
                    width = struct.unpack('>I', header[16:20])[0]
                    height = struct.unpack('>I', header[20:24])[0]
                    return width, height
        except Exception:
            pass
        return None, None
    
    def _has_valid_shebang(self, script_path: Path) -> bool:
        """Check if script has a valid shebang line."""
        try:
            with open(script_path, 'rb') as f:
                first_line = f.readline()
                return first_line.startswith(b'#!')
        except Exception:
            return False
    
    def _has_crlf_endings(self, file_path: Path) -> bool:
        """Check if file has Windows CRLF line endings."""
        try:
            with open(file_path, 'rb') as f:
                content = f.read(4096)  # Check first 4KB
                return b'\r\n' in content
        except Exception:
            return False
    
    def validate_config(self, config: dict) -> bool:
        """Validate required fields in config.json (matches original apkg-tools)."""
        # Check required fields
        for field in self.REQUIRED_FIELDS:
            try:
                value = config['general'].get(field, '').strip()
                if not value:
                    print_error(f"Empty required field: {field}")
                    return False
            except (KeyError, AttributeError):
                print_error(f"Missing required field: {field}")
                return False
        
        # Validate package name format
        package_name = config['general']['package']
        if not self.VALID_PACKAGE_PATTERN.match(package_name):
            print_error(f"Invalid package name: {package_name} (valid characters: [a-zA-Z0-9.+-])")
            return False
        
        # Validate architecture
        architecture = config['general']['architecture']
        if architecture not in self.VALID_ARCHITECTURES:
            print_error(f"Invalid architecture: {architecture} (valid: {', '.join(self.VALID_ARCHITECTURES)})")
            return False
        
        # Validate version format (warning only)
        version = config['general']['version']
        if not self.VALID_VERSION_PATTERN.match(version):
            print_warn(f"Version '{version}' may not follow semantic versioning (X.Y.Z)")
        
        # Validate firmware format (warning only)
        firmware = config['general']['firmware']
        if not self.VALID_FIRMWARE_PATTERN.match(firmware):
            print_warn(f"Firmware '{firmware}' format may be invalid (expected: X.Y or X.Y.Z)")
        
        # Validate model if specified
        model = config['general'].get('model', [])
        if model:
            if isinstance(model, list):
                for m in model:
                    if m not in self.VALID_MODELS:
                        print_warn(f"Unknown model: {m} (valid: {', '.join(self.VALID_MODELS)})")
            elif self.verbose:
                print_info(f"Model filter: {model}")
        
        return True
    
    def get_config(self) -> dict:
        """Read and parse config.json."""
        with open(self.config_file, 'r', encoding='utf-8') as f:
            return json.load(f)
    
    def convert_line_endings(self):
        """Convert all shell and python scripts to Unix line endings."""
        print_info("Converting scripts to Unix line endings...")
        
        # Convert scripts in CONTROL (.sh and .py)
        for pattern in ['*.sh', '*.py']:
            for script_file in self.control_dir.glob(pattern):
                if convert_to_unix_line_endings(script_file):
                    print(f"{Colors.GRAY}   📄 {script_file.name}{Colors.RESET}")
        
        # Convert scripts in /scripts folder
        scripts_dir = self.source_dir / 'scripts'
        if scripts_dir.is_dir():
            for sh_file in scripts_dir.glob('*.sh'):
                if convert_to_unix_line_endings(sh_file):
                    print(f"{Colors.GRAY}   📄 scripts/{sh_file.name}{Colors.RESET}")
        
        print_success("Line endings converted")
    
    def create_tar_gz(self, tar_path: Path, source_path: Path, exclude_dirs: list = None):
        """Create a tar.gz archive with proper Unix permissions and ownership."""
        exclude_dirs = exclude_dirs or []
        
        with tarfile.open(tar_path, 'w:gz') as tar:
            for item in source_path.rglob('*'):
                # Skip excluded directories
                rel_path = item.relative_to(source_path)
                if any(part in exclude_dirs for part in rel_path.parts):
                    continue
                
                # Handle both files and directories
                if item.is_file() or item.is_dir():
                    # Create TarInfo with Unix-style path
                    arcname = './' + str(rel_path).replace('\\', '/')
                    
                    # Get file info
                    info = tar.gettarinfo(item, arcname=arcname)
                    
                    # Set Unix permissions based on file type
                    if item.is_dir():
                        info.mode = 0o755
                    elif item.suffix in ['.sh', '.py']:
                        info.mode = 0o755  # Executable scripts
                    else:
                        info.mode = 0o644  # Regular files
                    
                    # Set owner to root (uid=0, gid=0) - matches original apkg-tools
                    info.uid = 0
                    info.gid = 0
                    info.uname = 'root'
                    info.gname = 'root'
                    
                    if item.is_file():
                        with open(item, 'rb') as f:
                            tar.addfile(info, f)
                    else:
                        tar.addfile(info)  # Directory entry
    
    def _cleanup_old_releases(self, releases_dir: Path, package: str, arch: str, current_version: str):
        """Remove old release packages, keeping only the latest version."""
        # Pattern: package_version_arch.apk (exclude dev versions)
        pattern = f"{package}_*_{arch}.apk"
        
        for apk_file in releases_dir.glob(pattern):
            # Extract version from filename
            name = apk_file.stem  # io.runtipi_4.6.5_x86-64
            parts = name.split('_')
            if len(parts) >= 2:
                file_version = parts[1]
                # Skip dev builds (they're in a different folder anyway)
                if '.dev' in file_version:
                    continue
                # Remove if not the current version
                if file_version != current_version:
                    apk_file.unlink()
                    # Also remove checksum file
                    sha_file = apk_file.with_suffix('.apk.sha256')
                    if sha_file.exists():
                        sha_file.unlink()
                    print_info(f"Removed old release: {apk_file.name}")
    
    def _cleanup_old_dev_builds(self, dev_dir: Path, package: str, arch: str):
        """Remove old dev builds, keeping only the last MAX_DEV_BUILDS."""
        pattern = f"{package}_*.dev*_{arch}.apk"
        
        # Get all dev builds sorted by modification time (newest first)
        dev_builds = sorted(
            dev_dir.glob(pattern),
            key=lambda f: f.stat().st_mtime,
            reverse=True
        )
        
        # Remove builds beyond MAX_DEV_BUILDS
        for old_build in dev_builds[MAX_DEV_BUILDS:]:
            old_build.unlink()
            print_info(f"Removed old dev build: {old_build.name}")

    def build(self, destination: Path = None, version_override: str = None, is_dev_build: bool = False) -> Path:
        """Build the APK package.
        
        Args:
            destination: Output directory for the APK
            version_override: Override version (for dev builds - temporarily modifies config.json)
            is_dev_build: If True, skip checksum and use dev folder
        """
        # Validate structure
        if not self.validate():
            sys.exit(1)
        
        # Read and validate config
        config = self.get_config()
        if not self.validate_config(config):
            print_error("Invalid config.json - aborting build")
            sys.exit(1)
        
        package = config['general']['package']
        original_version = config['general']['version']
        version = version_override or original_version
        architecture = config['general']['architecture']
        
        # If version override, temporarily modify config.json
        config_backup = None
        if version_override:
            config_backup = self.config_file.read_text(encoding='utf-8')
            config['general']['version'] = version_override
            with open(self.config_file, 'w', encoding='utf-8') as f:
                json.dump(config, f, indent=4, ensure_ascii=False)
        
        print_info(f"Package: {package}")
        print_info(f"Version: {version}")
        print_info(f"Architecture: {architecture}")
        
        # Determine destination
        if destination is None:
            if is_dev_build:
                destination = DEV_RELEASES_DIR
            else:
                destination = RELEASES_DIR
        else:
            destination = Path(destination).resolve()
        
        # Ensure destination exists
        destination.mkdir(parents=True, exist_ok=True)
        
        apk_filename = f"{package}_{version}_{architecture}.apk"
        apk_path = destination / apk_filename
        
        # Create temp directory
        temp_dir = Path(tempfile.mkdtemp(prefix='APKG-'))
        print_info(f"Temp directory: {temp_dir}")
        
        try:
            # Generate changelog (fetch GitHub release notes + package notes)
            # Extract base version for GitHub API (remove .devN or .rN suffix)
            base_version = re.sub(r'\.[dr][ev]*\d+$', '', original_version)
            update_changelog(base_version, version, is_dev_build)
            
            # Copy license file
            copy_license()
            
            # Convert line endings
            self.convert_line_endings()
            
            # Create apkg-version
            version_file = temp_dir / self.APK_CONTENTS['version']
            version_file.write_text(f"{self.APK_VERSION}\n", encoding='utf-8', newline='\n')
            print_success("Created apkg-version")
            
            # Create control.tar.gz
            print_info("Creating control.tar.gz...")
            control_tar = temp_dir / self.APK_CONTENTS['control']
            self.create_tar_gz(control_tar, self.control_dir)
            print_success("Created control.tar.gz")
            
            # Create data.tar.gz (excluding CONTROL and bin directories)
            print_info("Creating data.tar.gz...")
            data_tar = temp_dir / self.APK_CONTENTS['data']
            self.create_tar_gz(data_tar, self.apk_dir, exclude_dirs=['CONTROL', 'bin'])
            print_success("Created data.tar.gz")
            
            # Create APK (ZIP format)
            print_info("Creating APK package...")
            
            # Remove existing APK if present
            if apk_path.exists():
                apk_path.unlink()
            
            with zipfile.ZipFile(apk_path, 'w', zipfile.ZIP_DEFLATED) as apk_zip:
                apk_zip.write(version_file, self.APK_CONTENTS['version'])
                apk_zip.write(control_tar, self.APK_CONTENTS['control'])
                apk_zip.write(data_tar, self.APK_CONTENTS['data'])
            
            # Calculate SHA256 checksum (skip for dev builds)
            checksum = None
            if not is_dev_build:
                sha256_hash = hashlib.sha256()
                with open(apk_path, 'rb') as f:
                    for chunk in iter(lambda: f.read(8192), b''):
                        sha256_hash.update(chunk)
                checksum = sha256_hash.hexdigest()
                
                # Write checksum file
                checksum_file = apk_path.with_suffix('.apk.sha256')
                checksum_file.write_text(f"{checksum}  {apk_path.name}", encoding='utf-8')
                
                # Cleanup old releases (keep only latest base/revision version)
                self._cleanup_old_releases(destination, package, architecture, version)
            else:
                # Cleanup old dev builds (keep only MAX_DEV_BUILDS)
                self._cleanup_old_dev_builds(destination, package, architecture)
            
            # Success!
            print()
            print(f"{Colors.GREEN}╔══════════════════════════════════════════════════════════════╗{Colors.RESET}")
            print(f"{Colors.GREEN}║                    BUILD SUCCESSFUL                          ║{Colors.RESET}")
            print(f"{Colors.GREEN}╚══════════════════════════════════════════════════════════════╝{Colors.RESET}")
            print()
            print_success(f"Package created: {apk_path}")
            print_info(f"Size: {apk_path.stat().st_size / 1024:.2f} KB")
            if checksum:
                print_info(f"SHA256: {checksum}")
            print()
            
            return apk_path
            
        except Exception as e:
            print_error(f"Build failed: {e}")
            raise
            
        finally:
            # Restore original config.json if we modified it (dev mode)
            if config_backup:
                self.config_file.write_text(config_backup, encoding='utf-8')
            
            # Cleanup temp directory
            shutil.rmtree(temp_dir, ignore_errors=True)


def list_apk_contents(apk_path: Path, verbose: bool = False):
    """List contents of an APK package."""
    print()
    print(f"{Colors.BLUE}╔══════════════════════════════════════════════════════════════╗{Colors.RESET}")
    print(f"{Colors.BLUE}║       ASUSTOR APK Contents                                   ║{Colors.RESET}")
    print(f"{Colors.BLUE}╚══════════════════════════════════════════════════════════════╝{Colors.RESET}")
    print()
    
    if not apk_path.is_file():
        print_error(f"APK file not found: {apk_path}")
        sys.exit(1)
    
    print_info(f"File: {apk_path.name}")
    print_info(f"Size: {apk_path.stat().st_size / 1024:.2f} KB")
    print()
    
    temp_dir = Path(tempfile.mkdtemp(prefix='APKG-List-'))
    
    try:
        safe_extract_zip(apk_path, temp_dir)
        
        # Read version
        version_file = temp_dir / 'apkg-version'
        if version_file.is_file():
            print_info(f"APK Version: {version_file.read_text().strip()}")
        
        # Read config
        control_tar = temp_dir / 'control.tar.gz'
        if control_tar.is_file():
            control_temp = temp_dir / 'CONTROL_temp'
            control_temp.mkdir()
            with tarfile.open(control_tar, 'r:gz') as tar:
                tar.extractall(control_temp, filter='data')
            
            for config_file in control_temp.rglob('config.json'):
                with open(config_file, 'r', encoding='utf-8') as f:
                    config = json.load(f)
                general = config.get('general', {})
                print_info(f"Package: {general.get('name', 'unknown')}")
                print_info(f"Version: {general.get('version', 'unknown')}")
                print_info(f"Architecture: {general.get('architecture', 'unknown')}")
                print_info(f"Firmware: {general.get('firmware', 'unknown')}")
                break
        
        print()
        print(f"{Colors.CYAN}📁 CONTROL files:{Colors.RESET}")
        if control_tar.is_file():
            with tarfile.open(control_tar, 'r:gz') as tar:
                for member in tar.getmembers():
                    if member.isfile():
                        size = f"{member.size:>8} B"
                        mode = f"{oct(member.mode)[2:]:>5}"
                        print(f"   {mode} {size}  {member.name}")
        
        print()
        print(f"{Colors.CYAN}📁 DATA files:{Colors.RESET}")
        data_tar = temp_dir / 'data.tar.gz'
        if data_tar.is_file():
            with tarfile.open(data_tar, 'r:gz') as tar:
                for member in tar.getmembers():
                    if member.isfile():
                        size = f"{member.size:>8} B" if verbose else ""
                        mode = f"{oct(member.mode)[2:]:>5}" if verbose else ""
                        if verbose:
                            print(f"   {mode} {size}  {member.name}")
                        else:
                            print(f"   {member.name}")
        
        print()
        
    finally:
        shutil.rmtree(temp_dir, ignore_errors=True)


def extract_apk(apk_path: Path, destination: Path = None, force: bool = False, verbose: bool = False):
    """Extract an APK package."""
    print()
    print(f"{Colors.BLUE}╔══════════════════════════════════════════════════════════════╗{Colors.RESET}")
    print(f"{Colors.BLUE}║       ASUSTOR APK Extractor - Cross-Platform                ║{Colors.RESET}")
    print(f"{Colors.BLUE}╚══════════════════════════════════════════════════════════════╝{Colors.RESET}")
    print()
    
    if not apk_path.is_file():
        print_error(f"APK file not found: {apk_path}")
        sys.exit(1)
    
    print_info(f"Extracting: {apk_path}")
    
    temp_dir = Path(tempfile.mkdtemp(prefix='APKG-Extract-'))
    
    try:
        # Extract ZIP (APK) safely
        safe_extract_zip(apk_path, temp_dir)
        
        # Verify APK format
        version_file = temp_dir / 'apkg-version'
        control_tar = temp_dir / 'control.tar.gz'
        data_tar = temp_dir / 'data.tar.gz'
        
        if not version_file.is_file() or not control_tar.is_file() or not data_tar.is_file():
            print_error("Invalid APK format: missing required files")
            sys.exit(1)
        
        apk_version = version_file.read_text().strip()
        print_info(f"APK Version: {apk_version}")
        
        # Extract control to read config.json
        control_temp = temp_dir / 'CONTROL_temp'
        control_temp.mkdir()
        with tarfile.open(control_tar, 'r:gz') as tar:
            tar.extractall(control_temp, filter='data')
        
        # Find config.json
        config_file = None
        for f in control_temp.rglob('config.json'):
            config_file = f
            break
        
        package_name = "unknown"
        package_version = "0.0.0"
        package_arch = "unknown"
        
        if config_file and config_file.is_file():
            with open(config_file, 'r', encoding='utf-8') as f:
                config = json.load(f)
            package_name = config['general'].get('name', 'unknown')
            package_version = config['general'].get('version', '0.0.0')
            package_arch = config['general'].get('architecture', 'unknown')
            print_info(f"Package: {package_name} v{package_version} ({package_arch})")
        
        # Destination folder
        if destination is None:
            destination = Path.cwd()
        
        output_dir = destination / f"{package_name}_{package_version}_{package_arch}"
        
        if output_dir.exists():
            if force:
                print_warn(f"Overwriting existing directory: {output_dir}")
                shutil.rmtree(output_dir)
            else:
                print_error(f"Destination already exists: {output_dir}")
                print_info("Use --force to overwrite")
                sys.exit(1)
        
        output_dir.mkdir(parents=True)
        
        # Extract data.tar.gz
        print_info("Extracting data...")
        with tarfile.open(data_tar, 'r:gz') as tar:
            tar.extractall(output_dir, filter='data')
        
        # Create CONTROL folder and extract control.tar.gz
        control_dir = output_dir / 'CONTROL'
        control_dir.mkdir()
        with tarfile.open(control_tar, 'r:gz') as tar:
            tar.extractall(control_dir, filter='data')
        
        print()
        print(f"{Colors.GREEN}╔══════════════════════════════════════════════════════════════╗{Colors.RESET}")
        print(f"{Colors.GREEN}║                  EXTRACTION SUCCESSFUL                       ║{Colors.RESET}")
        print(f"{Colors.GREEN}╚══════════════════════════════════════════════════════════════╝{Colors.RESET}")
        print()
        print_success(f"Extracted to: {output_dir}")
        print()
        
    finally:
        shutil.rmtree(temp_dir, ignore_errors=True)


def get_dev_build_number(package_version: str) -> int:
    """Get and increment the dev build counter. Resets if package version changes."""
    counter = 1
    stored_version = None
    
    if DEV_BUILD_COUNTER_FILE.exists():
        try:
            content = DEV_BUILD_COUNTER_FILE.read_text().strip()
            # Format: "version:counter" (e.g., "4.6.5:3" or "4.6.5.r2:1")
            if ':' in content:
                stored_version, stored_counter = content.split(':', 1)
                if stored_version == package_version:
                    counter = int(stored_counter) + 1
                else:
                    print_info(f"Package version changed ({stored_version} → {package_version}), resetting dev counter")
                    counter = 1
            else:
                # Legacy format: just a number - reset to be safe
                counter = 1
        except (ValueError, IOError):
            counter = 1
    
    DEV_BUILD_COUNTER_FILE.write_text(f"{package_version}:{counter}", encoding='utf-8')
    return counter


def main():
    Colors.enable()
    
    parser = argparse.ArgumentParser(
        description='ASUSTOR APK Builder/Extractor (cross-platform)',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python build.py                           Build APK to releases/
  python build.py --dev                     Build dev APK (auto-increment counter)
  python build.py -d /output                Build APK to custom folder
  python build.py --extract package.apk     Extract APK to current dir
  python build.py --extract pkg.apk -d /out Extract APK to custom folder
  python build.py --list package.apk        List APK contents
  python build.py --version                 Show version
"""
    )
    parser.add_argument(
        '--destination', '-d',
        help='Output directory for the APK file or extraction (default: releases/ for build)',
        default=None
    )
    parser.add_argument(
        '--dev',
        help='Dev build mode: uses local counter for version suffix (e.g., 4.6.5.dev1), does not modify config.json',
        action='store_true'
    )
    parser.add_argument(
        '--extract', '-x',
        help='Extract an APK file instead of building',
        metavar='APK_FILE',
        default=None
    )
    parser.add_argument(
        '--list', '-l',
        help='List contents of an APK file',
        metavar='APK_FILE',
        dest='list_apk',
        default=None
    )
    parser.add_argument(
        '--force', '-f',
        help='Overwrite existing destination when extracting',
        action='store_true'
    )
    parser.add_argument(
        '--verbose', '-v',
        help='Show verbose output',
        action='store_true'
    )
    parser.add_argument(
        '--version', '-V',
        help='Show version and exit',
        action='version',
        version=f'ASUSTOR APK Builder v{__version__}'
    )
    
    args = parser.parse_args()
    
    # List mode
    if args.list_apk:
        apk_path = Path(args.list_apk).resolve()
        list_apk_contents(apk_path, args.verbose)
        return
    
    # Extract mode
    if args.extract:
        apk_path = Path(args.extract).resolve()
        destination = Path(args.destination).resolve() if args.destination else None
        extract_apk(apk_path, destination, force=args.force, verbose=args.verbose)
        return
    
    # Build mode
    print()
    print(f"{Colors.BLUE}╔══════════════════════════════════════════════════════════════╗{Colors.RESET}")
    print(f"{Colors.BLUE}║     ASUSTOR APK Builder - Cross-Platform Edition v{__version__}      ║{Colors.RESET}")
    print(f"{Colors.BLUE}╚══════════════════════════════════════════════════════════════╝{Colors.RESET}")
    print()
    
    destination = Path(args.destination).resolve() if args.destination else None
    version_override = None
    
    # Dev mode: generate version with dev suffix
    if args.dev:
        builder = ApkBuilder(PROJECT_ROOT, verbose=args.verbose)
        config = builder.get_config()
        package_version = config['general']['version']  # e.g., "4.6.5" or "4.6.5.r2"
        dev_number = get_dev_build_number(package_version)
        version_override = f"{package_version}.dev{dev_number}"
        print_info(f"🔧 DEV MODE - Build #{dev_number}")
        print_info(f"   Package version: {package_version}")
        print_info(f"   Dev version:     {version_override}")
        print_info(f"   Output:          releases/dev/")
        print()
        builder.build(destination, version_override, is_dev_build=True)
    else:
        builder = ApkBuilder(PROJECT_ROOT, verbose=args.verbose)
        builder.build(destination)


if __name__ == '__main__':
    main()
