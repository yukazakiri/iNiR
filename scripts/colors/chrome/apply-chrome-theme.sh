#!/usr/bin/env bash
# Apply Chrome/Chromium/Brave GM3 (Material You) theming via managed policy files.
#
# Chrome reads every *.json file inside the managed-policy directory.
# Writing BrowserThemeColor as the M3 seed is enough — Chrome derives
# the full tonal palette internally.
#
# Policy directories (Linux):
#   /etc/chromium/policies/managed/   – Chromium
#   /etc/opt/chrome/policies/managed/ – Google Chrome
#   /etc/brave/policies/managed/      – Brave
#   /etc/opt/edge/policies/managed/   – Microsoft Edge
#
# One-time sudo setup (only needed if dirs don't exist yet):
#   sudo mkdir -p /etc/chromium/policies/managed
#   sudo chmod 777 /etc/chromium/policies/managed
#
# Reload strategy (fastest → slowest):
#   1. --refresh-platform-policy (Chrome 142+ / Brave 141+) — instant
#   2. touch the file to wake Chrome's inotify watcher — ~3 min
#   3. Inform user to visit chrome://policy and click Reload

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE_DIR="$XDG_STATE_HOME/quickshell"
SCSS="$STATE_DIR/user/generated/material_colors.scss"
LOG="$STATE_DIR/user/generated/chrome_theme.log"
POLICY_FILE="ii-material-theme.json"
CONFIG_FILE="$XDG_CONFIG_HOME/illogical-impulse/config.json"

_log() { echo "$1" | tee -a "$LOG"; }

# ── Prerequisite checks ────────────────────────────────────────────────────────
if [[ ! -f "$SCSS" ]]; then
  _log "[chrome-theme] material_colors.scss not found. Skipping."
  exit 0
fi

if [[ -f "$CONFIG_FILE" ]] && command -v jq &>/dev/null; then
  enable_chrome=$(jq -r '.appearance.wallpaperTheming.enableChrome // true' "$CONFIG_FILE" 2>/dev/null)
  [[ "$enable_chrome" != "true" ]] && exit 0
fi

# ── Extract primary color from SCSS ───────────────────────────────────────────
# SCSS lines look like:  $primary: #6750A4;
# Fall back to term4 (blue slot) if no $primary variable exists.
primary=$(grep -m1 '^\$primary:' "$SCSS" | cut -d: -f2 | tr -d ' ;')
if [[ -z "$primary" ]]; then
  primary=$(grep -m1 '^\$term4:' "$SCSS" | cut -d: -f2 | tr -d ' ;')
fi
primary="${primary:-#4285F4}"   # last-resort Google Blue

_log "[chrome-theme] primary=$primary"

# ── Build policy JSON ─────────────────────────────────────────────────────────
# Single-line is valid JSON; keeps it tiny on disk and easy to diff.
POLICY_JSON="{\"BrowserThemeColor\":\"$primary\",\"NtpCustomBackgroundEnabled\":true}"

# ── Browser registry ──────────────────────────────────────────────────────────
# Format: "display-name|policy-dir|bin1 bin2 ..."
BROWSERS=(
  "chromium|/etc/chromium/policies/managed|chromium chromium-browser"
  "google-chrome|/etc/opt/chrome/policies/managed|google-chrome google-chrome-stable"
  "brave|/etc/brave/policies/managed|brave brave-browser"
  "microsoft-edge|/etc/opt/edge/policies/managed|microsoft-edge msedge"
)

# ── Helper: find first available binary from a space-separated list ───────────
_find_bin() {
  local bins="$1"
  for b in $bins; do
    if command -v "$b" &>/dev/null; then
      echo "$b"; return 0
    fi
  done
  return 1
}

# ── Helper: check if any binary from the list is running ──────────────────────
_is_running() {
  local bins="$1"
  for b in $bins; do
    pgrep -x "$b" &>/dev/null && return 0
  done
  return 1
}

# ── Helper: attempt --refresh-platform-policy signal ─────────────────────────
_refresh_policy() {
  local bin="$1" name="$2"
  # Spawn detached; the flag makes Chrome signal the running instance then exit.
  timeout 5s "$bin" --refresh-platform-policy --no-startup-window &>/dev/null
  local rc=$?
  if [[ $rc -eq 0 ]]; then
    _log "[chrome-theme] $name: policies refreshed via --refresh-platform-policy"
    return 0
  fi
  return 1
}

# ── Main loop ─────────────────────────────────────────────────────────────────
any_written=false

for entry in "${BROWSERS[@]}"; do
  IFS='|' read -r name policy_dir bins <<< "$entry"

  # Skip if neither installed nor policy dir already exists
  bin="$(_find_bin "$bins" || true)"
  if [[ -z "$bin" && ! -d "$policy_dir" ]]; then
    continue
  fi

  # Ensure policy directory exists and is world-writable
  if [[ ! -d "$policy_dir" ]]; then
    mkdir -p "$policy_dir" 2>/dev/null || {
      _log "[chrome-theme] $name: cannot create $policy_dir (run once with sudo to initialise)"
      continue
    }
    chmod 777 "$policy_dir" 2>/dev/null || true
  fi

  # Write policy file
  policy_path="$policy_dir/$POLICY_FILE"
  if printf '%s\n' "$POLICY_JSON" > "$policy_path" 2>/dev/null; then
    chmod 666 "$policy_path" 2>/dev/null || true
    _log "[chrome-theme] $name: wrote $policy_path"
    any_written=true
  else
    _log "[chrome-theme] $name: permission denied writing $policy_path (run once with sudo to initialise permissions)"
    continue
  fi

  # Reload running instances
  if [[ -z "$bin" ]]; then
    _log "[chrome-theme] $name: binary not found – policy ready for when it is installed"
    continue
  fi

  if ! _is_running "$bins"; then
    _log "[chrome-theme] $name: not running – policy applies on next launch"
    continue
  fi

  # Try --refresh-platform-policy first (Chrome 142+ / Brave 141+)
  if _refresh_policy "$bin" "$name"; then
    continue
  fi

  # Fallback: touch wakes inotify watcher (~3 min delay)
  touch "$policy_path" 2>/dev/null || true
  _log "[chrome-theme] $name: policy file touched (Chrome reloads within ~3 min, or visit chrome://policy → Reload)"
done

if [[ "$any_written" != "true" ]]; then
  _log "[chrome-theme] No writable policy directory found. Install a Chromium-based browser or pre-create the policy dir with sudo."
fi
