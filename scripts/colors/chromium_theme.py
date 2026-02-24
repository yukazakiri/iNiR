#!/usr/bin/env python3
"""
Chromium-based browser theme manager.

Two theming strategies:
- Chromium (omarchy): GM3 CLI switches (no window, instant)
- Brave: BrowserThemeColor policy file + --refresh-platform-policy

Policy dirs must be writable (setup once with sudo chmod a+rw):
  /etc/brave/policies/managed
"""

import sys
import re
import json
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
        "type": "gm3",
    },
    "brave": {
        "binary": "brave",
        "type": "policy",
        "policy_dir": "/etc/brave/policies/managed",
        "policy_file": "theme.json",
    },
    "google-chrome-stable": {
        "binary": "google-chrome-stable",
        "type": "policy",
        "policy_dir": "/etc/opt/chrome/policies/managed",
        "policy_file": "theme.json",
    },
    "google-chrome-beta": {
        "binary": "google-chrome-beta",
        "type": "policy",
        "policy_dir": "/etc/opt/chrome/policies/managed",
        "policy_file": "theme.json",
    },
}


def parse_scss_colors(scss_path: str) -> Dict[str, str]:
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
    hex_color = hex_color.lstrip("#")
    r = int(hex_color[0:2], 16)
    g = int(hex_color[2:4], 16)
    b = int(hex_color[4:6], 16)
    return (r, g, b)


def get_darkmode(scss_path: str) -> bool:
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
    config = BROWSER_REGISTRY.get(browser_name)
    if not config:
        return False
    return shutil.which(config["binary"]) is not None


def get_installed_browsers() -> List[str]:
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


def apply_policy_theme(
    browser_name: str, colors: Dict[str, str], darkmode: bool
) -> bool:
    config = BROWSER_REGISTRY.get(browser_name)
    if not config:
        print(f"[chromium-theme] Unknown browser: {browser_name}", file=sys.stderr)
        return False

    binary = config["binary"]
    policy_dir = Path(config["policy_dir"])
    policy_file = policy_dir / config["policy_file"]

    seed_color = colors.get("primary_paletteKeyColor", colors.get("primary", "#458588"))

    policy_data = {"BrowserThemeColor": seed_color}

    try:
        policy_dir.mkdir(parents=True, exist_ok=True)
        with open(policy_file, "w") as f:
            json.dump(policy_data, f, indent=2)
    except (PermissionError, OSError) as e:
        print(
            f"[chromium-theme] Cannot write policy to {policy_file}: {e}\n"
            f"[chromium-theme] Fix with: sudo mkdir -p {policy_dir} && sudo chmod a+rw {policy_dir}",
            file=sys.stderr,
        )
        return False

    print(f"[chromium-theme] Policy written to {policy_file}")

    cmd = [binary, "--no-startup-window", "--refresh-platform-policy"]

    try:
        result = subprocess.run(cmd, capture_output=True, timeout=5)
        if result.returncode != 0:
            print(
                f"[chromium-theme] Policy refresh returned {result.returncode}: {' '.join(cmd)}",
                file=sys.stderr,
            )
    except FileNotFoundError:
        print(f"[chromium-theme] Binary not found: {binary}", file=sys.stderr)
        return False
    except subprocess.TimeoutExpired:
        # --refresh-platform-policy may not exit cleanly if browser isn't running; policy file is still written
        print(
            f"[chromium-theme] Policy refresh timed out (policy file written, will apply on next launch)"
        )
    except Exception as e:
        print(f"[chromium-theme] Policy refresh failed: {e}", file=sys.stderr)
        return False

    print(f"[chromium-theme] Policy theme applied to {browser_name}")
    return True


def apply_browser_theme(
    browser_name: str, colors: Dict[str, str], darkmode: bool
) -> bool:
    config = BROWSER_REGISTRY.get(browser_name)
    if not config:
        print(f"[chromium-theme] Unknown browser: {browser_name}", file=sys.stderr)
        return False

    browser_type = config.get("type", "gm3")

    if browser_type == "gm3":
        return apply_gm3_theme(browser_name, colors, darkmode)
    elif browser_type == "policy":
        return apply_policy_theme(browser_name, colors, darkmode)

    return False


def apply_all_browsers(
    scss_path: str, enabled_browsers: Optional[List[str]] = None
) -> Dict[str, bool]:
    results: Dict[str, bool] = {}

    colors = parse_scss_colors(scss_path)
    if not colors:
        return results

    darkmode = get_darkmode(scss_path)

    if enabled_browsers is None:
        enabled_browsers = get_installed_browsers()

    for browser in enabled_browsers:
        if is_browser_installed(browser):
            results[browser] = apply_browser_theme(browser, colors, darkmode)
        else:
            print(f"[chromium-theme] Skipping {browser} (not installed)")
            results[browser] = False

    return results


def main():
    import argparse

    parser = argparse.ArgumentParser(description="Chromium/Brave theme manager")
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
            btype = BROWSER_REGISTRY[browser]["type"]
            print(f"  - {browser} ({btype})")
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
