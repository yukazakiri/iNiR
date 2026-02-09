#!/bin/bash
# Script to reload kitty when theme changes
# Call this from your quickshell theme change hook

# Method 1: Reload config
kitty @ --to unix:/tmp/kitty load-config 2>/dev/null

# Method 2: Alternative - signal all kitty instances
# killall -SIGUSR1 kitty 2>/dev/null

echo "Kitty theme reloaded"
