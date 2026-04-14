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
NEOVIM_COLORS_FILE="$NEOVIM_PLUGIN_DIR/inir_colors.lua"
NEOVIM_THEME_FILE="$NEOVIM_PLUGIN_DIR/inir_theme.lua"

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

  local tmp_colors="${NEOVIM_COLORS_FILE}.tmp"
  cat > "$tmp_colors" <<'LUAEOF'
-- inir color palette module (auto-generated)
local generated_dir = vim.fn.expand("~/.local/state/quickshell/user/generated")

local function read_json(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok or not lines or vim.tbl_isempty(lines) then
    return {}
  end
  local ok_decode, decoded = pcall(vim.json.decode, table.concat(lines, "\n"))
  if not ok_decode or type(decoded) ~= "table" then
    return {}
  end
  return decoded
end

local M = {}

function M.load()
  local palette = read_json(generated_dir .. "/palette.json")
  if vim.tbl_isempty(palette) then
    palette = read_json(generated_dir .. "/colors.json")
  end
  local terminal = read_json(generated_dir .. "/terminal.json")

  local function pick(tbl, key, fallback)
    local value = tbl[key]
    return type(value) == "string" and value ~= "" and value or fallback
  end

  local fg = pick(palette, "on_background", "#E8E1DE")
  local term4 = pick(terminal, "term4", "#B19FB6")
  local term11 = pick(terminal, "term11", "#E2CBB5")

  return {
    bg = pick(palette, "background", "#151311"),
    dark_bg = pick(palette, "surface_container_low", "#1E1B19"),
    darker_bg = pick(palette, "surface_container_lowest", "#100D0C"),
    lighter_bg = pick(palette, "surface_container_highest", "#383432"),
    fg = fg,
    fg_dim = pick(palette, "on_surface_variant", "#CFC4BD"),
    fg_bright = pick(terminal, "term15", fg),
    muted = pick(palette, "outline", "#998F88"),
    red = pick(terminal, "term1", "#CA917F"),
    yellow = term11,
    orange = pick(palette, "primary", "#F3D9C5"),
    green = pick(terminal, "term2", "#BBBB97"),
    cyan = pick(terminal, "term6", "#B5C8AA"),
    blue = term4,
    purple = pick(terminal, "term5", "#BF9EA4"),
    brown = pick(palette, "secondary_container", "#50443B"),
    bright_red = pick(terminal, "term9", "#DDB2A6"),
    bright_yellow = term11,
    bright_green = pick(terminal, "term10", "#D4D4B0"),
    bright_cyan = pick(terminal, "term14", "#D6E9CA"),
    bright_blue = pick(terminal, "term12", "#D2C0D9"),
    bright_purple = pick(terminal, "term13", "#E0BFC6"),
    accent = pick(palette, "primary", term4),
    cursor = fg,
    foreground = fg,
    background = pick(palette, "background", "#151311"),
    selection = pick(palette, "surface_container_high", "#2D2928"),
    selection_foreground = fg,
    selection_background = pick(palette, "surface_container_high", "#2D2928"),
  }
end

return M
LUAEOF

  if [[ -f "$NEOVIM_COLORS_FILE" ]] && cmp -s "$tmp_colors" "$NEOVIM_COLORS_FILE" 2>/dev/null; then
    rm -f "$tmp_colors"
  else
    mv "$tmp_colors" "$NEOVIM_COLORS_FILE"
  fi

  local tmp_theme="${NEOVIM_THEME_FILE}.tmp"
  cat > "$tmp_theme" <<'EOF'
-- inir aether theme (auto-generated)
local colors = require("plugins.inir_colors")

local inir_colors = colors.load()

-- Load user customizations if exists
local user_ok, user_spec = pcall(require, "plugins.99-inir-user")
local user_specs = user_ok and user_spec or {}

local base_specs = {
  {
    "bjarneo/aether.nvim",
    branch = "v3",
    name = "aether",
    priority = 1000,
    opts = {
      colors = inir_colors,
    },
    config = function(_, opts)
      require("aether").setup(opts)
      vim.cmd.colorscheme("aether")
      require("aether.hotreload").setup()
      
      local hl = vim.api.nvim_set_hl
      local c = inir_colors
      
      local function apply_ui()
        hl(0, "Normal", { bg = "NONE", fg = "NONE" })
        hl(0, "NormalNC", { bg = "NONE", fg = "NONE" })
        hl(0, "NormalSB", { bg = "NONE", fg = "NONE" })
        hl(0, "SideBar", { bg = "NONE", fg = "NONE" })
        hl(0, "VertSplit", { bg = "NONE", fg = "NONE" })
        hl(0, "WinSeparator", { bg = "NONE", fg = "NONE" })
        hl(0, "EndOfBuffer", { bg = "NONE", fg = "NONE" })
        hl(0, "StatusLine", { bg = "NONE", fg = "NONE" })
        hl(0, "StatusLineNC", { bg = "NONE", fg = "NONE" })
        hl(0, "FloatBorder", { bg = "NONE", fg = c.muted })
        hl(0, "Folded", { bg = "NONE", fg = c.muted })
        hl(0, "FoldColumn", { bg = "NONE", fg = c.muted })
        hl(0, "SignColumn", { bg = "NONE", fg = "NONE" })
        hl(0, "LineNr", { bg = "NONE", fg = c.muted })
        hl(0, "CursorLineNr", { bg = "NONE", fg = c.fg })
        hl(0, "Pmenu", { bg = c.dark_bg, fg = c.fg })
        hl(0, "PmenuSel", { bg = c.lighter_bg })
        hl(0, "TabLine", { bg = "NONE", fg = "NONE" })
        hl(0, "TabLineFill", { bg = "NONE", fg = "NONE" })
        hl(0, "TabLineSel", { bg = "NONE", fg = "NONE" })
        hl(0, "NvimTreeNormal", { bg = "NONE", fg = "NONE" })
        hl(0, "NvimTreeNormalNC", { bg = "NONE", fg = "NONE" })
        hl(0, "NvimTreeEndOfBuffer", { bg = "NONE", fg = "NONE" })
        hl(0, "NeoTreeNormal", { bg = "NONE", fg = "NONE" })
        hl(0, "NeoTreeNormalNC", { bg = "NONE", fg = "NONE" })
        hl(0, "NeoTreeEndOfBuffer", { bg = "NONE", fg = "NONE" })
      end
      
      apply_ui()
      
      vim.api.nvim_create_autocmd("Colorscheme", { callback = apply_ui })
      vim.api.nvim_create_autocmd({ "VimEnter", "UIEnter" }, {
        callback = function() vim.defer_fn(apply_ui, 100) end,
      })
    end,
  },
  {
    "LazyVim/LazyVim",
    opts = { colorscheme = "aether" },
  },
}

-- Merge user specs into return (LazyVim will handle merging)
if type(user_specs) == "table" and #user_specs > 0 then
  for _, spec in ipairs(user_specs) do
    base_specs[#base_specs + 1] = spec
  end
end

return base_specs
EOF

  if [[ -f "$NEOVIM_THEME_FILE" ]] && cmp -s "$tmp_theme" "$NEOVIM_THEME_FILE" 2>/dev/null; then
    rm -f "$tmp_theme"
    return 0
  fi

  mv "$tmp_theme" "$NEOVIM_THEME_FILE"
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
