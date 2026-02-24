#!/usr/bin/env bash
# Setup script to configure passwordless sudo for Chromium theme management
# Run this once to enable automatic theme policy updates

set -e

echo "=== Chromium Theme Policy Setup ==="
echo ""
echo "This script configures your system to allow automatic Chrome/Chromium theme updates."
echo ""
echo "Please enter your password when prompted..."
echo ""

sudo -v

POLICY_DIRS=(
    "/etc/chromium/policies/managed"
    "/etc/opt/chrome/policies/managed"
)

for dir in "${POLICY_DIRS[@]}"; do
    if [[ ! -d "$dir" ]]; then
        echo "Creating $dir..."
        sudo mkdir -p "$dir"
    fi
done

SUDOERS_FILE="/etc/sudoers.d/chromium-theme"

echo ""
echo "Creating sudoers rule for passwordless theme policy updates..."
echo "This allows the theme script to write to policy directories without a password."
echo ""

cat << 'EOF' | sudo tee "$SUDOERS_FILE" > /dev/null
# Allow members of wheel group to write Chrome theme policies without password
%wheel ALL=(ALL) NOPASSWD: /bin/mkdir -p /etc/chromium/policies/managed
%wheel ALL=(ALL) NOPASSWD: /bin/mkdir -p /etc/opt/chrome/policies/managed
%wheel ALL=(ALL) NOPASSWD: /usr/bin/tee /etc/chromium/policies/managed/*.json
%wheel ALL=(ALL) NOPASSWD: /usr/bin/tee /etc/opt/chrome/policies/managed/*.json
EOF

sudo chmod 440 "$SUDOERS_FILE"

echo ""
echo "✓ Setup complete!"
echo ""
echo "You can now run the theme script without password prompts."
echo ""
echo "To test:"
echo "  python3 scripts/colors/chromium_theme.py --scss ~/.local/state/quickshell/user/generated/material_colors.scss"
