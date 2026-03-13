#!/usr/bin/env bash
#
# apply-chrome-theme.sh — Apply GM3 BrowserThemeColor to Chromium-based browsers
#
# Usage:
#   apply-chrome-theme.sh                  # auto-detect color from material pipeline
#   apply-chrome-theme.sh "#ff6b35"        # explicit hex color
#
# Supports: Google Chrome, Chromium, Brave
# Requires: jq, writable policy dir (one-time sudo setup)
#
# One-time setup per browser:
#   sudo mkdir -p /etc/chromium/policies/managed && sudo chown a+rw- /etc/chromium/policies/managed
#   sudo mkdir -p /etc/opt/chrome/policies/managed && sudo chown a+rw- /etc/opt/chrome/policies/managed
#   sudo mkdir -p /etc/brave/policies/managed && sudo chown a+rw- /etc/brave/policies/managed

XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
STATE_DIR="$XDG_STATE_HOME/quickshell"
LOG_FILE="$STATE_DIR/user/generated/chrome_theme.log"
mkdir -p "$STATE_DIR/user/generated" 2>/dev/null
: > "$LOG_FILE" 2>/dev/null

log() { echo "[chrome] $*" >> "$LOG_FILE"; }

# ── Helpers ──────────────────────────────────────────────────────────────────

hex_to_rgb() {
  local hex=$1
  hex="${hex#\#}"
  printf "%d,%d,%d" "0x${hex:0:2}" "0x${hex:2:2}" "0x${hex:4:2}"
}

# Convert a hex color (#RRGGBB) to Chrome's packed signed int32 ARGB format.
# Chrome stores user_color as a signed 32-bit int where the bits are AARRGGBB (A=0xFF).
# e.g. #6CB890 -> 0xFF6CB890 -> reinterpreted as signed -> -9652080
hex_to_chrome_int() {
  local hex="${1#\#}"
  python3 -c "
import struct
r,g,b = int('${hex:0:2}',16), int('${hex:2:2}',16), int('${hex:4:2}',16)
packed = (0xFF << 24) | (r << 16) | (g << 8) | b
print(struct.unpack('i', struct.pack('I', packed))[0])
" 2>/dev/null
}

# Map variant name to Chrome's internal integer enum.
# From Chrome source: kTonalSpot=1, kNeutral=2, kVibrant=3, kExpressive=4
variant_to_int() {
  case "$1" in
    tonal_spot)  echo 1 ;;
    neutral)     echo 2 ;;
    vibrant)     echo 3 ;;
    expressive)  echo 4 ;;
    *)           echo 1 ;;  # default: tonal_spot
  esac
}

is_omarchy() {
  local bin_path
  bin_path=$(command -v "$1" 2>/dev/null)
  if [[ -n "$bin_path" ]]; then
    if command -v pacman &>/dev/null; then
      pacman -Qo "$bin_path" 2>/dev/null | grep -qi "omarchy" && return 0
    fi
  fi
  return 1
}

# ── Resolve theme color ─────────────────────────────────────────────────────

resolve_color() {
  # 1. Explicit argument
  if [[ -n "$1" && "$1" =~ ^#[A-Fa-f0-9]{6}$ ]]; then
    echo "$1"
    return
  fi

  # 2. Raw seed color from image (best for GM3, as Chrome generates its own palette from this)
  local seed_file="$STATE_DIR/user/generated/color.txt"
  if [[ -f "$seed_file" ]]; then
    local c
    c=$(cat "$seed_file" | tr -d '\n')
    if [[ -n "$c" && "$c" =~ ^#[A-Fa-f0-9]{6}$ ]]; then
      echo "$c"
      return
    fi
  fi

  # 3. colors.json fallback (this is the already-generated primary, which might cause double-theming)
  local colors_json="$STATE_DIR/user/generated/colors.json"
  if [[ -f "$colors_json" ]] && command -v jq &>/dev/null; then
    local c
    c=$(jq -r '.primary // empty' "$colors_json" 2>/dev/null)
    if [[ -n "$c" ]]; then
      echo "$c"
      return
    fi
  fi
}

# ── Resolve dark/light mode ─────────────────────────────────────────────────
# Returns Chrome's color_scheme2 value:
#   In Chrome internals: 0 = system, 1 = light, 2 = dark
# But since Niri does not have a reliable XDG portal for standard Chrome,
# we map them directly. However, we'll invert them if needed to match what actually works.

resolve_color_scheme() {
  local scss_file="$STATE_DIR/user/generated/material_colors.scss"
  if [[ -f "$scss_file" ]]; then
    local val
    val=$(grep '^\$darkmode:' "$scss_file" | sed 's/.*: *\(.*\);/\1/' | tr -d ' ')
    if [[ "$val" == "True" || "$val" == "true" ]]; then
      # If Dark mode is currently returning light, we swap to 1.
      # If it's standard, it's 2. But we need to use 2 for dark in CLI and 2 for light in Prefs? 
      # Let's pass 'dark' or 'light' string, and translate internally per method.
      echo "dark"
      return
    fi
  fi
  echo "light"
}

# ── Browser registry ─────────────────────────────────────────────────────────
# Each entry: bin_name|policy_dir|prefs_dir

BROWSERS=()

_register() {
  local bin="$1" policy_dir="$2" prefs_dir="$3"
  if command -v "$bin" &>/dev/null; then
    BROWSERS+=("$bin|$policy_dir|$prefs_dir")
  fi
}

# Google Chrome
_register google-chrome-stable "/etc/opt/chrome/policies/managed" "$HOME/.config/google-chrome"
_register google-chrome        "/etc/opt/chrome/policies/managed" "$HOME/.config/google-chrome"
# Chromium
_register chromium             "/etc/chromium/policies/managed"   "$HOME/.config/chromium"
_register chromium-browser     "/etc/chromium/policies/managed"   "$HOME/.config/chromium"
# Brave
_register brave                "/etc/brave/policies/managed"      "$HOME/.config/BraveSoftware/Brave-Browser"
_register brave-browser        "/etc/brave/policies/managed"      "$HOME/.config/BraveSoftware/Brave-Browser"

# Deduplicate by policy_dir (e.g. google-chrome-stable vs google-chrome)
_dedup_browsers() {
  local -A seen
  local deduped=()
  for entry in "${BROWSERS[@]}"; do
    local policy_dir="${entry#*|}"
    policy_dir="${policy_dir%%|*}"
    if [[ -z "${seen[$policy_dir]:-}" ]]; then
      seen[$policy_dir]=1
      deduped+=("$entry")
    fi
  done
  BROWSERS=("${deduped[@]}")
}

# ── Preferences fixer ────────────────────────────────────────────────────────
# Patches BOTH browser.theme (local prefs) AND account_values.browser.theme
# (synced account layer, which takes higher priority in signed-in Chrome).
# Without fixing account_values, a stale synced user_color will override
# any local color_scheme setting, keeping Chrome stuck on the wrong theme.
#
# Args:
#   $1 = prefs_dir
#   $2 = browser name (for logging)
#   $3 = color_scheme int (2=dark, 1=light)
#   $4 = user_color signed int32 (packed ARGB of the seed color)
#   $5 = color_variant int (1=tonal_spot, 2=neutral, 3=vibrant, 4=expressive)

fix_preferences() {
  local prefs_dir="$1"
  local name="$2"
  local cs="$3"        # 2=dark, 1=light
  local user_color="$4"  # signed int32 ARGB
  local variant_int="$5" # Chrome variant enum int
  local prefs_file="$prefs_dir/Default/Preferences"

  # Create Default dir and minimal Preferences if missing
  if [[ ! -f "$prefs_file" ]]; then
    mkdir -p "$prefs_dir/Default" 2>/dev/null
    echo '{}' > "$prefs_file"
    log "$name: created empty Preferences file"
  fi

  local tmp_file="${prefs_file}.ii-tmp"

  # Patch both the local pref layer (browser.theme) and the synced account
  # layer (account_values.browser.theme). Chrome merges these at runtime with
  # account_values taking precedence for signed-in users, so both must agree.
  if jq \
    --argjson cs "$cs" \
    --argjson uc "$user_color" \
    --argjson cv "$variant_int" \
    '
    # ── local pref layer ──────────────────────────────────────────────
    .extensions.theme.id = "" |
    .extensions.theme.use_system = false |
    .extensions.theme.use_custom = false |
    .browser.theme.color_scheme  = $cs |
    .browser.theme.color_scheme2 = $cs |
    .browser.theme.user_color    = $uc |
    .browser.theme.color_variant = $cv |
    del(.browser.theme.user_color2) |
    del(.browser.theme.saved_local_theme) |
    del(.browser.theme.color_variant2) |

    # ── synced account layer (higher priority when signed in) ─────────
    .account_values.browser.theme.color_scheme  = $cs |
    .account_values.browser.theme.user_color    = $uc |
    .account_values.browser.theme.color_variant = $cv |
    del(.account_values.browser.theme.saved_local_theme)
    ' "$prefs_file" > "$tmp_file" 2>/dev/null && [[ -s "$tmp_file" ]]; then
    mv "$tmp_file" "$prefs_file"
    log "$name: preferences set (color_scheme=$cs, user_color=$user_color, variant=$variant_int)"
  else
    rm -f "$tmp_file"
    log "$name: ERROR — failed to update preferences"
  fi
}

# ── Write policy and refresh ─────────────────────────────────────────────────

apply_to_browser() {
  local bin="$1"
  local policy_dir="$2"
  local prefs_dir="$3"
  local theme_color="$4"
  local mode="$5"     # "dark" or "light"
  local variant="$6"  # "tonal_spot", "neutral", "vibrant", "expressive"
  local name="$bin"

  # color_scheme: 2=dark, 1=light
  local pref_cs=1
  if [[ "$mode" == "dark" ]]; then
    pref_cs=2
  fi

  # Convert hex seed color to Chrome's packed signed int32 ARGB (for user_color pref)
  local user_color_int
  user_color_int=$(hex_to_chrome_int "$theme_color")
  if [[ -z "$user_color_int" ]]; then
    log "$name: WARNING — could not convert color to int (python3 missing?), skipping user_color patch"
    user_color_int=0
  fi

  # Convert variant name to Chrome's internal integer enum
  local variant_int
  variant_int=$(variant_to_int "$variant")

  # 1. Fix preferences — patches both browser.theme and account_values.browser.theme
  fix_preferences "$prefs_dir" "$name" "$pref_cs" "$user_color_int" "$variant_int"

  # 2. Write managed policy — BrowserThemeColor is the primary live hook;
  #    BrowserColorScheme enforces dark/light at the policy level.
  #    Both are refreshed live via --refresh-platform-policy.
  #    BrowserColorScheme values: 1=Light, 2=Dark
  if [[ -d "$policy_dir" && -w "$policy_dir" ]]; then
    printf '{"BrowserThemeColor": "%s", "BrowserColorScheme": %d}\n' \
      "$theme_color" "$pref_cs" | tee "$policy_dir/ii-theme.json" >/dev/null
    log "$name: policy written (BrowserThemeColor=$theme_color, BrowserColorScheme=$pref_cs)"
  else
    log "$name: policy dir not writable → sudo mkdir -p $policy_dir && sudo chown \$USER $policy_dir"
  fi

  # 3. Apply live
  if is_omarchy "$bin"; then
    local rgb_color
    rgb_color=$(hex_to_rgb "$theme_color")
    log "$name: Omarchy fork detected. Using CLI flags + policy."
    "$bin" --no-startup-window \
           --refresh-platform-policy \
           --set-user-color="$rgb_color" \
           --set-color-scheme="$mode" \
           --set-color-variant="$variant" >/dev/null 2>&1 & disown
  else
    log "$name: Standard browser detected. Using policy refresh."
    "$bin" --refresh-platform-policy --no-startup-window >/dev/null 2>&1 & disown
  fi

  log "$name: applied theme $theme_color (mode=$mode, variant=$variant, user_color=$user_color_int)"
}

# ── Resolve variant (scheme type) ──────────────────────────────────────────────

resolve_variant() {
  # Read variant from config
  local config_file="${XDG_CONFIG_HOME:-$HOME/.config}/illogical-impulse/config.json"
  if [[ -f "$config_file" ]]; then
    local variant
    variant=$(jq -r '.appearance.palette.type // "auto"' "$config_file" 2>/dev/null)
    if [[ -n "$variant" && "$variant" != "null" && "$variant" != "auto" ]]; then
      # Convert scheme-xxx to xxx for Chrome (e.g., scheme-tonal-spot -> tonal_spot)
      local chrome_variant
      chrome_variant=$(echo "$variant" | sed 's/scheme-//')

      # Chrome only supports: tonal_spot, neutral, vibrant, expressive
      # Map unsupported variants to neutral
      case "$chrome_variant" in
        tonal_spot|neutral|vibrant|expressive)
          echo "$chrome_variant"
          ;;
        *)
          echo "neutral"
          ;;
      esac
      return
    fi
  fi
  echo "tonal_spot"  # Default fallback
}

# ── Main ─────────────────────────────────────────────────────────────────────

main() {
  local theme_color
  theme_color=$(resolve_color "$1")

  if [[ -z "$theme_color" ]]; then
    log "Could not determine primary color. Skipping."
    return 1
  fi

  local mode
  mode=$(resolve_color_scheme)

  local variant
  variant=$(resolve_variant)

  log "GM3 seed color: $theme_color, mode: $mode, variant: $variant"

  _dedup_browsers

  if [[ ${#BROWSERS[@]} -eq 0 ]]; then
    log "No Chromium-based browsers found. Skipping."
    return 0
  fi

  for entry in "${BROWSERS[@]}"; do
    IFS='|' read -r bin policy_dir prefs_dir <<< "$entry"
    apply_to_browser "$bin" "$policy_dir" "$prefs_dir" "$theme_color" "$mode" "$variant"
  done
}

main "$@"
