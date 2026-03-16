#!/usr/bin/env python3
"""
Go-backed terminal config generator.

This wrapper preserves the previous Python entrypoint while delegating
generation to the Go implementation for faster execution.
"""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
GO_SOURCE = SCRIPT_DIR / "generate_terminal_configs.go"
CACHE_DIR = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "inir"
GO_BINARY = CACHE_DIR / "generate_terminal_configs"


def _build_go_binary() -> Path:
    if not GO_SOURCE.exists():
        raise FileNotFoundError(f"Missing Go source: {GO_SOURCE}")

    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    needs_build = (not GO_BINARY.exists()) or GO_BINARY.stat().st_mtime < GO_SOURCE.stat().st_mtime
    if needs_build:
        subprocess.run(
            ["go", "build", "-o", str(GO_BINARY), str(GO_SOURCE)],
            check=True,
        )
    return GO_BINARY


def main() -> None:
    binary = _build_go_binary()
    subprocess.run([str(binary), *sys.argv[1:]], check=True)


if __name__ == "__main__":
    main()
