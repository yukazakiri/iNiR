#!/usr/bin/env python3
"""Generate and refresh the iNiR Spicetify theme from Material You colors."""

from __future__ import annotations

import configparser
import json
import os
import subprocess
from pathlib import Path


COLOR_SOURCE = Path(
    os.environ.get(
        "QUICKSHELL_COLORS_JSON",
        "~/.local/state/quickshell/user/generated/colors.json",
    )
).expanduser()
THEME_NAME = os.environ.get("SPICETIFY_THEME_NAME", "ii-matugen")
COLOR_SCHEME = os.environ.get("SPICETIFY_COLOR_SCHEME", "matugen")

USER_CSS = """\
:root {
  --spice-main-elevated: var(--spice-main);
  --spice-highlight: var(--spice-main-secondary);
  --spice-highlight-elevated: var(--spice-main-secondary);
}

.main-topBar-background {
  background-image: linear-gradient(var(--spice-main) 0%, transparent 100%);
  background-color: unset !important;
}

.main-topBar-overlay {
  background-color: var(--spice-main);
}
"""


def _ensure_parent(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)


def _load_colors() -> dict[str, str]:
    if not COLOR_SOURCE.exists():
        raise FileNotFoundError(
            f"Material colors file not found: {COLOR_SOURCE}. "
            "Ensure switchwall.sh has been executed successfully."
        )

    with COLOR_SOURCE.open("r", encoding="utf-8") as fh:
        data = json.load(fh)
    return {k: v.lower().lstrip("#") for k, v in data.items()}


def _resolve_spicetify_dir() -> Path:
    explicit = os.environ.get("SPICETIFY_CONFIG_DIR")
    if explicit:
        return Path(explicit).expanduser()

    try:
        result = subprocess.run(
            ["spicetify", "-c"],
            capture_output=True,
            check=False,
            text=True,
        )
    except FileNotFoundError:
        return Path("~/.config/spicetify").expanduser()

    config_path = Path(result.stdout.strip()).expanduser()
    if config_path.name:
        return config_path.parent

    return Path("~/.config/spicetify").expanduser()


def _build_color_map(colors: dict[str, str]) -> dict[str, str]:
    return {
        "main": colors["surface"],
        "main-secondary": colors["surface_container_low"],
        "accent": colors["primary"],
        "button": colors["primary"],
        "button-secondary": colors["secondary_container"],
        "button-active": colors["primary_container"],
        "button-disabled": colors["surface_container_high"],
        "misc": colors["surface_variant"],
        "subtext": colors["on_surface_variant"],
        "text": colors["on_surface"],
        "sidebar": colors["surface"],
        "player": colors["surface"],
        "card": colors["surface_container_low"],
        "notification": colors["surface_container"],
        "notification-error": colors["error"],
        "shadow": "000000",
        "nav-active-text": colors["on_primary"],
        "nav-active": colors["primary"],
        "tab-active": colors["surface_container_highest"],
        "play-button": colors["primary"],
        "playback-bar": colors["primary_container"],
    }


def _write_theme(theme_dir: Path, color_map: dict[str, str]) -> None:
    _ensure_parent(theme_dir / "color.ini")

    lines = [f"[{COLOR_SCHEME}]"]
    for key, value in color_map.items():
        lines.append(f"{key:<18} = {value}")
    lines.append("")

    (theme_dir / "color.ini").write_text("\n".join(lines), encoding="utf-8")
    (theme_dir / "user.css").write_text(USER_CSS, encoding="utf-8")


def _read_active_theme(config_file: Path) -> tuple[str, str]:
    if not config_file.exists():
        return "", ""

    parser = configparser.ConfigParser(interpolation=None)
    parser.read(config_file, encoding="utf-8")
    current_theme = parser.get("Setting", "current_theme", fallback="")
    color_scheme = parser.get("Setting", "color_scheme", fallback="")
    return current_theme.strip(), color_scheme.strip()


def _run_spicetify(*args: str) -> bool:
    try:
        result = subprocess.run(
            ["spicetify", *args],
            capture_output=True,
            check=False,
            text=True,
        )
    except FileNotFoundError:
        return False

    if result.stdout.strip():
        print(result.stdout.strip())
    if result.stderr.strip():
        print(result.stderr.strip())
    return result.returncode == 0


def _refresh_if_active(spicetify_dir: Path) -> None:
    config_file = spicetify_dir / "config-xpui.ini"
    current_theme, color_scheme = _read_active_theme(config_file)

    if current_theme != THEME_NAME:
        print(
            f"Generated Spicetify theme at {spicetify_dir / 'Themes' / THEME_NAME}. "
            f"Activate it with: spicetify config current_theme {THEME_NAME} "
            f"color_scheme {COLOR_SCHEME} inject_css 1 replace_colors 1 && spicetify apply"
        )
        return

    if color_scheme != COLOR_SCHEME:
        _run_spicetify("config", "color_scheme", COLOR_SCHEME)

    _run_spicetify("refresh")


def main() -> None:
    try:
        colors = _load_colors()
    except FileNotFoundError as exc:
        print(f"Error: {exc}")
        return

    spicetify_dir = _resolve_spicetify_dir()
    theme_dir = spicetify_dir / "Themes" / THEME_NAME
    color_map = _build_color_map(colors)
    _write_theme(theme_dir, color_map)
    print(f"Generated: {theme_dir / 'color.ini'}")
    print(f"Generated: {theme_dir / 'user.css'}")
    _refresh_if_active(spicetify_dir)


if __name__ == "__main__":
    main()
