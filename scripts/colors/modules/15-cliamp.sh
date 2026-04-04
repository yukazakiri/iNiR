#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/module-runtime.sh"
COLOR_MODULE_ID="cliamp"

SCSS_FILE="$STATE_DIR/user/generated/material_colors.scss"
PALETTE_FILE="$STATE_DIR/user/generated/palette.json"
TERMINAL_FILE="$STATE_DIR/user/generated/terminal.json"
LEGACY_COLORS_FILE="$STATE_DIR/user/generated/colors.json"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CLIAMP_THEMEGEN_BIN="$STATE_DIR/user/generated/bin/inir-cliamp-themegen"

ensure_cliamp_themegen() {
  command -v go &>/dev/null || return 1
  mkdir -p "$STATE_DIR/user/generated/bin"
  if [[ ! -x "$CLIAMP_THEMEGEN_BIN" || "$REPO_ROOT/go.mod" -nt "$CLIAMP_THEMEGEN_BIN" || "$SCRIPT_DIR/cliamp_themegen/main.go" -nt "$CLIAMP_THEMEGEN_BIN" || "$SCRIPT_DIR/themegencommon/common.go" -nt "$CLIAMP_THEMEGEN_BIN" ]]; then
    (cd "$REPO_ROOT" && go build -o "$CLIAMP_THEMEGEN_BIN" ./scripts/colors/cliamp_themegen) >/dev/null 2>&1 || return 1
  fi
  [[ -x "$CLIAMP_THEMEGEN_BIN" ]]
}

main() {
  local enable_terminal enable_cliamp
  enable_terminal=$(config_bool '.appearance.wallpaperTheming.enableTerminal' true)
  [[ "$enable_terminal" == 'true' ]] || exit 0

  enable_cliamp=$(config_bool '.appearance.wallpaperTheming.terminals.cliamp' true)
  [[ "$enable_cliamp" == 'true' ]] || exit 0

  command -v cliamp &>/dev/null || exit 0
  [[ -f "$SCSS_FILE" ]] || exit 0

  if ! ensure_cliamp_themegen; then
    log_module "go compiler unavailable or cliamp theme generator build failed"
    exit 0
  fi

  local colors_file="$PALETTE_FILE"
  [[ -f "$colors_file" ]] || colors_file="$LEGACY_COLORS_FILE"

  "$CLIAMP_THEMEGEN_BIN" \
    --scss "$SCSS_FILE" \
    --colors "$colors_file" \
    --terminal-json "$TERMINAL_FILE" \
    >> "$STATE_DIR/user/generated/cliamp_theme.log" 2>&1 || true
}

main "$@"
