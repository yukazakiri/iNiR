#!/usr/bin/env python3
"""Generate iNiR-compatible theme contracts from Aether output."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

try:
    import tomllib
except ModuleNotFoundError:  # pragma: no cover
    import tomli as tomllib


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate colors from Aether output")
    parser.add_argument("--path", required=True, help="Wallpaper/image path")
    parser.add_argument("--mode", choices=["dark", "light"], default="dark")
    parser.add_argument("--extract-mode", default="normal")
    parser.add_argument(
        "--aether-output",
        default=os.path.expanduser("~/.config/aether/themes/inir-auto"),
    )
    parser.add_argument("--json-output")
    parser.add_argument("--palette-output")
    parser.add_argument("--terminal-output")
    parser.add_argument("--meta-output")
    parser.add_argument("--scss-output")
    parser.add_argument("--chromium-output")
    parser.add_argument("--cache")
    return parser.parse_args()


def hex_to_rgb(value: str) -> tuple[int, int, int]:
    value = value.lstrip("#")
    return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4))


def rgb_to_hex(rgb: tuple[int, int, int]) -> str:
    return "#{:02X}{:02X}{:02X}".format(*rgb)


def blend(color1: str, color2: str, amount: float) -> str:
    amount = max(0.0, min(1.0, amount))
    r1, g1, b1 = hex_to_rgb(color1)
    r2, g2, b2 = hex_to_rgb(color2)
    return rgb_to_hex(
        (
            round(r1 + (r2 - r1) * amount),
            round(g1 + (g2 - g1) * amount),
            round(b1 + (b2 - b1) * amount),
        )
    )


def relative_luminance(color: str) -> float:
    def channel(value: int) -> float:
        component = value / 255.0
        if component <= 0.03928:
            return component / 12.92
        return ((component + 0.055) / 1.055) ** 2.4

    r, g, b = hex_to_rgb(color)
    return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)


def contrast_ratio(color1: str, color2: str) -> float:
    lum1 = relative_luminance(color1)
    lum2 = relative_luminance(color2)
    lighter = max(lum1, lum2)
    darker = min(lum1, lum2)
    return (lighter + 0.05) / (darker + 0.05)


def pick_readable(background: str, candidates: list[str]) -> str:
    return max(candidates, key=lambda candidate: contrast_ratio(background, candidate))


def subdued(foreground: str, background: str, amount: float = 0.28) -> str:
    return blend(foreground, background, amount)


def run_aether(args: argparse.Namespace) -> None:
    output_dir = Path(args.aether_output).expanduser()
    output_dir.mkdir(parents=True, exist_ok=True)
    command = [
        "aether",
        "--generate",
        str(Path(args.path).expanduser()),
        "--extract-mode",
        args.extract_mode,
        "--no-apply",
        "--output",
        str(output_dir),
    ]
    if args.mode == "light":
        command.append("--light-mode")

    completed = subprocess.run(command, capture_output=True, text=True)
    if completed.returncode != 0:
        sys.stderr.write(completed.stderr or completed.stdout)
        raise SystemExit(completed.returncode)


def load_aether_colors(output_dir: str) -> dict[str, str]:
    colors_path = Path(output_dir).expanduser() / "colors.toml"
    with colors_path.open("rb") as handle:
        data = tomllib.load(handle)
    return {key: value.upper() for key, value in data.items() if isinstance(value, str)}


def build_terminal_contract(colors: dict[str, str]) -> dict[str, str]:
    return {f"term{i}": colors[f"color{i}"] for i in range(16)}


def build_palette(term: dict[str, str], darkmode: bool, accent: str, foreground: str, background: str) -> dict[str, str]:
    primary = accent
    secondary = term.get("term6", term.get("term2", primary))
    tertiary = term.get("term5", term.get("term3", secondary))
    error = term.get("term1", "#B00020")
    success = term.get("term2", secondary)

    container_strength = 0.22 if darkmode else 0.12
    fixed_strength = 0.30 if darkmode else 0.18

    primary_container = blend(background, primary, container_strength)
    secondary_container = blend(background, secondary, container_strength - 0.02)
    tertiary_container = blend(background, tertiary, container_strength)
    error_container = blend(background, error, container_strength)
    success_container = blend(background, success, container_strength - 0.02)

    primary_fixed = blend(background, primary, fixed_strength)
    primary_fixed_dim = blend(background, primary, fixed_strength - 0.06)
    secondary_fixed = blend(background, secondary, fixed_strength - 0.02)
    secondary_fixed_dim = blend(background, secondary, fixed_strength - 0.08)
    tertiary_fixed = blend(background, tertiary, fixed_strength)
    tertiary_fixed_dim = blend(background, tertiary, fixed_strength - 0.06)

    surface = blend(background, foreground, 0.02)
    surface_dim = blend(background, foreground, 0.04)
    surface_bright = blend(background, foreground, 0.08)
    surface_variant = blend(background, foreground, 0.14)
    surface_container_lowest = blend(background, foreground, 0.01)
    surface_container_low = blend(background, foreground, 0.04)
    surface_container = blend(background, foreground, 0.07)
    surface_container_high = blend(background, foreground, 0.10)
    surface_container_highest = blend(background, foreground, 0.13)
    outline = blend(background, foreground, 0.35)
    outline_variant = blend(background, foreground, 0.22)

    def on_color(base: str) -> str:
        return pick_readable(base, [background, foreground, term.get("term15", foreground), term.get("term0", background)])

    def on_container(base: str) -> str:
        return pick_readable(base, [foreground, background, term.get("term15", foreground), term.get("term0", background)])

    palette = {
        "primary": primary,
        "onPrimary": on_color(primary),
        "primaryContainer": primary_container,
        "onPrimaryContainer": on_container(primary_container),
        "primaryFixed": primary_fixed,
        "primaryFixedDim": primary_fixed_dim,
        "onPrimaryFixed": on_container(primary_fixed),
        "onPrimaryFixedVariant": subdued(on_container(primary_fixed), primary_fixed, 0.35),
        "secondary": secondary,
        "onSecondary": on_color(secondary),
        "secondaryContainer": secondary_container,
        "onSecondaryContainer": on_container(secondary_container),
        "secondaryFixed": secondary_fixed,
        "secondaryFixedDim": secondary_fixed_dim,
        "onSecondaryFixed": on_container(secondary_fixed),
        "onSecondaryFixedVariant": subdued(on_container(secondary_fixed), secondary_fixed, 0.35),
        "tertiary": tertiary,
        "onTertiary": on_color(tertiary),
        "tertiaryContainer": tertiary_container,
        "onTertiaryContainer": on_container(tertiary_container),
        "tertiaryFixed": tertiary_fixed,
        "tertiaryFixedDim": tertiary_fixed_dim,
        "onTertiaryFixed": on_container(tertiary_fixed),
        "onTertiaryFixedVariant": subdued(on_container(tertiary_fixed), tertiary_fixed, 0.35),
        "error": error,
        "onError": on_color(error),
        "errorContainer": error_container,
        "onErrorContainer": on_container(error_container),
        "background": background,
        "onBackground": foreground,
        "surface": surface,
        "onSurface": foreground,
        "surfaceDim": surface_dim,
        "surfaceBright": surface_bright,
        "surfaceVariant": surface_variant,
        "onSurfaceVariant": subdued(foreground, background, 0.28),
        "surfaceContainerLowest": surface_container_lowest,
        "surfaceContainerLow": surface_container_low,
        "surfaceContainer": surface_container,
        "surfaceContainerHigh": surface_container_high,
        "surfaceContainerHighest": surface_container_highest,
        "outline": outline,
        "outlineVariant": outline_variant,
        "inverseSurface": foreground,
        "inverseOnSurface": background,
        "inversePrimary": blend(primary, foreground if darkmode else background, 0.25),
        "shadow": "#000000",
        "scrim": "#000000",
        "surfaceTint": primary,
        "success": success,
        "onSuccess": on_color(success),
        "successContainer": success_container,
        "onSuccessContainer": on_container(success_container),
        "primaryPaletteKeyColor": primary,
    }
    return palette


def palette_to_contract(palette: dict[str, str]) -> dict[str, str]:
    return {
        "primary": palette["primary"],
        "on_primary": palette["onPrimary"],
        "primary_container": palette["primaryContainer"],
        "on_primary_container": palette["onPrimaryContainer"],
        "primary_fixed": palette["primaryFixed"],
        "primary_fixed_dim": palette["primaryFixedDim"],
        "on_primary_fixed": palette["onPrimaryFixed"],
        "on_primary_fixed_variant": palette["onPrimaryFixedVariant"],
        "secondary": palette["secondary"],
        "on_secondary": palette["onSecondary"],
        "secondary_container": palette["secondaryContainer"],
        "on_secondary_container": palette["onSecondaryContainer"],
        "secondary_fixed": palette["secondaryFixed"],
        "secondary_fixed_dim": palette["secondaryFixedDim"],
        "on_secondary_fixed": palette["onSecondaryFixed"],
        "on_secondary_fixed_variant": palette["onSecondaryFixedVariant"],
        "tertiary": palette["tertiary"],
        "on_tertiary": palette["onTertiary"],
        "tertiary_container": palette["tertiaryContainer"],
        "on_tertiary_container": palette["onTertiaryContainer"],
        "tertiary_fixed": palette["tertiaryFixed"],
        "tertiary_fixed_dim": palette["tertiaryFixedDim"],
        "on_tertiary_fixed": palette["onTertiaryFixed"],
        "on_tertiary_fixed_variant": palette["onTertiaryFixedVariant"],
        "error": palette["error"],
        "on_error": palette["onError"],
        "error_container": palette["errorContainer"],
        "on_error_container": palette["onErrorContainer"],
        "background": palette["background"],
        "on_background": palette["onBackground"],
        "surface": palette["surface"],
        "on_surface": palette["onSurface"],
        "surface_dim": palette["surfaceDim"],
        "surface_bright": palette["surfaceBright"],
        "surface_variant": palette["surfaceVariant"],
        "on_surface_variant": palette["onSurfaceVariant"],
        "surface_container_lowest": palette["surfaceContainerLowest"],
        "surface_container_low": palette["surfaceContainerLow"],
        "surface_container": palette["surfaceContainer"],
        "surface_container_high": palette["surfaceContainerHigh"],
        "surface_container_highest": palette["surfaceContainerHighest"],
        "outline": palette["outline"],
        "outline_variant": palette["outlineVariant"],
        "inverse_surface": palette["inverseSurface"],
        "inverse_on_surface": palette["inverseOnSurface"],
        "inverse_primary": palette["inversePrimary"],
        "shadow": palette["shadow"],
        "scrim": palette["scrim"],
        "surface_tint": palette["surfaceTint"],
        "success": palette["success"],
        "on_success": palette["onSuccess"],
        "success_container": palette["successContainer"],
        "on_success_container": palette["onSuccessContainer"],
    }


def write_json(path: str | None, payload: dict) -> None:
    if not path:
        return
    destination = Path(path).expanduser()
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(payload, indent=2) + "\n")


def write_text(path: str | None, content: str) -> None:
    if not path:
        return
    destination = Path(path).expanduser()
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(content)


def build_scss(palette: dict[str, str], terminal: dict[str, str], darkmode: bool) -> str:
    ordered_keys = [
        "background",
        "onBackground",
        "surface",
        "surfaceDim",
        "surfaceBright",
        "surfaceContainerLowest",
        "surfaceContainerLow",
        "surfaceContainer",
        "surfaceContainerHigh",
        "surfaceContainerHighest",
        "surfaceVariant",
        "onSurface",
        "onSurfaceVariant",
        "primary",
        "onPrimary",
        "primaryContainer",
        "onPrimaryContainer",
        "primaryFixed",
        "primaryFixedDim",
        "onPrimaryFixed",
        "onPrimaryFixedVariant",
        "secondary",
        "onSecondary",
        "secondaryContainer",
        "onSecondaryContainer",
        "secondaryFixed",
        "secondaryFixedDim",
        "onSecondaryFixed",
        "onSecondaryFixedVariant",
        "tertiary",
        "onTertiary",
        "tertiaryContainer",
        "onTertiaryContainer",
        "tertiaryFixed",
        "tertiaryFixedDim",
        "onTertiaryFixed",
        "onTertiaryFixedVariant",
        "error",
        "onError",
        "errorContainer",
        "onErrorContainer",
        "outline",
        "outlineVariant",
        "inverseSurface",
        "inverseOnSurface",
        "inversePrimary",
        "shadow",
        "scrim",
        "surfaceTint",
        "success",
        "onSuccess",
        "successContainer",
        "onSuccessContainer",
        "primaryPaletteKeyColor",
    ]
    lines = [
        f"$darkmode: {'true' if darkmode else 'false'};",
        "$transparent: false;",
    ]
    for key in ordered_keys:
        if key in palette:
            lines.append(f"${key}: {palette[key]};")
    for idx in range(16):
        lines.append(f"$term{idx}: {terminal[f'term{idx}']};")
    return "\n".join(lines) + "\n"


def main() -> None:
    args = parse_args()
    run_aether(args)

    colors = load_aether_colors(args.aether_output)
    darkmode = args.mode == "dark"
    background = colors["background"]
    foreground = colors["foreground"]
    accent = colors.get("accent", colors.get("color4", foreground))
    terminal = build_terminal_contract(colors)
    palette = build_palette(terminal, darkmode, accent, foreground, background)
    palette_contract = palette_to_contract(palette)
    colors_contract = dict(palette_contract)
    colors_contract.update(terminal)
    colors_contract["darkmode"] = darkmode
    colors_contract["transparent"] = False

    if args.cache:
        write_text(args.cache, accent + "\n")

    write_json(args.json_output, colors_contract)
    write_json(args.palette_output, palette_contract)
    write_json(args.terminal_output, terminal)
    write_json(
        args.meta_output,
        {
            "source": "image",
            "source_path": str(Path(args.path).expanduser()),
            "seed_color": accent,
            "mode": args.mode,
            "scheme": args.extract_mode,
            "transparent": False,
            "generator": "aether",
            "generated_by": "generate_colors_aether.py",
            "aether_output": str(Path(args.aether_output).expanduser()),
        },
    )
    write_text(args.scss_output, build_scss(palette, terminal, darkmode))

    if args.chromium_output:
        chromium_path = Path(args.aether_output).expanduser() / "chromium.theme"
        if chromium_path.exists():
            write_text(args.chromium_output, chromium_path.read_text().strip() + "\n")
        else:
            r, g, b = hex_to_rgb(background)
            write_text(args.chromium_output, f"{r},{g},{b}\n")


if __name__ == "__main__":
    main()
