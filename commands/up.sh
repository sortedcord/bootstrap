# shellcheck shell=bash
# Command: up
# Manually checks for updates and runs the updater if a newer version is found.

# Source libraries if needed
if [ -z "${_LIB_COMMON_SOURCED:-}" ]; then
    _LIB_DIR="${BOOTSTRAP_DIR:-$HOME/.config/bootstrap}/lib"
    # shellcheck source=/dev/null
    . "$_LIB_DIR/common.sh"
fi

require_bash

log_info "Checking for updates..."

local_ver="0.0.0"
version_file="${BOOTSTRAP_DIR:-$HOME/.config/bootstrap}/VERSION"
if [ -f "$version_file" ]; then
    local_ver=$(tr -d '[:space:]' < "$version_file")
fi

base_url="https://git.adityagupta.dev/sortedcord/bootstrap/raw/branch/master"
remote_ver=$(curl -fsSL "$base_url/VERSION" 2>/dev/null)
remote_ver=$(echo "$remote_ver" | tr -d '[:space:]')

if [ -z "$remote_ver" ]; then
    log_error "Failed to fetch remote version. Please check your internet connection."
    exit 1
fi


log_info "Local version:  $local_ver"
log_info "Remote version: $remote_ver"

force_update=false
if [ "${1:-}" = "--force" ] || [ "${1:-}" = "-f" ]; then
    force_update=true
fi

if version_lt "$local_ver" "$remote_ver" || [ "$force_update" = true ]; then
    if [ "$force_update" = true ]; then
        log_info "Force updating..."
    else
        log_info "New version available! Updating..."
    fi

    tmp_bootstrap="$(mktemp)"
    if curl -fsSL "$base_url/bootstrap.sh" -o "$tmp_bootstrap"; then
        # Run bootstrap.sh in foreground
        if bash "$tmp_bootstrap"; then
            # Update the last update timestamp
            date +%s > "${BOOTSTRAP_DIR:-$HOME/.config/bootstrap}/.last_b_update" 2>/dev/null || true
            
            # Update plugin cache
            if [ -f "${BOOTSTRAP_DIR:-$HOME/.config/bootstrap}/lib/plugins.sh" ]; then
                . "${BOOTSTRAP_DIR:-$HOME/.config/bootstrap}/lib/plugins.sh"
                update_plugin_cache
            fi
            
            log_success "Bootstrap CLI successfully updated to version $remote_ver!"
        else
            log_error "Failed to execute bootstrap installer."
            rm -f "$tmp_bootstrap"
            exit 1
        fi
    else
        log_error "Failed to download update installer."
        rm -f "$tmp_bootstrap"
        exit 1
    fi
    rm -f "$tmp_bootstrap"
else
    log_success "You are already on the latest version ($local_ver)."
    log_info "To force reinstall, run: b up --force"
fi
