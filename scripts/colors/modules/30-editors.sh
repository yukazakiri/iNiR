#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/module-runtime.sh"
COLOR_MODULE_ID="editors"

SCSS_FILE="$STATE_DIR/user/generated/material_colors.scss"
PALETTE_FILE="$STATE_DIR/user/generated/palette.json"
TERMINAL_FILE="$STATE_DIR/user/generated/terminal.json"
LEGACY_COLORS_FILE="$STATE_DIR/user/generated/colors.json"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VSCODE_THEMEGEN_BIN="$STATE_DIR/user/generated/bin/inir-vscode-themegen"
OPENCODE_THEMEGEN_BIN="$STATE_DIR/user/generated/bin/inir-opencode-themegen"
NEOVIM_CONFIG_DIR="$XDG_CONFIG_HOME/nvim"
NEOVIM_PLUGIN_DIR="$NEOVIM_CONFIG_DIR/lua/plugins"
NEOVIM_THEME_FILE="$NEOVIM_PLUGIN_DIR/neovim.lua"

ensure_vscode_themegen() {
  command -v go &>/dev/null || return 1
  mkdir -p "$STATE_DIR/user/generated/bin"
  if [[ ! -x "$VSCODE_THEMEGEN_BIN" || "$REPO_ROOT/go.mod" -nt "$VSCODE_THEMEGEN_BIN" || "$SCRIPT_DIR/vscode_themegen/main.go" -nt "$VSCODE_THEMEGEN_BIN" || "$SCRIPT_DIR/themegencommon/common.go" -nt "$VSCODE_THEMEGEN_BIN" ]]; then
    (cd "$REPO_ROOT" && go build -o "$VSCODE_THEMEGEN_BIN" ./scripts/colors/vscode_themegen) >/dev/null 2>&1 || return 1
  fi
  [[ -x "$VSCODE_THEMEGEN_BIN" ]]
}

ensure_opencode_themegen() {
  command -v go &>/dev/null || return 1
  mkdir -p "$STATE_DIR/user/generated/bin"
  if [[ ! -x "$OPENCODE_THEMEGEN_BIN" || "$REPO_ROOT/go.mod" -nt "$OPENCODE_THEMEGEN_BIN" || "$SCRIPT_DIR/opencode_themegen/main.go" -nt "$OPENCODE_THEMEGEN_BIN" || "$SCRIPT_DIR/themegencommon/common.go" -nt "$OPENCODE_THEMEGEN_BIN" ]]; then
    (cd "$REPO_ROOT" && go build -o "$OPENCODE_THEMEGEN_BIN" ./scripts/colors/opencode_themegen) >/dev/null 2>&1 || return 1
  fi
  [[ -x "$OPENCODE_THEMEGEN_BIN" ]]
}

json_color() {
  local file_path="$1"
  local key="$2"
  local fallback="$3"
  if [[ -f "$file_path" ]]; then
    jq -r --arg key "$key" --arg fallback "$fallback" '.[$key] // $fallback' "$file_path" 2>/dev/null || printf '%s\n' "$fallback"
  else
    printf '%s\n' "$fallback"
  fi
}

generate_neovim_spec() {
  mkdir -p "$NEOVIM_PLUGIN_DIR"
  local tmp_file="${NEOVIM_THEME_FILE}.tmp"

  # Read dynamic colors from generated palette/terminal JSON files
  local bg dark_bg darker_bg lighter_bg
  local fg dark_fg muted
  local red yellow orange green cyan blue purple brown
  local bright_red bright_yellow bright_green bright_cyan bright_blue bright_purple
  local accent selection selection_bg

  bg=$(json_color "$PALETTE_FILE" "background" "#1E1D2E")
  dark_bg=$(json_color "$PALETTE_FILE" "surface_container_low" "#171623")
  darker_bg=$(json_color "$PALETTE_FILE" "surface_container_lowest" "#0f0f17")
  lighter_bg=$(json_color "$PALETTE_FILE" "surface_container_highest" "#353443")

  fg=$(json_color "$PALETTE_FILE" "on_background" "#DAC1C5")
  dark_fg=$(json_color "$PALETTE_FILE" "on_surface_variant" "#a49194")
  muted=$(json_color "$PALETTE_FILE" "outline" "#6e6e74")

  red=$(json_color "$TERMINAL_FILE" "term1" "#D99F9F")
  yellow=$(json_color "$TERMINAL_FILE" "term11" "#9b9e73")
  orange=$(json_color "$PALETTE_FILE" "primary" "#dfadad")
  green=$(json_color "$TERMINAL_FILE" "term2" "#88a480")
  cyan=$(json_color "$TERMINAL_FILE" "term6" "#99B3CE")
  blue=$(json_color "$TERMINAL_FILE" "term4" "#7B8DAB")
  purple=$(json_color "$TERMINAL_FILE" "term5" "#a28798")
  brown=$(json_color "$PALETTE_FILE" "secondary_container" "#866868")

  bright_red=$(json_color "$TERMINAL_FILE" "term9" "#febcbc")
  bright_yellow=$(json_color "$TERMINAL_FILE" "term11" "#c0c58c")
  bright_green=$(json_color "$TERMINAL_FILE" "term10" "#aacc9c")
  bright_cyan=$(json_color "$TERMINAL_FILE" "term14" "#b6d2f4")
  bright_blue=$(json_color "$TERMINAL_FILE" "term12" "#9eb1d8")
  bright_purple=$(json_color "$TERMINAL_FILE" "term13" "#caaac0")

  accent=$(json_color "$PALETTE_FILE" "primary" "#7B8DAB")
  selection=$(json_color "$PALETTE_FILE" "surface_container_high" "#353443")
  selection_bg=$(json_color "$PALETTE_FILE" "surface_container_high" "#353443")

  cat > "$tmp_file" <<EOF
return {
  {
    "bjarneo/aether.nvim",
    branch = "v3",
    name = "aether",
    priority = 1000,
    opts = {
      colors = {
        bg         = "${bg}",
        dark_bg    = "${dark_bg}",
        darker_bg  = "${darker_bg}",
        lighter_bg = "${lighter_bg}",

        fg         = "${fg}",
        dark_fg    = "${dark_fg}",
        light_fg   = "${fg}",
        bright_fg  = "${fg}",
        muted      = "${muted}",

        red        = "${red}",
        yellow     = "${yellow}",
        orange     = "${orange}",
        green      = "${green}",
        cyan       = "${cyan}",
        blue       = "${blue}",
        purple     = "${purple}",
        brown      = "${brown}",

        bright_red    = "${bright_red}",
        bright_yellow = "${bright_yellow}",
        bright_green  = "${bright_green}",
        bright_cyan   = "${bright_cyan}",
        bright_blue   = "${bright_blue}",
        bright_purple = "${bright_purple}",

        accent               = "${accent}",
        cursor               = "${fg}",
        foreground           = "${fg}",
        background           = "${bg}",
        selection             = "${selection}",
        selection_foreground = "${fg}",
        selection_background = "${selection_bg}",
      },
    },
    config = function(_, opts)
      require("aether").setup(opts)
      vim.cmd.colorscheme("aether")
      -- Re-apply highlights to all active windows/buffers so plugins
      -- like neo-tree, nvim-tree, oil, etc. are fully re-themed.
      vim.schedule(function()
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          local buf = vim.api.nvim_win_get_buf(win)
          if vim.api.nvim_buf_is_valid(buf) then
            pcall(vim.api.nvim_buf_call, buf, function()
              vim.cmd("syntax sync fromstart")
            end)
          end
        end
        vim.cmd("redraw!")
      end)
      require("aether.hotreload").setup()
    end,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "aether",
    },
  },
}
EOF
  if [[ -f "$NEOVIM_THEME_FILE" ]] && cmp -s "$tmp_file" "$NEOVIM_THEME_FILE"; then
    rm -f "$tmp_file"
    return 0
  fi

  mv "$tmp_file" "$NEOVIM_THEME_FILE"
}

apply_code_editors() {
  [[ -f "$SCSS_FILE" ]] || return 0
  local colors_file="$PALETTE_FILE"
  [[ -f "$colors_file" ]] || colors_file="$LEGACY_COLORS_FILE"
  local python_cmd
  python_cmd=$(venv_python)

  local enable_vscode enable_neovim
  enable_vscode=$(config_json 'if .appearance.wallpaperTheming | has("enableVSCode") then .appearance.wallpaperTheming.enableVSCode else true end' true)
  enable_neovim=$(config_json 'if .appearance.wallpaperTheming | has("enableNeovim") then .appearance.wallpaperTheming.enableNeovim else true end' true)

  if [[ "$enable_neovim" == 'true' ]] && [[ -d "$NEOVIM_CONFIG_DIR" || -x "$(command -v nvim 2>/dev/null)" ]]; then
    generate_neovim_spec "$colors_file" "$TERMINAL_FILE"
  fi

  if [[ "$enable_vscode" == 'true' ]]; then
    local enabled_forks=()
    local disabled_forks=()
    if [[ -f "$CONFIG_FILE" ]] && command -v jq >/dev/null 2>&1; then
      local editors_config
      editors_config=$(jq -r '.appearance.wallpaperTheming.vscodeEditors // {}' "$CONFIG_FILE" 2>/dev/null || echo '{}')

      _check_vscode_fork() {
        local jq_key="$1" fork_key="$2" config_dir="$3"
        if [[ $(echo "$editors_config" | jq -r ".$jq_key // true") == 'true' ]] && [[ -d "$config_dir" ]]; then
          enabled_forks+=("$fork_key")
        elif [[ -d "$config_dir" ]]; then
          disabled_forks+=("$fork_key")
        fi
      }

      _check_vscode_fork code code "$HOME/.config/Code"
      _check_vscode_fork codium codium "$HOME/.config/VSCodium"
      _check_vscode_fork codeOss code-oss "$HOME/.config/Code - OSS"
      _check_vscode_fork codeInsiders code-insiders "$HOME/.config/Code - Insiders"
      _check_vscode_fork cursor cursor "$HOME/.config/Cursor"
      _check_vscode_fork windsurf windsurf "$HOME/.config/Windsurf"
      _check_vscode_fork windsurfNext windsurf-next "$HOME/.config/Windsurf - Next"
      _check_vscode_fork qoder qoder "$HOME/.config/Qoder"
      _check_vscode_fork antigravity antigravity "$HOME/.config/Antigravity"
      _check_vscode_fork positron positron "$HOME/.config/Positron"
      _check_vscode_fork voidEditor void "$HOME/.config/Void"
      _check_vscode_fork melty melty "$HOME/.config/Melty"
      _check_vscode_fork pearai pearai "$HOME/.config/PearAI"
      _check_vscode_fork aide aide "$HOME/.config/Aide"

      unset -f _check_vscode_fork
    fi

    if [[ ${#enabled_forks[@]} -gt 0 ]]; then
      if ensure_vscode_themegen; then
        local vscode_cmd=("$VSCODE_THEMEGEN_BIN" "--colors" "$colors_file" "--terminal-json" "$TERMINAL_FILE" "--scss" "$SCSS_FILE")
        for fork in "${enabled_forks[@]}"; do
          vscode_cmd+=("--forks" "$fork")
        done
        "${vscode_cmd[@]}" >> "$STATE_DIR/user/generated/code_editor_themes.log" 2>&1 || true
      else
        "$python_cmd" "$SCRIPT_DIR/generate_terminal_configs.py" --scss "$SCSS_FILE" --colors "$colors_file" --terminal-json "$TERMINAL_FILE" --vscode --vscode-forks "${enabled_forks[@]}" >> "$STATE_DIR/user/generated/code_editor_themes.log" 2>&1 || true
      fi
    fi

    # Strip theme from individually disabled forks
    if [[ ${#disabled_forks[@]} -gt 0 ]]; then
      if ensure_vscode_themegen; then
        local strip_cmd=("$VSCODE_THEMEGEN_BIN" "--strip")
        for fork in "${disabled_forks[@]}"; do
          strip_cmd+=("--forks" "$fork")
        done
        "${strip_cmd[@]}" >> "$STATE_DIR/user/generated/code_editor_themes.log" 2>&1 || true
      else
        "$python_cmd" "$SCRIPT_DIR/vscode/theme_generator.py" --strip --forks "${disabled_forks[@]}" >> "$STATE_DIR/user/generated/code_editor_themes.log" 2>&1 || true
      fi
    fi
  else
    # VSCode theming globally disabled — strip all installed forks
    if ensure_vscode_themegen; then
      "$VSCODE_THEMEGEN_BIN" --strip >> "$STATE_DIR/user/generated/code_editor_themes.log" 2>&1 || true
    else
      "$python_cmd" "$SCRIPT_DIR/vscode/theme_generator.py" --strip >> "$STATE_DIR/user/generated/code_editor_themes.log" 2>&1 || true
    fi
  fi

  if command -v opencode &>/dev/null; then
    local enable_opencode
    enable_opencode=$(config_bool '.appearance.wallpaperTheming.enableOpenCode' true)
    if [[ "$enable_opencode" == 'true' ]]; then
      if ensure_opencode_themegen; then
        "$OPENCODE_THEMEGEN_BIN" "$SCSS_FILE" "$colors_file" "$TERMINAL_FILE" >> "$STATE_DIR/user/generated/code_editor_themes.log" 2>&1 || true
      else
        "$python_cmd" "$SCRIPT_DIR/opencode/theme_generator.py" "$SCSS_FILE" "$colors_file" "$TERMINAL_FILE" >> "$STATE_DIR/user/generated/code_editor_themes.log" 2>&1 || true
      fi
    fi
  fi
}

main() {
  apply_code_editors
}

main "$@"
