# Snapshot system for ii-niri
# Time-machine style backups before updates
# This script is meant to be sourced.

# shellcheck shell=bash

SNAPSHOTS_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/snapshots"
MAX_SNAPSHOTS=10

# Paths to snapshot
SNAPSHOT_PATHS=(
    "${XDG_CONFIG_HOME}/quickshell/ii"
    "${XDG_CONFIG_HOME}/illogical-impulse/config.json"
    "${XDG_CONFIG_HOME}/niri/config.kdl"
)

###############################################################################
# Create snapshot
###############################################################################
create_snapshot() {
    local reason="${1:-manual}"
    local description="${2:-}"
    local commit_after="${3:-}"
    
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local commit_before=$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo "unknown")
    local version_before=$(get_installed_version 2>/dev/null || echo "unknown")
    local snapshot_id="${timestamp}-${commit_before}"
    local snapshot_dir="${SNAPSHOTS_DIR}/${snapshot_id}"
    
    mkdir -p "$snapshot_dir"
    
    # Copy QML code
    if [[ -d "${XDG_CONFIG_HOME}/quickshell/ii" ]]; then
        rsync -a --exclude='.ii-manifest' "${XDG_CONFIG_HOME}/quickshell/ii/" "${snapshot_dir}/ii/"
    fi
    
    # Copy user config
    if [[ -f "${XDG_CONFIG_HOME}/illogical-impulse/config.json" ]]; then
        cp "${XDG_CONFIG_HOME}/illogical-impulse/config.json" "${snapshot_dir}/"
    fi
    
    # Copy niri config
    if [[ -f "${XDG_CONFIG_HOME}/niri/config.kdl" ]]; then
        cp "${XDG_CONFIG_HOME}/niri/config.kdl" "${snapshot_dir}/niri-config.kdl"
    fi
    
    # Copy migrations state
    if [[ -f "${XDG_CONFIG_HOME}/illogical-impulse/migrations.json" ]]; then
        cp "${XDG_CONFIG_HOME}/illogical-impulse/migrations.json" "${snapshot_dir}/"
    fi
    
    # Create metadata
    cat > "${snapshot_dir}/snapshot.json" << EOF
{
  "id": "${snapshot_id}",
  "created_at": "$(date -Iseconds)",
  "commit_before": "${commit_before}",
  "commit_after": "${commit_after:-pending}",
  "version_before": "${version_before}",
  "reason": "${reason}",
  "description": "${description:-Auto snapshot before ${reason}}"
}
EOF
    
    # Cleanup old snapshots
    cleanup_old_snapshots
    
    echo "$snapshot_id"
}

###############################################################################
# List snapshots
###############################################################################
list_snapshots() {
    [[ ! -d "$SNAPSHOTS_DIR" ]] && return
    
    for dir in $(ls -1t "$SNAPSHOTS_DIR" 2>/dev/null); do
        local meta="${SNAPSHOTS_DIR}/${dir}/snapshot.json"
        [[ -f "$meta" ]] && echo "$dir"
    done
}

show_snapshots() {
    local snapshots=($(list_snapshots))
    
    if [[ ${#snapshots[@]} -eq 0 ]]; then
        echo -e "${STY_YELLOW}No snapshots found${STY_RST}"
        return 1
    fi
    
    echo -e "${STY_CYAN}${STY_BOLD}Available Snapshots${STY_RST}"
    echo ""
    
    local i=1
    for snap in "${snapshots[@]}"; do
        local meta="${SNAPSHOTS_DIR}/${snap}/snapshot.json"
        if [[ -f "$meta" ]] && command -v jq &>/dev/null; then
            local date=$(jq -r '.created_at' "$meta" | cut -d'T' -f1,2 | tr 'T' ' ')
            local commit=$(jq -r '.commit_before' "$meta")
            local reason=$(jq -r '.reason' "$meta")
            local desc=$(jq -r '.description' "$meta")
            echo -e "  ${STY_BOLD}[$i]${STY_RST} ${date} (${commit}) - ${reason}"
            echo -e "      ${STY_FAINT}${desc}${STY_RST}"
        else
            echo -e "  ${STY_BOLD}[$i]${STY_RST} ${snap}"
        fi
        ((i++))
    done
    echo ""
}

###############################################################################
# Restore snapshot
###############################################################################
restore_snapshot() {
    local snapshot_id="$1"
    local snapshot_dir="${SNAPSHOTS_DIR}/${snapshot_id}"
    
    if [[ ! -d "$snapshot_dir" ]]; then
        log_error "Snapshot not found: $snapshot_id"
        return 1
    fi
    
    local meta="${snapshot_dir}/snapshot.json"
    local commit_before=""
    if [[ -f "$meta" ]] && command -v jq &>/dev/null; then
        commit_before=$(jq -r '.commit_before' "$meta")
    fi
    
    echo -e "${STY_CYAN}Restoring snapshot: ${snapshot_id}${STY_RST}"
    
    # Stop shell
    qs kill -c ii &>/dev/null || true
    
    # Restore QML code
    if [[ -d "${snapshot_dir}/ii" ]]; then
        log_info "Restoring QML code..."
        rsync -a --delete "${snapshot_dir}/ii/" "${XDG_CONFIG_HOME}/quickshell/ii/"
    fi
    
    # Restore user config
    if [[ -f "${snapshot_dir}/config.json" ]]; then
        log_info "Restoring user config..."
        cp "${snapshot_dir}/config.json" "${XDG_CONFIG_HOME}/illogical-impulse/"
    fi
    
    # Restore niri config
    if [[ -f "${snapshot_dir}/niri-config.kdl" ]]; then
        log_info "Restoring niri config..."
        cp "${snapshot_dir}/niri-config.kdl" "${XDG_CONFIG_HOME}/niri/config.kdl"
    fi
    
    # Restore migrations state
    if [[ -f "${snapshot_dir}/migrations.json" ]]; then
        cp "${snapshot_dir}/migrations.json" "${XDG_CONFIG_HOME}/illogical-impulse/"
    fi
    
    # Checkout git to that commit (stay on branch if possible)
    if [[ -n "$commit_before" && "$commit_before" != "unknown" ]]; then
        log_info "Checking out commit ${commit_before}..."
        # Try to find a branch containing this commit to avoid detached HEAD
        local branch=$(git -C "$REPO_ROOT" branch --contains "$commit_before" 2>/dev/null | grep -v "HEAD detached" | head -1 | sed 's/^[* ]*//')
        if [[ -n "$branch" ]]; then
            git -C "$REPO_ROOT" checkout "$branch" 2>/dev/null || true
            git -C "$REPO_ROOT" reset --hard "$commit_before" 2>/dev/null || true
        else
            git -C "$REPO_ROOT" checkout "$commit_before" 2>/dev/null || true
        fi
    fi
    
    # Update version tracking
    local version=$(jq -r '.version_before // "unknown"' "$meta" 2>/dev/null || echo "unknown")
    set_installed_version "$version" "$commit_before" "rollback"
    
    # Restart shell
    log_info "Starting shell..."
    nohup qs -c ii >/dev/null 2>&1 &
    disown
    
    echo -e "${STY_GREEN}✓ Snapshot restored${STY_RST}"
}

###############################################################################
# Interactive rollback
###############################################################################
run_rollback() {
    local snapshots=($(list_snapshots))
    
    if [[ ${#snapshots[@]} -eq 0 ]]; then
        echo -e "${STY_YELLOW}No snapshots available${STY_RST}"
        return 1
    fi
    
    show_snapshots
    
    echo -e "Enter snapshot number to restore (or 'q' to quit):"
    read -p ">>> " choice
    
    [[ "$choice" == "q" || -z "$choice" ]] && return 0
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#snapshots[@]} ]]; then
        local idx=$((choice - 1))
        local snapshot_id="${snapshots[$idx]}"
        
        echo ""
        echo -e "${STY_YELLOW}This will restore your system to the state before:${STY_RST}"
        local meta="${SNAPSHOTS_DIR}/${snapshot_id}/snapshot.json"
        if [[ -f "$meta" ]]; then
            jq -r '"  Commit: \(.commit_before)\n  Reason: \(.reason)\n  Date: \(.created_at)"' "$meta"
        fi
        echo ""
        read -p "Continue? [y/N] " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            restore_snapshot "$snapshot_id"
        fi
    else
        echo -e "${STY_RED}Invalid choice${STY_RST}"
    fi
}

###############################################################################
# Cleanup
###############################################################################
cleanup_old_snapshots() {
    [[ ! -d "$SNAPSHOTS_DIR" ]] && return
    
    local snapshots=($(list_snapshots))
    local count=${#snapshots[@]}
    
    if [[ $count -gt $MAX_SNAPSHOTS ]]; then
        local to_delete=$((count - MAX_SNAPSHOTS))
        for snap in "${snapshots[@]: -$to_delete}"; do
            rm -rf "${SNAPSHOTS_DIR}/${snap}"
        done
    fi
}

###############################################################################
# Check remote for updates
###############################################################################
check_remote_updates() {
    if [[ ! -d "${REPO_ROOT}/.git" ]]; then
        return 1
    fi
    
    # Fetch silently
    git -C "$REPO_ROOT" fetch origin --quiet 2>/dev/null || return 1
    
    local branch=$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)
    [[ -z "$branch" || "$branch" == "HEAD" ]] && branch="main"
    
    local local_commit=$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null)
    local remote_commit=$(git -C "$REPO_ROOT" rev-parse "origin/${branch}" 2>/dev/null)
    
    if [[ "$local_commit" == "$remote_commit" ]]; then
        return 1  # No updates
    fi
    
    return 0  # Updates available
}

show_pending_commits() {
    local branch=$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)
    [[ -z "$branch" || "$branch" == "HEAD" ]] && branch="main"
    local remote="origin/${branch}"
    
    echo -e "${STY_CYAN}New commits available:${STY_RST}"
    echo ""
    git -C "$REPO_ROOT" log --oneline HEAD..${remote} 2>/dev/null | head -10 | while read -r line; do
        echo -e "  ${STY_GREEN}+${STY_RST} $line"
    done
    echo ""
}

get_remote_commit() {
    local branch=$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)
    [[ -z "$branch" || "$branch" == "HEAD" ]] && branch="main"
    git -C "$REPO_ROOT" rev-parse --short "origin/${branch}" 2>/dev/null || echo "unknown"
}
