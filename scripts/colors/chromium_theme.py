#!/usr/bin/env python3
"""
Chromium/Chrome theme manager with support for:
- Preferences-based theming (chromium, google-chrome-stable, google-chrome-beta)
- GM3 CLI switches (omarchy-chromium-bin)

For regular Chromium/Chrome:
- Modifies Preferences file to set user color and color scheme
- Uses --force-dark-mode flag approach via preferences

For omarchy-chromium-bin:
- Uses GM3 CLI switches for runtime theme updates
"""

import sys
import os
import re
import json
import subprocess
import shutil
import time
import struct
from pathlib import Path
from typing import Optional, Dict, List, Tuple
from copy import deepcopy

BROWSER_REGISTRY = {
    "chromium": {
        "binary": "chromium",
        "config_dir": ".config/chromium",
        "profile": "Default",
        "policy_dir": "/etc/chromium/policies/managed",
        "policy_file": "theme.json",
        "type": "preferences",
    },
    "google-chrome-stable": {
        "binary": "google-chrome-stable",
        "config_dir": ".config/google-chrome",
        "profile": "Default",
        "policy_dir": "/etc/opt/chrome/policies/managed",
        "policy_file": "theme.json",
        "type": "preferences",
    },
    "google-chrome-beta": {
        "binary": "google-chrome-beta",
        "config_dir": ".config/google-chrome-beta",
        "profile": "Default",
        "policy_dir": "/etc/opt/chrome/policies/managed",
        "policy_file": "theme.json",
        "type": "preferences",
    },
    "google-chrome-unstable": {
        "binary": "google-chrome-unstable",
        "config_dir": ".config/google-chrome-unstable",
        "profile": "Default",
        "policy_dir": "/etc/opt/chrome/policies/managed",
        "policy_file": "theme.json",
        "type": "preferences",
    },
    "omarchy-chromium-bin": {
        "binary": "omarchy-chromium-bin",
        "type": "gm3",
        "gm3_flags": {
            "user_color": "--set-user-color",
            "color_scheme": "--set-color-scheme",
            "color_variant": "--set-color-variant",
            "grayscale": "--set-grayscale-theme",
            "default": "--set-default-theme",
        },
        "no_window_flag": "--no-startup-window",
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


def hex_to_chrome_color(hex_color: str) -> int:
    """Convert hex color to Chrome's signed 32-bit ARGB integer format."""
    r, g, b = hex_to_rgb(hex_color)
    argb = (0xFF << 24) | (r << 16) | (g << 8) | b
    if argb >= 0x80000000:
        argb -= 0x100000000
    return argb


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
    """Get list of installed Chrome/Chromium variants."""
    return [name for name in BROWSER_REGISTRY if is_browser_installed(name)]


def get_browser_profile_path(browser_name: str) -> Optional[Path]:
    """Get the path to the browser's profile directory."""
    config = BROWSER_REGISTRY.get(browser_name)
    if not config or config["type"] != "preferences":
        return None

    config_dir = Path.home() / config["config_dir"]

    if config_dir.exists():
        profile_dir = config_dir / config["profile"]
        if profile_dir.exists():
            return profile_dir

    return None


def read_preferences(prefs_path: Path) -> Optional[Dict]:
    """Read and parse Chrome's Preferences file."""
    if not prefs_path.exists():
        return None

    try:
        with open(prefs_path, "r") as f:
            return json.load(f)
    except (json.JSONDecodeError, IOError) as e:
        print(f"[chromium-theme] Error reading preferences: {e}", file=sys.stderr)
        return None


def write_preferences(prefs_path: Path, prefs: Dict) -> bool:
    """Write Chrome's Preferences file."""
    try:
        prefs_path.parent.mkdir(parents=True, exist_ok=True)

        with open(prefs_path, "w") as f:
            json.dump(prefs, f, indent=2)

        return True
    except IOError as e:
        print(f"[chromium-theme] Error writing preferences: {e}", file=sys.stderr)
        return False


def apply_preferences_theme(
    browser_name: str, colors: Dict[str, str], darkmode: bool
) -> bool:
    """Apply theme by modifying Chrome's Preferences file."""
    config = BROWSER_REGISTRY.get(browser_name)
    if not config or config["type"] != "preferences":
        return False

    profile_path = get_browser_profile_path(browser_name)
    if not profile_path:
        print(f"[chromium-theme] No profile found for {browser_name}", file=sys.stderr)
        return False

    prefs_path = profile_path / "Preferences"

    prefs = read_preferences(prefs_path)
    if prefs is None:
        prefs = {}

    original_prefs = deepcopy(prefs)

    primary = colors.get("primary", "#458588")
    background = colors.get("background", "#282828")
    surface = colors.get("surface", "#282828")
    on_surface = colors.get("onSurface", "#ebdbb2")

    chrome_color = hex_to_chrome_color(primary)
    bg_color = hex_to_chrome_color(background)
    frame_color = hex_to_chrome_color(surface)
    text_color = hex_to_chrome_color(on_surface)

    if "browser" not in prefs:
        prefs["browser"] = {}
    if "theme" not in prefs["browser"]:
        prefs["browser"]["theme"] = {}

    prefs["browser"]["theme"]["user_color2"] = chrome_color

    if "extensions" not in prefs:
        prefs["extensions"] = {}
    if "theme" not in prefs["extensions"]:
        prefs["extensions"]["theme"] = {}

    prefs["extensions"]["theme"]["id"] = "autogenerated_theme_id"
    prefs["extensions"]["theme"]["system_theme"] = 0 if not darkmode else 1

    if "properties" not in prefs["extensions"]["theme"]:
        prefs["extensions"]["theme"]["properties"] = {}

    prefs["extensions"]["theme"]["properties"] = {
        "ntp_background": bg_color,
        "ntp_text": text_color,
        "frame": frame_color,
        "frame_inactive": frame_color,
        "toolbar": bg_color,
        "bookmark_text": text_color,
        "tab_text": text_color,
        "tab_background_text": text_color,
    }

    if prefs != original_prefs:
        if not write_preferences(prefs_path, prefs):
            return False
        print(f"[chromium-theme] Updated Preferences for {browser_name}")
    else:
        print(f"[chromium-theme] No changes needed for {browser_name}")

    return True


def signal_browser_reload(browser_name: str, profile_path: Path) -> bool:
    """Signal browser to reload preferences."""
    prefs_path = profile_path / "Preferences"

    try:
        prefs_path.touch()
    except OSError:
        pass

    config = BROWSER_REGISTRY.get(browser_name)
    if not config:
        return False

    binary = config["binary"]

    try:
        result = subprocess.run(
            [binary, "--refresh-platform-policy", "--no-startup-window"],
            capture_output=True,
            timeout=3,
        )
        print(f"[chromium-theme] Signaled refresh for {browser_name}")
        return True
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
        pass

    return True


def apply_policy_theme(
    browser_name: str, colors: Dict[str, str], darkmode: bool
) -> bool:
    """Apply theme via managed policy (enterprise policy, requires sudo)."""
    config = BROWSER_REGISTRY.get(browser_name)
    if not config:
        return False

    policy_dir = Path(config.get("policy_dir", ""))
    policy_file = policy_dir / config.get("policy_file", "theme.json")

    primary = colors.get("primary", "#458588")

    policy_data = {
        "BrowserThemeColor": primary,
    }
    policy_json = json.dumps(policy_data, indent=2)

    def try_write(path: Path, data: str) -> bool:
        try:
            path.parent.mkdir(parents=True, exist_ok=True)
            with open(path, "w") as f:
                f.write(data)
            return True
        except (PermissionError, OSError):
            return False

    if try_write(policy_file, policy_json):
        print(f"[chromium-theme] Policy written to {policy_file}")
        return True

    for tool in ["sudo", "pkexec"]:
        result = subprocess.run(
            [
                "sh",
                "-c",
                f"mkdir -p '{policy_dir}' 2>/dev/null; {tool} tee '{policy_file}'",
            ],
            input=policy_json,
            capture_output=True,
            text=True,
        )
        if result.returncode == 0:
            print(f"[chromium-theme] Policy written to {policy_file} (via {tool})")
            return True

    print(
        f"[chromium-theme] Skipped policy for {browser_name} (no sudo access)",
        file=sys.stderr,
    )
    return True


def apply_gm3_theme(browser_name: str, colors: Dict[str, str], darkmode: bool) -> bool:
    """Apply theme via GM3 CLI switches (omarchy-chromium-bin)."""
    config = BROWSER_REGISTRY.get(browser_name)
    if not config or config["type"] != "gm3":
        return False

    binary = config["binary"]
    flags = config["gm3_flags"]
    no_window = config["no_window_flag"]

    primary = colors.get("primary", "#458588")
    r, g, b = hex_to_rgb(primary)
    color_scheme = "dark" if darkmode else "light"

    commands = [
        [binary, no_window, f'{flags["user_color"]}="{r},{g},{b}"'],
        [binary, no_window, f'{flags["color_scheme"]}="{color_scheme}"'],
    ]

    success = True
    for cmd in commands:
        try:
            subprocess.run(cmd, capture_output=True, timeout=3)
        except Exception as e:
            print(
                f"[chromium-theme] GM3 command failed: {' '.join(cmd)}", file=sys.stderr
            )
            success = False

    if success:
        print(f"[chromium-theme] GM3 theme applied to {browser_name}")
    return success


def apply_browser_theme(browser_name: str, scss_path: str) -> bool:
    """Apply theme to a specific browser."""
    config = BROWSER_REGISTRY.get(browser_name)
    if not config:
        print(f"[chromium-theme] Unknown browser: {browser_name}", file=sys.stderr)
        return False

    colors = parse_scss_colors(scss_path)
    if not colors:
        return False

    darkmode = get_darkmode(scss_path)

    browser_type = config["type"]

    if browser_type == "preferences":
        prefs_success = apply_preferences_theme(browser_name, colors, darkmode)
        policy_success = apply_policy_theme(browser_name, colors, darkmode)
        profile_path = get_browser_profile_path(browser_name)
        if policy_success and profile_path:
            signal_browser_reload(browser_name, profile_path)
        return prefs_success
    elif browser_type == "gm3":
        return apply_gm3_theme(browser_name, colors, darkmode)

    return False


def apply_all_browsers(
    scss_path: str, enabled_browsers: Optional[List[str]] = None
) -> Dict[str, bool]:
    """Apply theme to all or specified browsers."""
    results = {}

    if enabled_browsers is None:
        enabled_browsers = get_installed_browsers()

    for browser in enabled_browsers:
        if is_browser_installed(browser):
            results[browser] = apply_browser_theme(browser, scss_path)
        else:
            print(f"[chromium-theme] Skipping {browser} (not installed)")
            results[browser] = False

    return results


def main():
    import argparse

    parser = argparse.ArgumentParser(description="Chromium/Chrome theme manager")
    parser.add_argument("--scss", help="Path to material_colors.scss")
    parser.add_argument(
        "--browsers",
        nargs="*",
        help="Specific browsers to theme (default: all installed)",
    )
    parser.add_argument("--list", action="store_true", help="List installed browsers")
    parser.add_argument(
        "--check-prefs", action="store_true", help="Check browser preferences status"
    )

    args = parser.parse_args()

    if args.list:
        print("Installed browsers:")
        for browser in get_installed_browsers():
            config = BROWSER_REGISTRY[browser]
            print(f"  - {browser} ({config['type']})")
        return

    if args.check_prefs:
        for browser, config in BROWSER_REGISTRY.items():
            if config["type"] == "preferences":
                profile_path = get_browser_profile_path(browser)
                if profile_path:
                    prefs_path = profile_path / "Preferences"
                    exists = prefs_path.exists()
                    print(
                        f"  {browser}: {prefs_path} {'exists' if exists else 'missing'}"
                    )
                else:
                    print(f"  {browser}: no profile found")
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
