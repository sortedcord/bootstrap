# Command: up
# Manually checks for updates and runs the updater if a newer version is found.

# Source libraries if needed
if [ -z "${_LIB_COMMON_SOURCED:-}" ]; then
    _LIB_DIR="${BOOTSTRAP_DIR:-$HOME/.config/bootstrap}/lib"
    . "$_LIB_DIR/common.sh"
fi

require_bash

log_info "Checking for updates..."

local_ver="0.0.0"
version_file="${BOOTSTRAP_DIR:-$HOME/.config/bootstrap}/VERSION"
if [ -f "$version_file" ]; then
    local_ver=$(cat "$version_file" | tr -d '[:space:]')
fi

base_url="https://git.adityagupta.dev/sortedcord/bootstrap/raw/branch/master"
remote_ver=$(curl -fsSL "$base_url/VERSION" 2>/dev/null || wget -qO- "$base_url/VERSION" 2>/dev/null)
remote_ver=$(echo "$remote_ver" | tr -d '[:space:]')

if [ -z "$remote_ver" ]; then
    log_error "Failed to fetch remote version. Please check your internet connection."
    exit 1
fi

# Version comparison helper
version_lt() {
    [ "$1" = "$2" ] && return 1
    local IFS=.
    local i ver1=($1) ver2=($2)
    for ((i=${#ver1[@]}; i<3; i++)); do ver1[i]=0; done
    for ((i=${#ver2[@]}; i<3; i++)); do ver2[i]=0; done
    for ((i=0; i<3; i++)); do
        if ((10#${ver1[i]} < 10#${ver2[i]})); then
            return 0
        elif ((10#${ver1[i]} > 10#${ver2[i]})); then
            return 1
        fi
    done
    return 1
}

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
    if curl -fsSL "$base_url/bootstrap.sh" -o "$tmp_bootstrap" || wget -qO "$tmp_bootstrap" "$base_url/bootstrap.sh"; then
        # Run bootstrap.sh in foreground
        if bash "$tmp_bootstrap"; then
            # Update the last update timestamp
            date +%s > "${BOOTSTRAP_DIR:-$HOME/.config/bootstrap}/.last_b_update" 2>/dev/null || true
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
