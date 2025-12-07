#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Unit tests for build.py"""

import sys
import unittest
from pathlib import Path
from unittest.mock import patch, MagicMock

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

try:
    import build
except ImportError as e:
    print(f"Warning: Could not import build: {e}")
    build = None


@unittest.skipIf(build is None, "build module not available")
class TestReleaseNotesParsing(unittest.TestCase):
    """Test GitHub release notes parsing."""

    def test_parse_empty_body(self):
        """Test parsing empty release notes."""
        result = build.parse_github_release_notes("")
        self.assertEqual(result['added'], [])
        self.assertEqual(result['fixed'], [])

    def test_parse_added_section(self):
        """Test parsing Added section."""
        body = """## What's new

### Added
- New feature one
- New feature two

### Fixed
- Bug fix one
"""
        result = build.parse_github_release_notes(body)
        self.assertIn("New feature one", result['added'])
        self.assertIn("Bug fix one", result['fixed'])

    def test_parse_conventional_format(self):
        """Test parsing conventional changelog format."""
        body = """## Changes

- feat: Added new feature
- fix: Fixed a bug
- improve: Better performance
"""
        result = build.parse_github_release_notes(body)
        # The parser should handle different formats
        self.assertIsInstance(result['added'], list)
        self.assertIsInstance(result['fixed'], list)


@unittest.skipIf(build is None, "build module not available")
class TestPackageNotes(unittest.TestCase):
    """Test package notes loading."""

    def test_load_package_notes_returns_dict(self):
        """Test that load_package_notes returns proper structure."""
        result = build.load_package_notes()
        self.assertIsInstance(result, dict)
        self.assertIn('current', result)
        self.assertIn('history', result)
        self.assertIsInstance(result['current'], list)
        self.assertIsInstance(result['history'], dict)


@unittest.skipIf(build is None, "build module not available")
class TestChangelogGeneration(unittest.TestCase):
    """Test changelog generation."""

    def test_generate_changelog_header(self):
        """Test changelog has proper header."""
        with patch.object(build, 'fetch_github_release_notes', return_value=''):
            result = build.generate_changelog("4.6.5")
            self.assertIn("Changelog", result)
            self.assertIn("4.6.5", result)

    def test_generate_dev_changelog(self):
        """Test dev changelog generation."""
        with patch.object(build, 'fetch_github_release_notes', return_value=''):
            result = build.generate_changelog("4.6.5", "4.6.5.dev1", is_dev=True)
            self.assertIn("Development Build", result)


@unittest.skipIf(build is None, "build module not available")
class TestFetchWithRetry(unittest.TestCase):
    """Test network fetch with retry."""

    @patch('build.urllib.request.urlopen')
    def test_successful_fetch(self, mock_urlopen):
        """Test successful URL fetch."""
        mock_response = MagicMock()
        mock_response.read.return_value = b'test data'
        mock_response.__enter__ = MagicMock(return_value=mock_response)
        mock_response.__exit__ = MagicMock(return_value=False)
        mock_urlopen.return_value = mock_response

        result = build.fetch_with_retry("http://example.com")
        self.assertEqual(result, b'test data')

    @patch('build.urllib.request.urlopen')
    def test_404_returns_none(self, mock_urlopen):
        """Test 404 error returns None without retry."""
        from urllib.error import HTTPError
        mock_urlopen.side_effect = HTTPError(
            url="http://example.com",
            code=404,
            msg="Not Found",
            hdrs={},
            fp=None
        )

        result = build.fetch_with_retry("http://example.com", max_retries=3)
        self.assertIsNone(result)
        # Should only be called once for 404
        self.assertEqual(mock_urlopen.call_count, 1)


@unittest.skipIf(build is None, "build module not available")
class TestLineEndingConversion(unittest.TestCase):
    """Test line ending conversion."""

    def test_convert_crlf_to_lf(self):
        """Test CRLF to LF conversion."""
        import tempfile
        import os

        # Create temp file with CRLF
        fd, path = tempfile.mkstemp()
        try:
            os.write(fd, b"line1\r\nline2\r\n")
            os.close(fd)

            result = build.convert_to_unix_line_endings(Path(path))
            self.assertTrue(result)

            # Verify content
            with open(path, 'rb') as f:
                content = f.read()
            self.assertNotIn(b'\r\n', content)
            self.assertIn(b'\n', content)
        finally:
            os.unlink(path)


if __name__ == '__main__':
    unittest.main()
