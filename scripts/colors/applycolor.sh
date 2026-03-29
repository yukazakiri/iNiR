#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/module-runtime.sh"

# If applycolor.sh is invoked with switchwall-style args, forward to switchwall.sh.
# This lets users run: applycolor.sh --image /path/to/wallpaper
for arg in "$@"; do
  case "$arg" in
    --image|--noswitch|--mode|--type|--color|--monitor|--start-workspace|--end-workspace|--skip-config-write)
      exec "$SCRIPT_DIR/switchwall.sh" "$@"
      ;;
  esac
done

term_alpha=100 #Set this to < 100 make all your terminals transparent
# sleep 0 # idk i wanted some delay or colors dont get applied properly
if [ ! -d "$STATE_DIR"/user/generated ]; then
  mkdir -p "$STATE_DIR"/user/generated
fi
cd "$CONFIG_DIR" || exit

  local modules=()
  while IFS= read -r module_path; do
    [[ -n "$module_path" ]] || continue
    modules+=("$module_path")
  done < <(list_declared_theming_modules)

  if [[ ${#modules[@]} -eq 0 ]]; then
    while IFS= read -r module_path; do
      [[ -n "$module_path" ]] || continue
      modules+=("$module_path")
    done < <(list_theming_modules)
  fi

  if [[ ${#modules[@]} -eq 0 ]]; then
    printf 'No theming modules found in %s\n' "$SCRIPT_DIR/modules" >&2
    exit 1
  fi

  local pids=()
  for module_path in "${modules[@]}"; do
    bash "$module_path" &
    pids+=("$!")
  done

  local failed=0
  for pid in "${pids[@]}"; do
    if ! wait "$pid"; then
      failed=1
    fi
  done

  exit "$failed"
}

apply_qt() {
  sh "$CONFIG_DIR/scripts/kvantum/materialQT.sh"          # generate kvantum theme
  python "$CONFIG_DIR/scripts/kvantum/changeAdwColors.py" # apply config colors
}

apply_code_editors() {
  # Generate code editor themes (Zed, VSCode, etc.)
  local log_file="$STATE_DIR/user/generated/code_editor_themes.log"

  if [ ! -f "$STATE_DIR/user/generated/material_colors.scss" ]; then
    echo "[code-editors] material_colors.scss not found. Skipping." | tee -a "$log_file" 2>/dev/null
    return
  fi

  # Get Python command
  local python_cmd="python3"
  local _ac_venv
  if [[ -n "${ILLOGICAL_IMPULSE_VIRTUAL_ENV:-}" ]]; then
    _ac_venv="$(eval echo "$ILLOGICAL_IMPULSE_VIRTUAL_ENV")"
  else
    _ac_venv="$HOME/.local/state/quickshell/.venv"
  fi
  local venv_python="$_ac_venv/bin/python3"
  if [[ -x "$venv_python" ]]; then
    python_cmd="$venv_python"
  fi

  if ! command -v "$python_cmd" &>/dev/null && [[ ! -x "$python_cmd" ]]; then
    echo "[code-editors] ERROR: Python not found ($python_cmd). Cannot generate themes." >> "$log_file" 2>/dev/null
    return
  fi

  # Check if Zed is installed and enabled
  local enable_zed="true"
  if [ -f "$CONFIG_FILE" ]; then
    enable_zed=$(jq -r 'if .appearance.wallpaperTheming | has("enableZed") then .appearance.wallpaperTheming.enableZed else true end' "$CONFIG_FILE" 2>/dev/null || echo "true")
  fi

  if [[ "$enable_zed" == "true" ]] && { command -v zed &>/dev/null || command -v zeditor &>/dev/null; }; then
    echo "[code-editors] Generating Zed theme..." | tee -a "$log_file" 2>/dev/null
    "$python_cmd" "$SCRIPT_DIR/generate_terminal_configs.py" \
      --scss "$STATE_DIR/user/generated/material_colors.scss" \
      --zed >> "$log_file" 2>&1

    if [ $? -eq 0 ]; then
      echo "[code-editors] Zed theme generated (Zed auto-reloads on file change)" >> "$log_file" 2>/dev/null
    else
      echo "[code-editors] ERROR: Failed to generate Zed theme" >> "$log_file" 2>/dev/null
    fi
  fi

  # Check if VSCode editors are enabled
  local enable_vscode="true"
  if [ -f "$CONFIG_FILE" ]; then
    enable_vscode=$(jq -r 'if .appearance.wallpaperTheming | has("enableVSCode") then .appearance.wallpaperTheming.enableVSCode else true end' "$CONFIG_FILE" 2>/dev/null || echo "true")
  fi

  if [[ "$enable_vscode" == "true" ]]; then
    # Build list of enabled forks from config
    local enabled_forks=()
    if [ -f "$CONFIG_FILE" ]; then
      # Read individual fork settings, default to true if not specified
      local editors_config
      editors_config=$(jq -r '.appearance.wallpaperTheming.vscodeEditors // {}' "$CONFIG_FILE" 2>/dev/null || echo "{}")

      # Map config keys to script fork keys
      [[ $(echo "$editors_config" | jq -r '.code // true') == "true" ]] && [[ -d "$HOME/.config/Code" ]] && enabled_forks+=("code")
      [[ $(echo "$editors_config" | jq -r '.codium // true') == "true" ]] && [[ -d "$HOME/.config/VSCodium" ]] && enabled_forks+=("codium")
      [[ $(echo "$editors_config" | jq -r '.codeOss // true') == "true" ]] && [[ -d "$HOME/.config/Code - OSS" ]] && enabled_forks+=("code-oss")
      [[ $(echo "$editors_config" | jq -r '.codeInsiders // true') == "true" ]] && [[ -d "$HOME/.config/Code - Insiders" ]] && enabled_forks+=("code-insiders")
      [[ $(echo "$editors_config" | jq -r '.cursor // true') == "true" ]] && [[ -d "$HOME/.config/Cursor" ]] && enabled_forks+=("cursor")
      [[ $(echo "$editors_config" | jq -r '.windsurf // true') == "true" ]] && [[ -d "$HOME/.config/Windsurf" ]] && enabled_forks+=("windsurf")
      [[ $(echo "$editors_config" | jq -r '.windsurfNext // true') == "true" ]] && [[ -d "$HOME/.config/Windsurf - Next" ]] && enabled_forks+=("windsurf-next")
      [[ $(echo "$editors_config" | jq -r '.qoder // true') == "true" ]] && [[ -d "$HOME/.config/Qoder" ]] && enabled_forks+=("qoder")
      [[ $(echo "$editors_config" | jq -r '.antigravity // true') == "true" ]] && [[ -d "$HOME/.config/Antigravity" ]] && enabled_forks+=("antigravity")
      [[ $(echo "$editors_config" | jq -r '.positron // true') == "true" ]] && [[ -d "$HOME/.config/Positron" ]] && enabled_forks+=("positron")
      [[ $(echo "$editors_config" | jq -r '.voidEditor // true') == "true" ]] && [[ -d "$HOME/.config/Void" ]] && enabled_forks+=("void")
      [[ $(echo "$editors_config" | jq -r '.melty // true') == "true" ]] && [[ -d "$HOME/.config/Melty" ]] && enabled_forks+=("melty")
      [[ $(echo "$editors_config" | jq -r '.pearai // true') == "true" ]] && [[ -d "$HOME/.config/PearAI" ]] && enabled_forks+=("pearai")
      [[ $(echo "$editors_config" | jq -r '.aide // true') == "true" ]] && [[ -d "$HOME/.config/Aide" ]] && enabled_forks+=("aide")
    fi

    if [ ${#enabled_forks[@]} -gt 0 ]; then
      echo "[code-editors] Generating VSCode themes for: ${enabled_forks[*]}" | tee -a "$log_file" 2>/dev/null
      "$python_cmd" "$SCRIPT_DIR/generate_terminal_configs.py" \
        --scss "$STATE_DIR/user/generated/material_colors.scss" \
        --vscode --vscode-forks "${enabled_forks[@]}" >> "$log_file" 2>&1

      if [ $? -eq 0 ]; then
        echo "[code-editors] VSCode themes generated (auto-reloads instantly)" >> "$log_file" 2>/dev/null
      else
        echo "[code-editors] ERROR: Failed to generate VSCode themes" >> "$log_file" 2>/dev/null
      fi
    else
      echo "[code-editors] No enabled VSCode forks found" >> "$log_file" 2>/dev/null
    fi
  fi
}

apply_gtk_kde() {
  # apply-gtk-theme.sh reads colors.json (matugen's output) directly
  # It generates: kdeglobals, Darkly.colors, pywalfox colors
  # GTK CSS is handled by matugen templates
  "$SCRIPT_DIR/apply-gtk-theme.sh"
}

apply_chrome() {
  # apply-chrome-theme.sh applies GM3 BrowserThemeColor to Chromium-based browsers
  # Supports: Google Chrome, Chromium, Brave (and Omarchy fork with CLI theming)
  "$SCRIPT_DIR/apply-chrome-theme.sh"
}

apply_spicetify() {
  # apply-spicetify-theme.sh creates/updates a dedicated Spicetify theme from colors.json
  "$SCRIPT_DIR/apply-spicetify-theme.sh"
}

# Check if terminal theming is enabled in config
CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/illogical-impulse/config.json"
if [ -f "$CONFIG_FILE" ]; then
  enable_terminal=$(jq -r '.appearance.wallpaperTheming.enableTerminal // true' "$CONFIG_FILE" 2>/dev/null || echo "true")
  if [ "$enable_terminal" = "true" ]; then
    apply_term &
    apply_terminal_configs &
  fi
else
  echo "Config file not found at $CONFIG_FILE. Applying terminal theming by default."
  apply_term &
  apply_terminal_configs &
fi

# apply_qt & # Qt theming is already handled by kde-material-colors

# Apply GTK/KDE theming if enabled
if [ -f "$CONFIG_FILE" ]; then
  enable_apps_shell=$(jq -r '.appearance.wallpaperTheming.enableAppsAndShell // true' "$CONFIG_FILE")
  enable_qt_apps=$(jq -r '.appearance.wallpaperTheming.enableQtApps // true' "$CONFIG_FILE")
  if [ "$enable_apps_shell" != "false" ] || [ "$enable_qt_apps" != "false" ]; then
    apply_gtk_kde &
  fi
else
  apply_gtk_kde &
fi


# Apply code editor themes (Zed, etc.)
apply_code_editors &

# Apply OpenCode TUI theme
apply_opencode_theme() {
  local log_file="$STATE_DIR/user/generated/code_editor_themes.log"
  local scss_file="$STATE_DIR/user/generated/material_colors.scss"
  local generator="$SCRIPT_DIR/opencode/theme_generator.py"

  if [ ! -f "$scss_file" ]; then
    return
  fi

  if [ ! -f "$generator" ]; then
    return
  fi

  local python_cmd="python3"
  local _ac_venv
  if [[ -n "${ILLOGICAL_IMPULSE_VIRTUAL_ENV:-}" ]]; then
    _ac_venv="$(eval echo "$ILLOGICAL_IMPULSE_VIRTUAL_ENV")"
  else
    _ac_venv="$HOME/.local/state/quickshell/.venv"
  fi
  local venv_python="$_ac_venv/bin/python3"
  if [[ -x "$venv_python" ]]; then
    python_cmd="$venv_python"
  fi

  "$python_cmd" "$generator" "$scss_file" >> "$log_file" 2>&1
}

if [ -f "$CONFIG_FILE" ]; then
  enable_opencode=$(jq -r '.appearance.wallpaperTheming.enableOpenCode // true' "$CONFIG_FILE" 2>/dev/null || echo "true")
  if [ "$enable_opencode" = "true" ] && command -v opencode &>/dev/null; then
    apply_opencode_theme &
  fi
else
  if command -v opencode &>/dev/null; then
    apply_opencode_theme &
  fi
fi

# Apply Chrome/Chromium/Brave GM3 theme via managed policies
if [ -f "$CONFIG_FILE" ]; then
  enable_chrome=$(jq -r '.appearance.wallpaperTheming.enableChrome // true' "$CONFIG_FILE" 2>/dev/null || echo "true")
  if [ "$enable_chrome" = "true" ]; then
    apply_chrome &
  fi
else
  apply_chrome &
fi

# Apply Spotify theme via Spicetify (opt-in)
if [ -f "$CONFIG_FILE" ]; then
  enable_spicetify=$(jq -r '.appearance.wallpaperTheming.enableSpicetify // false' "$CONFIG_FILE" 2>/dev/null || echo "false")
  if [ "$enable_spicetify" = "true" ] && command -v spicetify &>/dev/null; then
    apply_spicetify &
  fi
fi

# Sync ii-pixel SDDM theme colors (if installed)
SDDM_SYNC_SCRIPT="$SCRIPT_DIR/../sddm/sync-pixel-sddm.py"
if [[ -d "/usr/share/sddm/themes/ii-pixel" && -f "$SDDM_SYNC_SCRIPT" ]]; then
  python3 "$SDDM_SYNC_SCRIPT" &
fi
