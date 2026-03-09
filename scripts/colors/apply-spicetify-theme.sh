#!/usr/bin/env bash

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
STATE_DIR="$XDG_STATE_HOME/quickshell"
CONFIG_FILE="$XDG_CONFIG_HOME/illogical-impulse/config.json"
GENERATED_COLOR_INI="$STATE_DIR/user/generated/spicetify/color.ini"
COLORS_JSON="$STATE_DIR/user/generated/colors.json"
SOURCE_THEME_DIR="$XDG_CONFIG_HOME/matugen/spicetify/ii-matugen"
LOG_FILE="$STATE_DIR/user/generated/spicetify_theme.log"
THEME_NAME="ii-matugen"
COLOR_SCHEME="matugen"

mkdir -p "$STATE_DIR/user/generated" 2>/dev/null

log() {
  echo "[spicetify] $*" >> "$LOG_FILE"
}

is_enabled() {
  local enable_apps_shell="true"
  local enable_spicetify="true"

  if [[ -f "$CONFIG_FILE" ]] && command -v jq &>/dev/null; then
    enable_apps_shell=$(jq -r '.appearance.wallpaperTheming.enableAppsAndShell // true' "$CONFIG_FILE" 2>/dev/null || echo "true")
    enable_spicetify=$(jq -r '.appearance.wallpaperTheming.enableSpicetify // true' "$CONFIG_FILE" 2>/dev/null || echo "true")
  fi

  [[ "$enable_apps_shell" == "true" && "$enable_spicetify" == "true" ]]
}

strip_hash() {
  printf '%s' "${1#\#}"
}

render_fallback_color_ini() {
  [[ -f "$COLORS_JSON" ]] || return 1
  command -v jq &>/dev/null || return 1

  local main main_secondary accent button button_secondary button_active button_disabled
  local misc subtext text sidebar player card notification notification_error shadow
  local nav_active_text nav_active tab_active play_button playback_bar

  main=$(jq -r '.background // .surface // "#141218"' "$COLORS_JSON")
  main_secondary=$(jq -r '.surface_container_high // .surface_container // .surface_variant // .surface // "#2b2930"' "$COLORS_JSON")
  accent=$(jq -r '.primary // "#d0bcff"' "$COLORS_JSON")
  button="$accent"
  button_secondary=$(jq -r '.secondary // "#ccc2dc"' "$COLORS_JSON")
  button_active=$(jq -r '.primary_container // .primary // "#4f378b"' "$COLORS_JSON")
  button_disabled=$(jq -r '.surface_container_high // .surface_variant // .surface // "#2b2930"' "$COLORS_JSON")

  misc=$(jq -r '.tertiary // .secondary // "#efb8c8"' "$COLORS_JSON")
  subtext=$(jq -r '.on_surface_variant // .on_surface // "#cac4d0"' "$COLORS_JSON")
  text=$(jq -r '.on_background // .on_surface // "#e6e0e9"' "$COLORS_JSON")
  sidebar=$(jq -r '.surface // .background // "#1d1b20"' "$COLORS_JSON")
  player="$sidebar"
  card=$(jq -r '.surface_container // .surface_container_high // .surface // "#211f26"' "$COLORS_JSON")
  notification="$sidebar"
  notification_error=$(jq -r '.error // "#f2b8b5"' "$COLORS_JSON")
  shadow=$(jq -r '.shadow // "#000000"' "$COLORS_JSON")

  nav_active_text="$accent"
  nav_active="$accent"
  tab_active="$sidebar"
  play_button="$accent"
  playback_bar=$(jq -r '.primary_container // .primary // "#4f378b"' "$COLORS_JSON")

  mkdir -p "$(dirname "$GENERATED_COLOR_INI")"
  cat > "$GENERATED_COLOR_INI" <<EOF
[matugen]
main               = $(strip_hash "$main")
main-secondary     = $(strip_hash "$main_secondary")
accent             = $(strip_hash "$accent")
button             = $(strip_hash "$button")
button-secondary   = $(strip_hash "$button_secondary")
button-active      = $(strip_hash "$button_active")
button-disabled    = $(strip_hash "$button_disabled")

misc               = $(strip_hash "$misc")
subtext            = $(strip_hash "$subtext")
text               = $(strip_hash "$text")
sidebar            = $(strip_hash "$sidebar")
player             = $(strip_hash "$player")
card               = $(strip_hash "$card")
notification       = $(strip_hash "$notification")
notification-error = $(strip_hash "$notification_error")
shadow             = $(strip_hash "$shadow")

nav-active-text    = $(strip_hash "$nav_active_text")
nav-active         = $(strip_hash "$nav_active")
tab-active         = $(strip_hash "$tab_active")
play-button        = $(strip_hash "$play_button")

playback-bar       = $(strip_hash "$playback_bar")
EOF
}

write_default_user_css() {
  local target="$1"
  cat > "$target" <<'EOF'
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
EOF
}

main() {
  is_enabled || exit 0

  if ! command -v spicetify &>/dev/null; then
    log "Spicetify not installed; skipping"
    exit 0
  fi

  if [[ ! -f "$GENERATED_COLOR_INI" ]]; then
    render_fallback_color_ini || {
      log "No generated color.ini and fallback colors.json unavailable; skipping"
      exit 0
    }
  fi

  local userdata_dir
  userdata_dir=$(spicetify path userdata 2>/dev/null | tail -n 1 | tr -d '\r')
  [[ -z "$userdata_dir" ]] && userdata_dir="$XDG_CONFIG_HOME/spicetify"

  local target_theme_dir="$userdata_dir/Themes/$THEME_NAME"
  mkdir -p "$target_theme_dir"

  install -m 0644 "$GENERATED_COLOR_INI" "$target_theme_dir/color.ini"
  if [[ -f "$SOURCE_THEME_DIR/user.css" ]]; then
    install -m 0644 "$SOURCE_THEME_DIR/user.css" "$target_theme_dir/user.css"
  else
    write_default_user_css "$target_theme_dir/user.css"
  fi

  if ! spicetify config current_theme "$THEME_NAME" color_scheme "$COLOR_SCHEME" inject_css 1 replace_colors 1 >/dev/null 2>&1; then
    log "Failed to update Spicetify config"
  fi

  if spicetify -q -s refresh >/dev/null 2>&1; then
    log "Refreshed active Spicetify theme"
  elif spicetify -q apply >/dev/null 2>&1; then
    log "Applied Spicetify theme"
  elif spicetify -q backup apply >/dev/null 2>&1; then
    log "Ran backup+apply for Spicetify theme"
  else
    log "Failed to refresh/apply theme; run 'spicetify backup apply' once if Spotify was never patched"
  fi
}

main "$@"
