#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Unit tests for version-manager.py"""

import sys
import unittest
from pathlib import Path
from unittest.mock import patch, MagicMock

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

# Import after path modification
try:
    # Import the module using importlib to avoid naming issues
    import importlib.util
    spec = importlib.util.spec_from_file_location(
        "version_manager",
        Path(__file__).parent.parent / "version-manager.py"
    )
    version_manager = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(version_manager)
    VersionManager = version_manager.VersionManager
except Exception as e:
    print(f"Warning: Could not import version_manager: {e}")
    VersionManager = None


@unittest.skipIf(VersionManager is None, "VersionManager not available")
class TestVersionParsing(unittest.TestCase):
    """Test version string parsing."""

    def setUp(self):
        self.vm = VersionManager()

    def test_parse_base_version(self):
        """Test parsing base version without revision."""
        base, rev = self.vm.parse_version("4.6.5")
        self.assertEqual(base, "4.6.5")
        self.assertIsNone(rev)

    def test_parse_version_with_revision(self):
        """Test parsing version with revision."""
        base, rev = self.vm.parse_version("4.6.5.r1")
        self.assertEqual(base, "4.6.5")
        self.assertEqual(rev, 1)

        base, rev = self.vm.parse_version("4.6.5.r10")
        self.assertEqual(base, "4.6.5")
        self.assertEqual(rev, 10)

    def test_parse_invalid_version(self):
        """Test parsing invalid version raises error."""
        with self.assertRaises(ValueError):
            self.vm.parse_version("invalid")

        with self.assertRaises(ValueError):
            self.vm.parse_version("4.6")

        with self.assertRaises(ValueError):
            self.vm.parse_version("4.6.5.dev3")


class TestVersionFormatting(unittest.TestCase):
    """Test version string formatting."""

    def setUp(self):
        self.vm = VersionManager()

    def test_format_base_version(self):
        """Test formatting version without revision."""
        result = self.vm.format_version("4.6.5", None)
        self.assertEqual(result, "4.6.5")

        result = self.vm.format_version("4.6.5", 0)
        self.assertEqual(result, "4.6.5")

    def test_format_version_with_revision(self):
        """Test formatting version with revision."""
        result = self.vm.format_version("4.6.5", 1)
        self.assertEqual(result, "4.6.5.r1")

        result = self.vm.format_version("4.6.5", 5)
        self.assertEqual(result, "4.6.5.r5")


class TestVersionSorting(unittest.TestCase):
    """Test version tag sorting."""

    def setUp(self):
        self.vm = VersionManager()

    def test_version_sort_key(self):
        """Test version sort key generation."""
        key1 = self.vm._version_sort_key("v4.6.5")
        key2 = self.vm._version_sort_key("v4.6.5.r1")
        key3 = self.vm._version_sort_key("v4.6.6")

        self.assertLess(key1, key2)
        self.assertLess(key2, key3)


if __name__ == '__main__':
    unittest.main()
