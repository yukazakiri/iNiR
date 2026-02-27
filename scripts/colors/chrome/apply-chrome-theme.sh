#!/usr/bin/env bash
# Apply Chrome/Chromium/Brave GM3 (Material You) theming via managed policy files.
#
# Chrome reads every *.json file inside the managed-policy directory and merges
# them. Files are merged in alphabetical order — the LAST file wins for duplicate
# keys. We write directly into theme.json so there is no ordering conflict with
# any pre-existing policy files.
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
#   1. --refresh-platform-policy (Chrome 142+ / Brave 141+, only when running)
#   2. touch the file to wake Chrome's inotify watcher (~3 min)
#   3. Log message — policy applies on next browser launch

XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE_DIR="$XDG_STATE_HOME/quickshell"
SCSS="$STATE_DIR/user/generated/material_colors.scss"
LOG="$STATE_DIR/user/generated/chrome_theme.log"
# Write to theme.json so we are always the sole/last file in the dir
# and never get overridden by a stale alphabetically-later policy file.
POLICY_FILE="theme.json"
CONFIG_FILE="$XDG_CONFIG_HOME/illogical-impulse/config.json"

_log() { printf '%s\n' "$1" | tee -a "$LOG"; }

# ── Prerequisite checks ───────────────────────────────────────────────────────
if [[ ! -f "$SCSS" ]]; then
  _log "[chrome-theme] material_colors.scss not found. Skipping."
  exit 0
fi

if [[ -f "$CONFIG_FILE" ]] && command -v jq &>/dev/null; then
  enable_chrome=$(jq -r '.appearance.wallpaperTheming.enableChrome // true' "$CONFIG_FILE" 2>/dev/null)
  [[ "$enable_chrome" != "true" ]] && exit 0
fi

# ── Extract primary color and dark mode flag from SCSS ───────────────────────
# SCSS lines look like:  $primary: #6750A4;  and  $darkmode: True;
# Fall back to $term4 (blue slot) if $primary is absent, then hardcoded fallback.
primary=$(grep -m1 '^\$primary:' "$SCSS" | cut -d: -f2 | tr -d ' ;')
[[ -z "$primary" ]] && primary=$(grep -m1 '^\$term4:' "$SCSS" | cut -d: -f2 | tr -d ' ;')
primary="${primary:-#4285F4}"

# $darkmode: True|False  →  BrowserColorScheme: 2 (dark) | 1 (light)
# Chrome normally infers this from the XDG portal color-scheme signal, but the
# portal can be out of sync with the actual theme. Setting the policy directly
# ensures the browser always matches the system's actual dark/light state.
darkmode_raw=$(grep -m1 '^\$darkmode:' "$SCSS" | cut -d: -f2 | tr -d ' ;')
if [[ "${darkmode_raw,,}" == "true" ]]; then
  color_scheme=2   # dark
else
  color_scheme=1   # light
fi

_log "[chrome-theme] primary=$primary dark=$([[ $color_scheme -eq 2 ]] && echo true || echo false)"

# ── Sync system color-scheme so portal and browsers agree ────────────────────
# gsettings → xdg-desktop-portal-gtk emits SettingChanged on the session bus.
# Browsers listen to this signal for live dark/light updates independent of policy.
# We set it here so both the policy value AND the live signal are always in sync.
if command -v gsettings &>/dev/null; then
  if [[ $color_scheme -eq 2 ]]; then
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark' 2>/dev/null || true
  else
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-light' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3' 2>/dev/null || true
  fi
fi

# ── Build policy JSON ─────────────────────────────────────────────────────────
# BrowserColorScheme: 1=light 2=dark (Chrome 123+, Brave 141+)
# This overrides the XDG portal signal, which can be stale/wrong.
POLICY_JSON="{\"BrowserThemeColor\":\"$primary\",\"BrowserColorScheme\":$color_scheme,\"NtpCustomBackgroundEnabled\":true}"

# ── Browser registry ──────────────────────────────────────────────────────────
# Format: "label|policy-dir|space-separated binaries|space-separated pgrep comm names"
# pgrep names can differ from the binary name (e.g. wrapper script vs real binary).
BROWSERS=(
  "chromium|/etc/chromium/policies/managed|chromium chromium-browser|chromium chromium-browser"
  "google-chrome|/etc/opt/chrome/policies/managed|google-chrome google-chrome-stable chrome|chrome google-chrome"
  "brave|/etc/brave/policies/managed|brave brave-browser|brave"
  "microsoft-edge|/etc/opt/edge/policies/managed|microsoft-edge msedge|msedge microsoft-edge"
)

# ── Helper: find first available binary ──────────────────────────────────────
_find_bin() {
  for b in $1; do command -v "$b" &>/dev/null && { echo "$b"; return 0; }; done
  return 1
}

# ── Helper: check if any comm name is currently running ──────────────────────
_is_running() {
  for comm in $1; do pgrep -x "$comm" &>/dev/null && return 0; done
  return 1
}

# ── Helper: signal running browser to reload policies immediately ─────────────
# --refresh-platform-policy: when a browser instance is already running this flag
# causes the new process to signal it and exit immediately (Chrome 142+/Brave 141+).
# We only call it when we have confirmed the browser IS running; otherwise it
# would open a new browser window.
# IMPORTANT: flush all writes to disk first (sync) and give the kernel a moment
# to settle before signalling — the browser reads the file on receipt of the
# signal, and a race window between write and signal causes it to read the old value.
_refresh_policy() {
  local bin="$1" label="$2"
  sync
  sleep 0.3
  if timeout 4s "$bin" --refresh-platform-policy --no-startup-window &>/dev/null; then
    _log "[chrome-theme] $label: policies reloaded via --refresh-platform-policy"
    return 0
  fi
  return 1
}

# ── Main loop ─────────────────────────────────────────────────────────────────
any_written=false

for entry in "${BROWSERS[@]}"; do
  IFS='|' read -r label policy_dir bins comms <<< "$entry"

  bin="$(_find_bin "$bins" || true)"

  # Skip if the browser is neither installed nor has a pre-existing policy dir
  [[ -z "$bin" && ! -d "$policy_dir" ]] && continue

  # Ensure policy directory exists and is world-writable
  if [[ ! -d "$policy_dir" ]]; then
    if ! mkdir -p "$policy_dir" 2>/dev/null; then
      _log "[chrome-theme] $label: cannot create $policy_dir (run once with sudo)"
      continue
    fi
    chmod 777 "$policy_dir" 2>/dev/null || true
  fi

  # Remove legacy policy file from previous naming convention (sorted before theme.json,
  # but clean it up to avoid confusion and any future Chrome merge-order surprises)
  rm -f "$policy_dir/ii-material-theme.json" 2>/dev/null || true

  # Write the policy file (overwrites any prior content, including stale colors)
  policy_path="$policy_dir/$POLICY_FILE"
  if ! printf '%s\n' "$POLICY_JSON" > "$policy_path" 2>/dev/null; then
    _log "[chrome-theme] $label: permission denied writing $policy_path (run once with sudo)"
    continue
  fi
  chmod 666 "$policy_path" 2>/dev/null || true
  any_written=true
  _log "[chrome-theme] $label: wrote $policy_path"

  if [[ -z "$bin" ]]; then
    _log "[chrome-theme] $label: binary not found – policy ready for when browser is installed"
    continue
  fi

  # Only attempt live reload if the browser is actually running.
  # Calling --refresh-platform-policy against a stopped browser opens a new window.
  if ! _is_running "$comms"; then
    _log "[chrome-theme] $label: not running – policy applies on next launch"
    continue
  fi

  if _refresh_policy "$bin" "$label"; then
    continue
  fi

  # Fallback: touching the file wakes Chrome's inotify watcher (~3 min delay)
  touch "$policy_path" 2>/dev/null || true
  _log "[chrome-theme] $label: policy file touched (reloads within ~3 min, or visit chrome://policy → Reload)"
done

if [[ "$any_written" != "true" ]]; then
  _log "[chrome-theme] No writable policy directory found. Pre-create with sudo to enable Chrome theming."
fi
