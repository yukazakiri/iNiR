#!/usr/bin/env fish
# Script to reload fish theme when wallpaper changes
# This should be called by the ii wallpaper theming system

# Function to send reload command to all running fish shells
function reload_all_fish_themes
    # Find all running fish processes and send them a signal to reload
    # This uses USR1 signal which fish can trap
    
    # Get current user's fish PIDs (excluding this script)
    set -l fish_pids (pgrep -u (whoami) fish | grep -v $fish_pid)
    
    for pid in $fish_pids
        # Send signal to reload theme
        # Fish doesn't have a built-in USR1 handler, so we use a different approach
        # We'll create a flag file that fish checks
        touch /tmp/fish_reload_theme_$pid
    end
    
    # Also reload current shell
    if functions -q ii_reload_fish_theme
        ii_reload_fish_theme
    end
end

# Alternative: Use fish socket to broadcast (if available)
function broadcast_theme_reload
    # Create a marker file that all fish shells check
    echo (date +%s) > ~/.cache/fish_theme_reload
    
    # Notify user
    echo "Fish theme reload triggered for all shells"
end

# Main execution
if test "$argv[1]" = "broadcast"
    broadcast_theme_reload
else
    reload_all_fish_themes
end
