#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Runtipi Docker Images Manager

Extracts and manages Docker image versions used by Runtipi.
This script fetches the official image versions from the Runtipi CLI repository
docker-compose.yml file and updates the pre-install.sh script.

Docker images used by Runtipi:
- runtipi: Main application (ghcr.io/runtipi/runtipi)
- traefik: Reverse proxy
- postgres: Database
- rabbitmq: Message queue

Usage:
    python docker-images.py --show                 # Show current images
    python docker-images.py --fetch                # Fetch latest from GitHub
    python docker-images.py --update               # Update pre-install.sh
    python docker-images.py --update --version 4.6.5  # For specific Runtipi version

Sources:
    - Primary: https://github.com/runtipi/cli/blob/main/internal/assets/docker-compose.yml
    - Fallback: Runtipi release notes
"""

import sys
import argparse
import json
import re
import urllib.request
import urllib.error
from pathlib import Path
from typing import Optional, Dict

__version__ = '1.0.0'

# Paths
SCRIPT_DIR = Path(__file__).parent.resolve()
PROJECT_ROOT = SCRIPT_DIR.parent
CONFIG_FILE = PROJECT_ROOT / 'apk' / 'CONTROL' / 'config.json'
PRE_INSTALL_FILE = PROJECT_ROOT / 'apk' / 'CONTROL' / 'pre-install.sh'
IMAGES_CACHE_FILE = SCRIPT_DIR / '.docker-images-cache.json'

# GitHub API base
GITHUB_API = 'https://api.github.com'

# Runtipi CLI docker-compose.yml path (source of truth for Docker images)
RUNTIPI_CLI_OWNER = 'runtipi'
RUNTIPI_CLI_REPO = 'cli'
RUNTIPI_CLI_COMPOSE_PATH = 'internal/assets/docker-compose.yml'

# Fallback versions if CLI compose file is unavailable
DEFAULT_IMAGES = {
    'traefik': 'traefik:v3.6.7',
    'postgres': 'postgres:14',
    'rabbitmq': 'rabbitmq:4-alpine',
}


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
        if sys.platform == 'win32':
            try:
                import ctypes
                kernel32 = ctypes.windll.kernel32
                kernel32.SetConsoleMode(kernel32.GetStdHandle(-11), 7)
            except Exception:
                cls.RESET = cls.GREEN = cls.CYAN = cls.YELLOW = ''
                cls.RED = cls.BLUE = cls.GRAY = ''


def print_info(msg): print(f"{Colors.CYAN}🔹 {msg}{Colors.RESET}")
def print_success(msg): print(f"{Colors.GREEN}✅ {msg}{Colors.RESET}")
def print_warn(msg): print(f"{Colors.YELLOW}⚠️  {msg}{Colors.RESET}")
def print_error(msg): print(f"{Colors.RED}❌ {msg}{Colors.RESET}")


class DockerImagesManager:
    """Manages Docker image versions for Runtipi."""
    
    def __init__(self):
        self.cache_file = IMAGES_CACHE_FILE
        self.pre_install = PRE_INSTALL_FILE
        
    def get_runtipi_version(self) -> str:
        """Get Runtipi version from config.json."""
        with open(CONFIG_FILE, 'r', encoding='utf-8') as f:
            config = json.load(f)
        version = config['general']['version']
        # Remove revision suffix if present (4.6.5.r1 -> 4.6.5)
        return re.sub(r'\.r\d+$', '', version)
    
    def load_cache(self) -> Optional[Dict]:
        """Load cached image versions."""
        if self.cache_file.exists():
            try:
                with open(self.cache_file, 'r', encoding='utf-8') as f:
                    return json.load(f)
            except Exception:
                pass
        return None
    
    def save_cache(self, data: Dict):
        """Save image versions to cache."""
        with open(self.cache_file, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2)
    
    def fetch_from_github(self, runtipi_version: str) -> Dict[str, str]:
        """Fetch image versions from Runtipi CLI docker-compose.yml.
        
        Strategy:
        1. Try to fetch docker-compose.yml from runtipi/cli repository via GitHub API
        2. Parse the YAML to extract image versions
        3. Fall back to release notes if CLI compose not available
        4. Use defaults as last resort
        """
        images = DEFAULT_IMAGES.copy()
        
        # Try to fetch docker-compose.yml from CLI repository via GitHub API
        try:
            print_info(f"Fetching docker-compose.yml from Runtipi CLI...")
            
            api_url = f"{GITHUB_API}/repos/{RUNTIPI_CLI_OWNER}/{RUNTIPI_CLI_REPO}/contents/{RUNTIPI_CLI_COMPOSE_PATH}"
            req = urllib.request.Request(api_url, headers={
                'User-Agent': 'ASUSTOR-Runtipi-Builder/1.0',
                'Accept': 'application/vnd.github.raw+json'  # Get raw content directly
            })
            
            with urllib.request.urlopen(req, timeout=10) as response:
                compose_content = response.read().decode('utf-8')
                
                # Parse image versions from docker-compose.yml
                # Pattern: image: traefik:v3.6.1
                patterns = {
                    'traefik': r'^\s*image:\s*(traefik:[^\s]+)',
                    'postgres': r'^\s*image:\s*(postgres:[^\s]+)',
                    'rabbitmq': r'^\s*image:\s*(rabbitmq:[^\s]+)',
                }
                
                for key, pattern in patterns.items():
                    match = re.search(pattern, compose_content, re.MULTILINE)
                    if match:
                        images[key] = match.group(1)
                        print_info(f"  Found {key}: {images[key]}")
                
                print_success("docker-compose.yml parsed successfully")
                
        except urllib.error.HTTPError as e:
            print_warn(f"Could not fetch CLI docker-compose.yml: HTTP {e.code}")
            print_info("Falling back to release notes...")
            self._fetch_from_release_notes(runtipi_version, images)
        except Exception as e:
            print_warn(f"Could not fetch CLI docker-compose.yml: {e}")
            print_info("Using default versions")
        
        # Add Runtipi image itself
        images['runtipi'] = f"ghcr.io/runtipi/runtipi:v{runtipi_version}"
        
        return images
    
    def _fetch_from_release_notes(self, runtipi_version: str, images: Dict[str, str]):
        """Fallback: try to extract versions from release notes."""
        try:
            release_url = f"{GITHUB_API}/repos/runtipi/runtipi/releases/tags/v{runtipi_version}"
            print_info(f"Fetching release info for v{runtipi_version}...")
            
            req = urllib.request.Request(release_url, headers={
                'User-Agent': 'ASUSTOR-Runtipi-Builder/1.0',
                'Accept': 'application/vnd.github.v3+json'
            })
            
            with urllib.request.urlopen(req, timeout=10) as response:
                release = json.loads(response.read().decode('utf-8'))
                body = release.get('body', '')
                
                # Look for traefik version in release notes
                traefik_match = re.search(r'traefik[^\d]*v?(\d+\.\d+(?:\.\d+)?)', body, re.I)
                if traefik_match:
                    version = traefik_match.group(1)
                    images['traefik'] = f"traefik:v{version}"
                    print_info(f"  Found Traefik in release notes: v{version}")
                
        except Exception as e:
            print_warn(f"Could not fetch release notes: {e}")
    
    def get_current_images_from_script(self) -> Dict[str, str]:
        """Extract current image versions from pre-install.sh."""
        images = {}
        
        if not self.pre_install.exists():
            return images
        
        content = self.pre_install.read_text(encoding='utf-8')
        
        # Pattern to match: pull_image "image:tag" "Name"
        pattern = r'pull_image\s+"([^"]+)"\s+"([^"]+)"'
        
        for match in re.finditer(pattern, content):
            image = match.group(1)
            name = match.group(2).lower()
            
            # Map name to key
            if 'traefik' in name.lower():
                images['traefik'] = image
            elif 'postgres' in name.lower():
                images['postgres'] = image
            elif 'rabbit' in name.lower():
                images['rabbitmq'] = image
            elif 'runtipi' in name.lower():
                images['runtipi'] = image
        
        return images
    
    def update_pre_install_script(self, images: Dict[str, str], keep_runtipi_var: bool = True) -> bool:
        """Update pre-install.sh with new image versions.
        
        Args:
            images: Dictionary of image key to full image:tag string
            keep_runtipi_var: If True, keep ${APKG_PKG_VER} variable for Runtipi image
        """
        if not self.pre_install.exists():
            print_error(f"pre-install.sh not found: {self.pre_install}")
            return False
        
        content = self.pre_install.read_text(encoding='utf-8')
        original = content
        
        # Update each image in the pull_image calls
        replacements = [
            ('traefik', 'Traefik'),
            ('postgres', 'PostgreSQL'),
            ('rabbitmq', 'RabbitMQ'),
        ]
        
        # Only update Runtipi image if not keeping the variable
        if not keep_runtipi_var:
            replacements.append(('runtipi', 'Runtipi'))
        
        for key, name in replacements:
            if key not in images:
                continue
            
            # Pattern: pull_image "old_image" "Name"
            pattern = rf'(pull_image\s+")[^"]+("\s+"{name}")'
            replacement = rf'\g<1>{images[key]}\g<2>'
            content = re.sub(pattern, replacement, content, flags=re.IGNORECASE)
        
        if content != original:
            self.pre_install.write_text(content, encoding='utf-8')
            return True
        
        return False
    
    def generate_images_config(self, images: Dict[str, str]) -> str:
        """Generate a shell config snippet for Docker images."""
        lines = [
            "# Docker images for Runtipi",
            "# Auto-generated by docker-images.py",
            ""
        ]
        
        for key, image in sorted(images.items()):
            var_name = f"DOCKER_IMAGE_{key.upper()}"
            lines.append(f'{var_name}="{image}"')
        
        return '\n'.join(lines)


def main():
    Colors.enable()
    
    parser = argparse.ArgumentParser(
        description='Runtipi Docker Images Manager',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    python docker-images.py --show                    # Show current images
    python docker-images.py --fetch                   # Fetch from GitHub
    python docker-images.py --update                  # Update pre-install.sh
    python docker-images.py --update --version 4.7.0  # For specific version
"""
    )
    
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--show', action='store_true',
                      help='Show current image versions from pre-install.sh')
    group.add_argument('--fetch', action='store_true',
                      help='Fetch latest image versions from GitHub')
    group.add_argument('--update', action='store_true',
                      help='Update pre-install.sh with correct versions')
    group.add_argument('--generate', action='store_true',
                      help='Generate shell config for images')
    
    parser.add_argument('--version', '-v', metavar='VER',
                       help='Runtipi version to use (default: from config.json)')
    parser.add_argument('--quiet', '-q', action='store_true',
                       help='Minimal output')
    
    args = parser.parse_args()
    mgr = DockerImagesManager()
    
    try:
        # Get target version
        if args.version:
            version = args.version.lstrip('v')
        else:
            version = mgr.get_runtipi_version()
        
        if args.show:
            current = mgr.get_current_images_from_script()
            if args.quiet:
                for key, img in sorted(current.items()):
                    print(f"{key}={img}")
            else:
                print_info(f"Current images in pre-install.sh:")
                for key, img in sorted(current.items()):
                    print(f"  {Colors.CYAN}{key:12}{Colors.RESET}: {img}")
        
        elif args.fetch:
            if not args.quiet:
                print_info(f"Fetching images for Runtipi v{version}...")
            
            images = mgr.fetch_from_github(version)
            
            if not args.quiet:
                print_info("Fetched image versions:")
                for key, img in sorted(images.items()):
                    print(f"  {Colors.CYAN}{key:12}{Colors.RESET}: {img}")
            
            # Save to cache
            mgr.save_cache({
                'version': version,
                'images': images
            })
            
            if args.quiet:
                for key, img in sorted(images.items()):
                    print(f"{key}={img}")
            else:
                print_success(f"Saved to cache: {mgr.cache_file.name}")
        
        elif args.update:
            if not args.quiet:
                print_info(f"Updating images for Runtipi v{version}...")
            
            # Fetch or use cache
            cache = mgr.load_cache()
            if cache and cache.get('version') == version:
                images = cache['images']
                if not args.quiet:
                    print_info("Using cached image versions")
            else:
                images = mgr.fetch_from_github(version)
                mgr.save_cache({'version': version, 'images': images})
            
            # Show what we'll update
            if not args.quiet:
                current = mgr.get_current_images_from_script()
                print_info("Changes:")
                # Only show traefik, postgres, rabbitmq (not runtipi which uses variable)
                for key in ['traefik', 'postgres', 'rabbitmq']:
                    if key not in images:
                        continue
                    old = current.get(key, 'N/A')
                    new = images[key]
                    if old != new:
                        print(f"  {Colors.CYAN}{key:12}{Colors.RESET}: {old} → {Colors.GREEN}{new}{Colors.RESET}")
                    else:
                        print(f"  {Colors.GRAY}{key:12}: {new} (unchanged){Colors.RESET}")
                # Show runtipi separately
                print(f"  {Colors.GRAY}runtipi     : ghcr.io/runtipi/runtipi:v${{APKG_PKG_VER}} (dynamic){Colors.RESET}")
            
            # Update the script (keep Runtipi variable)
            if mgr.update_pre_install_script(images, keep_runtipi_var=True):
                if args.quiet:
                    print(f"updated")
                else:
                    print_success("pre-install.sh updated successfully")
            else:
                if args.quiet:
                    print("unchanged")
                else:
                    print_info("No changes needed in pre-install.sh")
        
        elif args.generate:
            cache = mgr.load_cache()
            if cache and cache.get('version') == version:
                images = cache['images']
            else:
                images = mgr.fetch_from_github(version)
            
            print(mgr.generate_images_config(images))
    
    except Exception as e:
        print_error(str(e))
        if not args.quiet:
            import traceback
            traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()
