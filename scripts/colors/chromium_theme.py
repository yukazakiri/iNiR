#!/usr/bin/env python3
"""
Chromium/Chrome theme manager with support for:
- Preferences-based theming (google-chrome-stable, google-chrome-beta)
- GM3 CLI switches (omarchy-chromium-bin, which installs as 'chromium')

No sudo required for normal operation. Policy files are optional and only
written during setup if sudo access is available.
"""

import sys
import os
import re
import json
import subprocess
import shutil
from pathlib import Path
from typing import Optional, Dict, List, Tuple, Any
from copy import deepcopy

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
        "config_dir": ".config/chromium",
        "profile": "Default",
        "policy_dir": "/etc/chromium/policies/managed",
        "policy_file": "theme.json",
        "type": "auto",
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
}


def detect_browser_type(binary: str) -> str:
    """Detect if a browser supports GM3 CLI switches or uses preferences."""
    if binary == "chromium":
        try:
            result = subprocess.run(
                ["pacman", "-Qi", "chromium"], capture_output=True, text=True, timeout=2
            )
            if result.returncode == 0 and "omarchy-chromium" in result.stdout:
                return "gm3"
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pass

        try:
            result = subprocess.run(
                ["dpkg", "-s", "chromium"], capture_output=True, text=True, timeout=2
            )
            if result.returncode == 0 and "omarchy" in result.stdout.lower():
                return "gm3"
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pass

    try:
        result = subprocess.run(
            ["rpm", "-qi", binary], capture_output=True, text=True, timeout=2
        )
        if result.returncode == 0 and "omarchy" in result.stdout.lower():
            return "gm3"
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass

    return "preferences"


def get_browser_config(browser_name: str) -> Optional[Dict[str, Any]]:
    """Get browser config with auto-detected type."""
    base_config = BROWSER_REGISTRY.get(browser_name)
    if not base_config:
        return None

    config: Dict[str, Any] = {}
    config.update(base_config)

    if config["type"] == "auto":
        config["type"] = detect_browser_type(config["binary"])
        if config["type"] == "gm3":
            config["gm3_flags"] = GM3_FLAGS
            config["no_window_flag"] = "--no-startup-window"

    return config


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
    config = get_browser_config(browser_name)
    if not config or config.get("type") != "preferences":
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


def set_system_color_scheme(darkmode: bool) -> bool:
    """Set system color-scheme via gsettings (affects Chrome's theme detection)."""
    scheme = "prefer-dark" if darkmode else "prefer-light"

    try:
        result = subprocess.run(
            ["gsettings", "set", "org.gnome.desktop.interface", "color-scheme", scheme],
            capture_output=True,
            timeout=2,
        )
        if result.returncode == 0:
            print(f"[chromium-theme] Set system color-scheme to {scheme}")
            return True
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass

    return False


def apply_preferences_theme(
    browser_name: str, colors: Dict[str, str], darkmode: bool
) -> bool:
    """Apply theme by modifying Chrome's Preferences file."""
    config = get_browser_config(browser_name)
    if not config or config.get("type") != "preferences":
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


def apply_gm3_theme(browser_name: str, colors: Dict[str, str], darkmode: bool) -> bool:
    """Apply theme via GM3 CLI switches (omarchy-chromium-bin)."""
    config = get_browser_config(browser_name)
    if not config or config.get("type") != "gm3":
        return False

    binary = config["binary"]
    flags: Dict[str, str] = config.get("gm3_flags", GM3_FLAGS)
    no_window = config.get("no_window_flag", "--no-startup-window")

    primary = colors.get("primary", "#458588")
    r, g, b = hex_to_rgb(primary)
    color_scheme = "dark" if darkmode else "light"

    commands = [
        [binary, no_window, f"{flags['user_color']}={r},{g},{b}"],
        [binary, no_window, f"{flags['color_scheme']}={color_scheme}"],
    ]

    success = True
    for cmd in commands:
        try:
            result = subprocess.run(cmd, capture_output=True, timeout=3)
            if result.returncode != 0:
                print(
                    f"[chromium-theme] GM3 command returned {result.returncode}: {' '.join(cmd)}",
                    file=sys.stderr,
                )
        except FileNotFoundError:
            print(f"[chromium-theme] GM3 binary not found: {binary}", file=sys.stderr)
            success = False
        except subprocess.TimeoutExpired:
            print(
                f"[chromium-theme] GM3 command timed out: {' '.join(cmd)}",
                file=sys.stderr,
            )
            success = False
        except Exception as e:
            print(f"[chromium-theme] GM3 command failed: {e}", file=sys.stderr)
            success = False

    if success:
        print(f"[chromium-theme] GM3 theme applied to {browser_name}")
    return success


def apply_browser_theme(
    browser_name: str, colors: Dict[str, str], darkmode: bool
) -> bool:
    """Apply theme to a specific browser."""
    config = get_browser_config(browser_name)
    if not config:
        print(f"[chromium-theme] Unknown browser: {browser_name}", file=sys.stderr)
        return False

    browser_type = config.get("type", "preferences")

    if browser_type == "preferences":
        return apply_preferences_theme(browser_name, colors, darkmode)
    elif browser_type == "gm3":
        return apply_gm3_theme(browser_name, colors, darkmode)

    return False


def apply_all_browsers(
    scss_path: str, enabled_browsers: Optional[List[str]] = None
) -> Dict[str, bool]:
    """Apply theme to all or specified browsers."""
    results = {}

    colors = parse_scss_colors(scss_path)
    if not colors:
        return results

    darkmode = get_darkmode(scss_path)

    set_system_color_scheme(darkmode)

    if enabled_browsers is None:
        enabled_browsers = get_installed_browsers()

    for browser in enabled_browsers:
        if is_browser_installed(browser):
            results[browser] = apply_browser_theme(browser, colors, darkmode)
        else:
            print(f"[chromium-theme] Skipping {browser} (not installed)")
            results[browser] = False

    return results


def setup_policies(scss_path: Optional[str] = None) -> bool:
    """Setup policy files for all installed browsers (requires sudo)."""
    if scss_path:
        colors = parse_scss_colors(scss_path)
        darkmode = get_darkmode(scss_path)
    else:
        colors = {}
        darkmode = True

    primary = colors.get("primary", "#458588")
    policy_data = {"BrowserThemeColor": primary}
    policy_json = json.dumps(policy_data, indent=2)

    success = False
    for browser_name, config in BROWSER_REGISTRY.items():
        if config["type"] != "preferences":
            continue

        if not is_browser_installed(browser_name):
            continue

        policy_dir = Path(config["policy_dir"])
        policy_file = policy_dir / config["policy_file"]

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
            success = True
            continue

        if shutil.which("sudo"):
            result = subprocess.run(
                ["sudo", "mkdir", "-p", str(policy_dir)],
                capture_output=True,
            )
            if result.returncode == 0:
                result = subprocess.run(
                    ["sudo", "tee", str(policy_file)],
                    input=policy_json,
                    capture_output=True,
                    text=True,
                )
                if result.returncode == 0:
                    print(
                        f"[chromium-theme] Policy written to {policy_file} (via sudo)"
                    )
                    success = True
                    continue

        print(f"[chromium-theme] Skipped policy for {browser_name} (no write access)")

    return success


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
        "--setup-policies",
        action="store_true",
        help="Setup policy files (requires sudo)",
    )

    args = parser.parse_args()

    if args.list:
        print("Installed browsers:")
        for browser in get_installed_browsers():
            config = get_browser_config(browser)
            if config:
                print(f"  - {browser} ({config.get('type', 'unknown')})")
        return

    if args.setup_policies:
        if not args.scss:
            print("[chromium-theme] Setting up policies without theme colors")
        setup_policies(args.scss)
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
