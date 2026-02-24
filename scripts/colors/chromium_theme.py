#!/usr/bin/env python3
"""
Chromium theme manager using GM3-compliant CLI switches.

Applies Material You themes to Chromium without opening new windows:
  chromium --no-startup-window --set-user-color="R,G,B"
  chromium --no-startup-window --set-color-scheme="dark|light"
  chromium --no-startup-window --set-color-variant="vibrant"
  chromium --no-startup-window --set-grayscale-theme="true|false"
  chromium --no-startup-window --set-default-theme

No sudo required. No preferences file manipulation.
"""

import sys
import re
import subprocess
import shutil
from pathlib import Path
from typing import Dict, List, Optional, Tuple

GM3_FLAGS = {
    "user_color": "--set-user-color",
    "color_scheme": "--set-color-scheme",
    "color_variant": "--set-color-variant",
    "grayscale": "--set-grayscale-theme",
    "default": "--set-default-theme",
}

BROWSER_REGISTRY = {
    "chromium": {
        "binary": "chromium",
    },
    "brave": {
        "binary": "brave",
    },
}


def parse_scss_colors(scss_path: str) -> Dict[str, str]:
    """Parse material_colors.scss and extract color variables."""
    colors = {}
    try:
        with open(scss_path, "r") as f:
            for line in f:
                match = re.match(r"\$(\w+):\s*(#[A-Fa-f0-9]{6});", line.strip())
                if match:
                    name, value = match.groups()
                    colors[name] = value
    except FileNotFoundError:
        print(f"[chromium-theme] Error: Could not find {scss_path}", file=sys.stderr)
        return {}
    return colors


def hex_to_rgb(hex_color: str) -> Tuple[int, int, int]:
    """Convert hex color to RGB tuple."""
    hex_color = hex_color.lstrip("#")
    r = int(hex_color[0:2], 16)
    g = int(hex_color[2:4], 16)
    b = int(hex_color[4:6], 16)
    return (r, g, b)


def get_darkmode(scss_path: str) -> bool:
    """Extract darkmode setting from SCSS file."""
    try:
        with open(scss_path, "r") as f:
            for line in f:
                match = re.match(r"\$darkmode:\s*(True|False);", line.strip())
                if match:
                    return match.group(1) == "True"
    except FileNotFoundError:
        pass
    return True


def is_browser_installed(browser_name: str) -> bool:
    """Check if a browser binary is installed."""
    config = BROWSER_REGISTRY.get(browser_name)
    if not config:
        return False
    return shutil.which(config["binary"]) is not None


def get_installed_browsers() -> List[str]:
    """Get list of installed Chromium browsers."""
    return [name for name in BROWSER_REGISTRY if is_browser_installed(name)]


def apply_gm3_theme(browser_name: str, colors: Dict[str, str], darkmode: bool) -> bool:
    config = BROWSER_REGISTRY.get(browser_name)
    if not config:
        print(f"[chromium-theme] Unknown browser: {browser_name}", file=sys.stderr)
        return False

    binary = config["binary"]

    seed_color = colors.get("primary_paletteKeyColor", colors.get("primary", "#458588"))
    r, g, b = hex_to_rgb(seed_color)
    color_scheme = "dark" if darkmode else "light"

    # Single invocation with all flags to avoid race conditions
    cmd = [
        binary,
        "--no-startup-window",
        f"{GM3_FLAGS['user_color']}={r},{g},{b}",
        f"{GM3_FLAGS['color_scheme']}={color_scheme}",
    ]

    try:
        result = subprocess.run(cmd, capture_output=True, timeout=5)
        if result.returncode != 0:
            print(
                f"[chromium-theme] GM3 command returned {result.returncode}: {' '.join(cmd)}",
                file=sys.stderr,
            )
            return False
    except FileNotFoundError:
        print(f"[chromium-theme] Binary not found: {binary}", file=sys.stderr)
        return False
    except subprocess.TimeoutExpired:
        print(f"[chromium-theme] Command timed out: {' '.join(cmd)}", file=sys.stderr)
        return False
    except Exception as e:
        print(f"[chromium-theme] Command failed: {e}", file=sys.stderr)
        return False

    print(f"[chromium-theme] GM3 theme applied to {browser_name}")
    return True


def apply_all_browsers(
    scss_path: str, enabled_browsers: Optional[List[str]] = None
) -> Dict[str, bool]:
    """Apply theme to all or specified browsers."""
    results: Dict[str, bool] = {}

    colors = parse_scss_colors(scss_path)
    if not colors:
        return results

    darkmode = get_darkmode(scss_path)

    if enabled_browsers is None:
        enabled_browsers = get_installed_browsers()

    for browser in enabled_browsers:
        if is_browser_installed(browser):
            results[browser] = apply_gm3_theme(browser, colors, darkmode)
        else:
            print(f"[chromium-theme] Skipping {browser} (not installed)")
            results[browser] = False

    return results


def main():
    import argparse

    parser = argparse.ArgumentParser(description="Chromium GM3 theme manager")
    parser.add_argument("--scss", help="Path to material_colors.scss")
    parser.add_argument(
        "--browsers",
        nargs="*",
        help="Specific browsers to theme (default: all installed)",
    )
    parser.add_argument("--list", action="store_true", help="List installed browsers")

    args = parser.parse_args()

    if args.list:
        print("Installed browsers:")
        for browser in get_installed_browsers():
            print(f"  - {browser}")
        return

    if not args.scss:
        print(
            "[chromium-theme] Error: --scss is required for theme application",
            file=sys.stderr,
        )
        parser.print_help()
        sys.exit(1)

    if not Path(args.scss).exists():
        print(
            f"[chromium-theme] Error: SCSS file not found: {args.scss}", file=sys.stderr
        )
        sys.exit(1)

    results = apply_all_browsers(args.scss, args.browsers)

    success_count = sum(1 for v in results.values() if v)
    print(f"[chromium-theme] Applied to {success_count}/{len(results)} browsers")


if __name__ == "__main__":
    main()
