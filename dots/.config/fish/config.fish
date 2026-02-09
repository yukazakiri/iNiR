# Fish Shell Configuration
# Source CachyOS defaults
source /usr/share/cachyos-fish-config/cachyos-config.fish

# ii Wallpaper Theming Support
# This loads dynamic colors from kitty theme for syntax highlighting
if test -f ~/.config/fish/conf.d/ii-theme.fish
    source ~/.config/fish/conf.d/ii-theme.fish
end

# Custom greeting (optional)
# function fish_greeting
#     # Add your custom greeting here
# end

# Function to reload theme when wallpaper changes
# This can be called from wallpaper change scripts
function reload_fish_theme
    if functions -q ii_reload_fish_theme
        ii_reload_fish_theme
    end
end
