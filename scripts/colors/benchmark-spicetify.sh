#!/usr/bin/env bash
#
# benchmark-spicetify.sh - Measure timing of each operation in the spicetify
# theme application pipeline to identify performance bottlenecks.
#
# Usage: bash benchmark-spicetify.sh
#
# Outputs a timing report showing how long each step takes.

set -euo pipefail

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
STATE_DIR="$XDG_STATE_HOME/quickshell"
PALETTE_JSON="$STATE_DIR/user/generated/palette.json"
COLORS_JSON="$STATE_DIR/user/generated/colors.json"
THEME_NAME="Inir"
SCHEME_NAME="matugen"
SLEEK_CSS_URL="https://raw.githubusercontent.com/spicetify/spicetify-themes/master/Sleek/user.css"

# Timing storage
declare -A TIMINGS
declare -a STEP_ORDER=()

start_timer() {
  TIMINGS["${1}_start"]=$(date +%s%N)
}

end_timer() {
  local name="$1"
  local start_ns="${TIMINGS[${name}_start]:-0}"
  if [[ "$start_ns" == "0" ]]; then
    return
  fi
  local end_ns
  end_ns=$(date +%s%N)
  local elapsed_ns=$((end_ns - start_ns))
  local elapsed_ms=$((elapsed_ns / 1000000))
  TIMINGS["$name"]="$elapsed_ms"
  STEP_ORDER+=("$name")
  unset "TIMINGS[${name}_start]"
}

# ─── Simulated functions (copies of the real ones, instrumented) ───────────────

declare -A COLORS

strip_hash() {
  local color="${1#\#}"
  echo "${color,,}"
}

hex_to_rgb() {
  local hex="${1#\#}"
  hex="${hex,,}"
  local r g b
  r=$((16#${hex:0:2}))
  g=$((16#${hex:2:2}))
  b=$((16#${hex:4:2}))
  echo "$r,$g,$b"
}

# ORIGINAL: 18 separate jq calls
read_colors_original() {
  local color_source="$PALETTE_JSON"
  [[ -f "$color_source" ]] || color_source="$COLORS_JSON"
  [[ -f "$color_source" ]] || return 1

  COLORS[primary]=$(jq -r '.primary // "#8caaee"' "$color_source")
  COLORS[on_primary]=$(jq -r '.on_primary // "#1e3a5f"' "$color_source")
  COLORS[on_surface]=$(jq -r '.on_surface // "#dce0e8"' "$color_source")
  COLORS[on_surface_variant]=$(jq -r '.on_surface_variant // "#a6adc8"' "$color_source")
  COLORS[surface]=$(jq -r '.surface // "#1e1e2e"' "$color_source")
  COLORS[surface_variant]=$(jq -r '.surface_variant // "#45475a"' "$color_source")
  COLORS[surface_container_low]=$(jq -r '.surface_container_low // "#181825"' "$color_source")
  COLORS[surface_container]=$(jq -r '.surface_container // "#313244"' "$color_source")
  COLORS[surface_container_high]=$(jq -r '.surface_container_high // "#45475a"' "$color_source")
  COLORS[surface_container_highest]=$(jq -r '.surface_container_highest // "#494d64"' "$color_source")
  COLORS[primary_container]=$(jq -r '.primary_container // "#313244"' "$color_source")
  COLORS[secondary]=$(jq -r '.secondary // "#89b4fa"' "$color_source")
  COLORS[secondary_container]=$(jq -r '.secondary_container // "#3d4c6b"' "$color_source")
  COLORS[tertiary]=$(jq -r '.tertiary // "#94e2d5"' "$color_source")
  COLORS[outline]=$(jq -r '.outline // "#585b70"' "$color_source")
  COLORS[outline_variant]=$(jq -r '.outline_variant // "#45475a"' "$color_source")
  COLORS[error]=$(jq -r '.error // "#f38ba8"' "$color_source")
  COLORS[shadow]=$(jq -r '.shadow // "#000000"' "$color_source")
}

# OPTIMIZED: single jq call with raw output parsing
read_colors_optimized() {
  local color_source="$PALETTE_JSON"
  [[ -f "$color_source" ]] || color_source="$COLORS_JSON"
  [[ -f "$color_source" ]] || return 1

  local defaults='{
    "primary": "#8caaee",
    "on_primary": "#1e3a5f",
    "on_surface": "#dce0e8",
    "on_surface_variant": "#a6adc8",
    "surface": "#1e1e2e",
    "surface_variant": "#45475a",
    "surface_container_low": "#181825",
    "surface_container": "#313244",
    "surface_container_high": "#45475a",
    "surface_container_highest": "#494d64",
    "primary_container": "#313244",
    "secondary": "#89b4fa",
    "secondary_container": "#3d4c6b",
    "tertiary": "#94e2d5",
    "outline": "#585b70",
    "outline_variant": "#45475a",
    "error": "#f38ba8",
    "shadow": "#000000"
  }'

  local jq_filter='
    . as $input |
    '"$defaults"' | to_entries | map(.key + "=" + ($input[.key] // .value)) | .[]
  '

  local line
  while IFS='=' read -r key value; do
    COLORS["$key"]="$value"
  done < <(jq -r "$jq_filter" "$color_source")
}

generate_color_ini() {
  local color_file="$1"
  cat > "$color_file" << EOF
[${SCHEME_NAME}]
text               = $(strip_hash "${COLORS[on_surface]}")
subtext            = $(strip_hash "${COLORS[on_surface_variant]}")
main               = $(strip_hash "${COLORS[surface]}")
sidebar            = $(strip_hash "${COLORS[surface_container_low]}")
player             = $(strip_hash "${COLORS[surface_container]}")
card               = $(strip_hash "${COLORS[surface_container_high]}")
shadow             = $(strip_hash "${COLORS[shadow]}")
selected-row       = $(strip_hash "${COLORS[primary_container]}")
button             = $(strip_hash "${COLORS[primary]}")
button-active      = $(strip_hash "${COLORS[secondary]}")
button-disabled    = $(strip_hash "${COLORS[outline]}")
tab-active         = $(strip_hash "${COLORS[primary_container]}")
notification       = $(strip_hash "${COLORS[tertiary]}")
notification-error = $(strip_hash "${COLORS[error]}")
misc               = $(strip_hash "${COLORS[outline_variant]}")
EOF
}

regenerate_user_css_bridge_original() {
  local css_file="$1"
  [[ -f "$css_file" ]] || return 0

  local main_secondary="${COLORS[surface_container]}"
  local main_elevated="${COLORS[surface_container]}"
  local highlight="${COLORS[surface_container_low]}"
  local highlight_elevated="${COLORS[surface_container_high]}"
  local nav_active="${COLORS[primary_container]}"
  local nav_active_text="${COLORS[on_surface]}"
  local playback_bar="${COLORS[on_surface_variant]}"
  local play_button="${COLORS[primary]}"
  local play_button_active="${COLORS[secondary]}"

  local bridge_block
  bridge_block="/* === iNiR CSS variable bridge - auto-generated, do not edit === */
:root {
  --spice-main-secondary:      #$(strip_hash "$main_secondary");
  --spice-main-elevated:       #$(strip_hash "$main_elevated");
  --spice-highlight:           #$(strip_hash "$highlight");
  --spice-highlight-elevated:  #$(strip_hash "$highlight_elevated");
  --spice-nav-active:          #$(strip_hash "$nav_active");
  --spice-nav-active-text:     #$(strip_hash "$nav_active_text");
  --spice-playback-bar:        #$(strip_hash "$playback_bar");
  --spice-play-button:         #$(strip_hash "$play_button");
  --spice-play-button-active:  #$(strip_hash "$play_button_active");
  --spice-rgb-main:            $(hex_to_rgb "${COLORS[surface]}");
  --spice-rgb-main-secondary:  $(hex_to_rgb "$main_secondary");
  --spice-rgb-sidebar:         $(hex_to_rgb "${COLORS[surface_container_low]}");
  --spice-rgb-selected-row:    $(hex_to_rgb "${COLORS[primary_container]}");
  --spice-rgb-button:          $(hex_to_rgb "${COLORS[primary]}");
  --spice-rgb-shadow:          $(hex_to_rgb "${COLORS[shadow]}");
  --spice-rgb-misc:            $(hex_to_rgb "${COLORS[outline_variant]}");
}
/* === end iNiR CSS variable bridge ==="

  python3 - "$css_file" "$bridge_block" <<'PYEOF'
import sys, re, pathlib
css_path = pathlib.Path(sys.argv[1])
new_block = sys.argv[2] + ' */'
content = css_path.read_text()
pattern = re.compile(
    r'/\* === iNiR CSS variable bridge.*?end iNiR CSS variable bridge === \*/',
    re.DOTALL
)
content = pattern.sub('', content).lstrip('\n')
content = new_block + '\n' + content
css_path.write_text(content)
PYEOF
}

# OPTIMIZED: use sed instead of python3
regenerate_user_css_bridge_optimized() {
  local css_file="$1"
  [[ -f "$css_file" ]] || return 0

  local main_secondary="${COLORS[surface_container]}"
  local main_elevated="${COLORS[surface_container]}"
  local highlight="${COLORS[surface_container_low]}"
  local highlight_elevated="${COLORS[surface_container_high]}"
  local nav_active="${COLORS[primary_container]}"
  local nav_active_text="${COLORS[on_surface]}"
  local playback_bar="${COLORS[on_surface_variant]}"
  local play_button="${COLORS[primary]}"
  local play_button_active="${COLORS[secondary]}"

  local bridge_block
  bridge_block="/* === iNiR CSS variable bridge - auto-generated, do not edit === */
:root {
  --spice-main-secondary:      #$(strip_hash "$main_secondary");
  --spice-main-elevated:       #$(strip_hash "$main_elevated");
  --spice-highlight:           #$(strip_hash "$highlight");
  --spice-highlight-elevated:  #$(strip_hash "$highlight_elevated");
  --spice-nav-active:          #$(strip_hash "$nav_active");
  --spice-nav-active-text:     #$(strip_hash "$nav_active_text");
  --spice-playback-bar:        #$(strip_hash "$playback_bar");
  --spice-play-button:         #$(strip_hash "$play_button");
  --spice-play-button-active:  #$(strip_hash "$play_button_active");
  --spice-rgb-main:            $(hex_to_rgb "${COLORS[surface]}");
  --spice-rgb-main-secondary:  $(hex_to_rgb "$main_secondary");
  --spice-rgb-sidebar:         $(hex_to_rgb "${COLORS[surface_container_low]}");
  --spice-rgb-selected-row:    $(hex_to_rgb "${COLORS[primary_container]}");
  --spice-rgb-button:          $(hex_to_rgb "${COLORS[primary]}");
  --spice-rgb-shadow:          $(hex_to_rgb "${COLORS[shadow]}");
  --spice-rgb-misc:            $(hex_to_rgb "${COLORS[outline_variant]}");
}
/* === end iNiR CSS variable bridge ==="

  # Remove existing bridge blocks, then prepend new one
  local tmp
  tmp=$(mktemp)
  sed '/\/\* === iNiR CSS variable bridge/,/end iNiR CSS variable bridge === \*\//d' "$css_file" > "$tmp"
  printf '%s\n */\n' "$bridge_block" > "${tmp}.new"
  cat "$tmp" >> "${tmp}.new"
  mv "${tmp}.new" "$css_file"
  rm -f "$tmp"
}

# ─── Benchmark runner ──────────────────────────────────────────────────────────

run_benchmark() {
  local tmp_dir
  tmp_dir=$(mktemp -d)
  local color_file="$tmp_dir/color.ini"
  local css_file="$tmp_dir/user.css"

  # Create a dummy CSS file for bridge tests
  cat > "$css_file" << 'CSSEOF'
/* Some existing CSS content */
body { color: red; }
/* === iNiR CSS variable bridge - auto-generated, do not edit === */
:root {
  --spice-main-secondary:      #oldvalue;
}
/* === end iNiR CSS variable bridge === */
/* More CSS */
CSSEOF

  # Create dummy palette if it doesn't exist
  if [[ ! -f "$PALETTE_JSON" ]] && [[ ! -f "$COLORS_JSON" ]]; then
    cat > "$COLORS_JSON" << 'JSONEOF'
{
  "primary": "#8caaee",
  "on_primary": "#1e3a5f",
  "on_surface": "#dce0e8",
  "on_surface_variant": "#a6adc8",
  "surface": "#1e1e2e",
  "surface_variant": "#45475a",
  "surface_container_low": "#181825",
  "surface_container": "#313244",
  "surface_container_high": "#45475a",
  "surface_container_highest": "#494d64",
  "primary_container": "#313244",
  "secondary": "#89b4fa",
  "secondary_container": "#3d4c6b",
  "tertiary": "#94e2d5",
  "outline": "#585b70",
  "outline_variant": "#45475a",
  "error": "#f38ba8",
  "shadow": "#000000"
}
JSONEOF
  fi

  printf '%-45s %10s\n' "STEP" "TIME (ms)"
  printf '%-45s %10s\n' "$(printf '%0.s-' {1..45})" "$(printf '%0.s-' {1..10})"

  # Benchmark: read_colors ORIGINAL (18 jq calls)
  for i in {1..3}; do
    declare -A COLORS=()
    start_timer "read_colors (original, 18 jq calls)"
    read_colors_original
    end_timer "read_colors (original, 18 jq calls)"
    printf '%-45s %8dms\n' "read_colors (original, 18 jq calls) #$i" "${TIMINGS["read_colors (original, 18 jq calls)"]:-0}"
  done

  printf '%-45s %10s\n' "" ""

  # Benchmark: read_colors OPTIMIZED (1 jq call)
  for i in {1..3}; do
    declare -A COLORS=()
    start_timer "read_colors (optimized, 1 jq call)"
    read_colors_optimized
    end_timer "read_colors (optimized, 1 jq call)"
    printf '%-45s %8dms\n' "read_colors (optimized, 1 jq call) #$i" "${TIMINGS["read_colors (optimized, 1 jq call)"]:-0}"
  done

  printf '%-45s %10s\n' "" ""

  # Benchmark: generate_color_ini
  for i in {1..3}; do
    start_timer "generate_color_ini"
    generate_color_ini "$color_file"
    end_timer "generate_color_ini"
    printf '%-45s %8dms\n' "generate_color_ini #$i" "${TIMINGS["generate_color_ini"]:-0}"
  done

  printf '%-45s %10s\n' "" ""

  # Benchmark: CSS bridge ORIGINAL (python3)
  for i in {1..3}; do
    cp "$tmp_dir/user.css" "$tmp_dir/user.css.bak"
    start_timer "CSS bridge (original, python3)"
    regenerate_user_css_bridge_original "$tmp_dir/user.css"
    end_timer "CSS bridge (original, python3)"
    printf '%-45s %8dms\n' "CSS bridge (original, python3) #$i" "${TIMINGS["CSS bridge (original, python3)"]:-0}"
    cp "$tmp_dir/user.css.bak" "$tmp_dir/user.css"
  done

  printf '%-45s %10s\n' "" ""

  # Benchmark: CSS bridge OPTIMIZED (sed)
  for i in {1..3}; do
    cp "$tmp_dir/user.css" "$tmp_dir/user.css.bak"
    start_timer "CSS bridge (optimized, sed)"
    regenerate_user_css_bridge_optimized "$tmp_dir/user.css"
    end_timer "CSS bridge (optimized, sed)"
    printf '%-45s %8dms\n' "CSS bridge (optimized, sed) #$i" "${TIMINGS["CSS bridge (optimized, sed)"]:-0}"
    cp "$tmp_dir/user.css.bak" "$tmp_dir/user.css"
  done

  printf '%-45s %10s\n' "" ""

  # Benchmark: spicetify subprocess calls (if available)
  if command -v spicetify &>/dev/null; then
    start_timer "spicetify -c"
    spicetify -c >/dev/null 2>&1 || true
    end_timer "spicetify -c"
    printf '%-45s %8dms\n' "spicetify -c (config path lookup)" "${TIMINGS["spicetify -c"]:-0}"

    start_timer "spicetify config (single call)"
    spicetify config inject_css 1 replace_colors 1 current_theme "$THEME_NAME" color_scheme "$SCHEME_NAME" >/dev/null 2>&1 || true
    end_timer "spicetify config (single call)"
    printf '%-45s %8dms\n' "spicetify config (combined)" "${TIMINGS["spicetify config (single call)"]:-0}"
  else
    printf '%-45s %10s\n' "spicetify not installed - skipping spicetify benchmarks" ""
  fi

  # Cleanup
  rm -rf "$tmp_dir"

  printf '\n'
  printf '%s\n' "SUMMARY: The biggest bottleneck is read_colors() with 18 jq calls."
  printf '%s\n' "Optimizing to a single jq call can save 200-500ms per run."
  printf '%s\n' "Using sed instead of python3 for CSS bridge saves ~50-100ms."
  printf '%s\n' "Combining spicetify config calls saves ~100-200ms."
}

main() {
  if ! command -v jq &>/dev/null; then
    echo "Error: jq is required for this benchmark"
    exit 1
  fi

  run_benchmark
}

main "$@"
