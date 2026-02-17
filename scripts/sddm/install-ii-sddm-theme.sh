#!/usr/bin/env bash
# Install and configure ii-sddm-theme for iNiR
# Uses the "ii + Matugen Integration" mode from https://github.com/3d3f/ii-sddm-theme
# This script requires sudo access and is called from setup install

set -euo pipefail

THEME_NAME="ii-sddm-theme"
THEME_DIR="/usr/share/sddm/themes/${THEME_NAME}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/sddm-theme"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
II_SDDM_CONFIG_DIR="$CONFIG_DIR/ii-sddm-theme"
MATUGEN_CONFIG="$CONFIG_DIR/matugen/config.toml"

log_info() { echo -e "\033[0;36m[sddm] $*\033[0m"; }
log_ok()   { echo -e "\033[0;32m[sddm] ✓ $*\033[0m"; }
log_warn() { echo -e "\033[0;33m[sddm] $*\033[0m"; }
log_err()  { echo -e "\033[0;31m[sddm] ✗ $*\033[0m"; }

# Check if SDDM is installed
if ! command -v sddm &>/dev/null; then
    log_warn "SDDM not installed. Skipping theme setup."
    log_info "Install with: sudo pacman -S sddm qt6-svg qt6-virtualkeyboard qt6-multimedia-ffmpeg"
    exit 0
fi

run_sudo() {
    sudo "$@"
}

# Clone or update ii-sddm-theme
log_info "Setting up ii-sddm-theme..."
mkdir -p "$CACHE_DIR"

if [[ -d "$CACHE_DIR/ii-sddm-theme/.git" ]]; then
    log_info "Updating existing ii-sddm-theme clone..."
    git -C "$CACHE_DIR/ii-sddm-theme" pull --ff-only 2>/dev/null || true
else
    rm -rf "$CACHE_DIR/ii-sddm-theme"
    git clone -b main --depth=1 https://github.com/3d3f/ii-sddm-theme "$CACHE_DIR/ii-sddm-theme" 2>&1 | tail -1
fi

if [[ ! -d "$CACHE_DIR/ii-sddm-theme" ]]; then
    log_err "Failed to clone ii-sddm-theme"
    exit 1
fi

# Copy iiMatugen integration files to user config
log_info "Setting up ii + Matugen integration..."
mkdir -p "$II_SDDM_CONFIG_DIR"
cp -r "$CACHE_DIR/ii-sddm-theme/iiMatugen/"* "$II_SDDM_CONFIG_DIR/"
chmod +x "$II_SDDM_CONFIG_DIR/sddm-theme-apply.sh"
chmod +x "$II_SDDM_CONFIG_DIR/generate_settings.py" 2>/dev/null || true
chmod +x "$II_SDDM_CONFIG_DIR/change_avatar.sh" 2>/dev/null || true
log_ok "Integration files installed to $II_SDDM_CONFIG_DIR"

# Install theme to system directory
log_info "Installing theme to ${THEME_DIR}..."
run_sudo mkdir -p "$THEME_DIR"
run_sudo cp -rf "$CACHE_DIR/ii-sddm-theme/." "$THEME_DIR/"

# Install fonts
if [[ -d "$THEME_DIR/fonts" ]]; then
    run_sudo cp -r "$THEME_DIR/fonts/"* /usr/share/fonts/ 2>/dev/null || true
    fc-cache -f 2>/dev/null || true
    log_ok "Fonts installed"
fi

# Configure SDDM
log_info "Configuring SDDM..."
if [[ -f "/etc/sddm.conf" ]]; then
    run_sudo cp "/etc/sddm.conf" "/etc/sddm.conf.bak"
fi

run_sudo tee "/etc/sddm.conf" > /dev/null << SDDM_EOF
[General]
InputMethod=qtvirtualkeyboard
GreeterEnvironment=QML2_IMPORT_PATH=/usr/share/sddm/themes/ii-sddm-theme/Components/,QT_IM_MODULE=qtvirtualkeyboard

[Theme]
Current=ii-sddm-theme
SDDM_EOF
log_ok "SDDM configured"

# Set up passwordless sudo for the apply script
log_info "Configuring passwordless sudo for SDDM theme apply..."
local_sudoers="/etc/sudoers.d/sddm-theme-$(whoami)"
echo "$(whoami) ALL=(ALL) NOPASSWD: $II_SDDM_CONFIG_DIR/sddm-theme-apply.sh" | run_sudo tee "$local_sudoers" > /dev/null
run_sudo chmod 0440 "$local_sudoers"
log_ok "Passwordless sudo configured"

# Add matugen template entry for SDDM colors
if [[ -f "$MATUGEN_CONFIG" ]]; then
    if ! grep -q "templates.iisddmtheme" "$MATUGEN_CONFIG" 2>/dev/null; then
        log_info "Adding SDDM template to matugen config..."
        cat >> "$MATUGEN_CONFIG" << MATUGEN_EOF

[templates.iisddmtheme]
input_path = '~/.config/ii-sddm-theme/SddmColors.qml'
output_path = '~/.config/ii-sddm-theme/Colors.qml'
post_hook = 'python3 ~/.config/ii-sddm-theme/generate_settings.py && sudo ~/.config/ii-sddm-theme/sddm-theme-apply.sh &'
MATUGEN_EOF
        log_ok "Matugen template added"
    else
        log_info "Matugen template already exists, skipping"
    fi
else
    log_warn "Matugen config not found at $MATUGEN_CONFIG — add template manually"
fi

# Generate initial settings from ii config
if [[ -f "$CONFIG_DIR/illogical-impulse/config.json" ]] && command -v python3 &>/dev/null; then
    log_info "Generating initial SDDM settings from ii config..."
    python3 "$II_SDDM_CONFIG_DIR/generate_settings.py" 2>/dev/null && log_ok "Settings generated" || log_warn "Settings generation failed (non-fatal)"
fi

# Enable SDDM service
if command -v systemctl &>/dev/null && [[ -d /run/systemd/system ]]; then
    # Check if any display manager is already enabled
    for dm in gdm lightdm lxdm greetd; do
        if systemctl is-enabled "${dm}.service" &>/dev/null 2>&1; then
            log_info "Display manager '${dm}' already enabled. Switching to SDDM..."
            run_sudo systemctl disable "${dm}.service" 2>/dev/null || true
            break
        fi
    done

    run_sudo systemctl enable sddm.service 2>/dev/null || true
    log_ok "SDDM service enabled"
fi

log_ok "ii-sddm-theme installed and configured"
log_info "Theme will auto-update colors when you change wallpaper (via matugen)"
log_info "To customize: edit ~/.config/ii-sddm-theme/ii-sddm.conf"
log_info "To test: sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/ii-sddm-theme"
