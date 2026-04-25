#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
docs_dir="$repo_root/docs"
wiki_dir="$repo_root/wiki"

mkdir -p "$wiki_dir"

find "$wiki_dir" -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} +

cp "$docs_dir/index.md" "$wiki_dir/Home.md"

while IFS= read -r src; do
  base="$(basename "$src")"
  cp "$src" "$wiki_dir/$base"
done < <(find "$docs_dir" -maxdepth 1 -type f -name '*.md' ! -name 'index.md' | sort)

cat > "$wiki_dir/_Sidebar.md" <<'EOF'
## Getting Started

- [Home](Home)
- [Installation](INSTALL)
- [Setup and Update](SETUP)
- [Packages](PACKAGES)
- [Keybinds](KEYBINDS)
- [IPC Reference](IPC)

## Architecture

- [Architecture Overview](ARCHITECTURE_OVERVIEW)
- [Project Map](PROJECT_MAP)
- [Panel Families](PANEL_FAMILIES)
- [Modules](MODULES)
- [Services](SERVICES)
- [Runtime](RUNTIME)
- [Config System](CONFIG_SYSTEM)

## Features

- [Calendar](CALENDAR)
- [Wallpaper](WALLPAPER)
- [Audio and Media](AUDIO_MEDIA)
- [Notifications](NOTIFICATIONS)
- [Autostart](AUTOSTART)
- [Compositors](COMPOSITORS)

## Theming

- [Theming Architecture](THEMING_ARCHITECTURE)
- [Theming Modules](THEMING_MODULES)
- [Theming Targets](THEMING_TARGETS)
- [Theming Presets](THEMING_PRESETS)
- [Vesktop Theme](VESKTOP)

## Reference

- [Global Actions](GLOBAL_ACTIONS)
- [Limitations](LIMITATIONS)
- [Optimization](OPTIMIZATION)
EOF

cat > "$wiki_dir/_Footer.md" <<'EOF'
---

[Repository](https://github.com/snowarch/iNiR) • [Releases](https://github.com/snowarch/iNiR/releases) • [Issue Tracker](https://github.com/snowarch/iNiR/issues)
EOF

printf 'GitHub Wiki snapshot updated in %s\n' "$wiki_dir"
