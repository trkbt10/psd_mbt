#!/usr/bin/env python3
"""Verify PSD fixture files using psd-tools.

Usage:
    uv run --with psd-tools python scripts/verify.py validate [fixtures/...]
    uv run --with psd-tools python scripts/verify.py validate  # validates all fixtures
"""

import sys
from pathlib import Path


def validate_file(filepath: Path) -> bool:
    """Validate a single PSD file using psd-tools."""
    from psd_tools import PSDImage

    try:
        psd = PSDImage.open(filepath)
        print(f"  OK: {filepath}")
        print(f"      Size: {psd.width}x{psd.height}, Channels: {psd.channels}")
        print(f"      Color Mode: {psd.color_mode}, Depth: {psd.depth}")
        return True
    except Exception as e:
        print(f"  FAIL: {filepath}")
        print(f"        {e}")
        return False


def validate(paths: list[str]) -> int:
    """Validate PSD files."""
    fixtures_dir = Path(__file__).parent.parent / "fixtures"

    if not paths:
        # Validate all .psd and .psb files in fixtures/
        files = sorted(fixtures_dir.glob("*.psd")) + sorted(fixtures_dir.glob("*.psb"))
        if not files:
            print("No .psd files found in fixtures/")
            return 1
    else:
        files = [Path(p) for p in paths]

    print(f"Validating {len(files)} file(s)...")
    results = [validate_file(f) for f in files]

    passed = sum(results)
    failed = len(results) - passed
    print(f"\nResults: {passed} passed, {failed} failed")
    return 0 if failed == 0 else 1


def main():
    if len(sys.argv) < 2:
        print("Usage: python scripts/verify.py validate [files...]")
        sys.exit(1)

    command = sys.argv[1]
    if command == "validate":
        sys.exit(validate(sys.argv[2:]))
    else:
        print(f"Unknown command: {command}")
        sys.exit(1)


if __name__ == "__main__":
    main()
