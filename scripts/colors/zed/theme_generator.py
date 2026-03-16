#!/usr/bin/env python3
"""
Go-backed Zed theme generator.

This wrapper preserves the previous Python import surface while delegating
all generation work to the Go implementation for faster execution.
"""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
GO_SOURCE = SCRIPT_DIR / "theme_generator.go"
CACHE_DIR = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "inir"
GO_BINARY = CACHE_DIR / "zed_theme_generator"


def _build_go_binary() -> Path:
    if not GO_SOURCE.exists():
        raise FileNotFoundError(f"Missing Go source: {GO_SOURCE}")

    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    needs_build = (
        not GO_BINARY.exists()
    ) or GO_BINARY.stat().st_mtime < GO_SOURCE.stat().st_mtime
    if needs_build:
        subprocess.run(
            ["go", "build", "-o", str(GO_BINARY), str(GO_SOURCE)],
            check=True,
        )
    return GO_BINARY


def generate_zed_config(_colors, scss_path: str, output_path: str) -> None:
    """Generate Zed editor theme using the Go implementation."""
    binary = _build_go_binary()
    subprocess.run(
        [str(binary), "--scss", scss_path, "--out", output_path],
        check=True,
    )


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: theme_generator.py <scss_path> <output_path>", file=sys.stderr)
        sys.exit(2)
    generate_zed_config({}, sys.argv[1], sys.argv[2])
