#!/usr/bin/env bash
# Tool: bat
# DisplayName: Bat
# Description: Install Bat (alternative to cat) and configure alias
# Strategy: binary
#
# Bat Installer Script
#

# Prevent standalone execution
if [ -z "${_LIB_COMMON_SOURCED:-}" ]; then
    echo "Error: This script must be run through the 'b' CLI." >&2
    exit 1
fi

set -euo pipefail

TMP_DIR="$(make_temp_dir)"
cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

install_bat() {
    if has_command bat; then
        if ! confirm "Bat is already installed. Reinstall/Upgrade?"; then
            log_info "Skipping Bat installation."
            return
        fi
    fi

    local arch
    arch=$(detect_arch)
    local target=""
    case "$arch" in
        x86_64) target="x86_64-unknown-linux-gnu" ;;
        arm64)  target="aarch64-unknown-linux-gnu" ;;
        *)      log_error "Unsupported architecture: $arch"; exit 1 ;;
    esac

    log_info "Fetching latest Bat version from GitHub..."
    local latest_tag=""
    latest_tag=$(github_get_latest_release "sharkdp/bat")

    if [ -z "$latest_tag" ]; then
        latest_tag="v0.26.1"
        log_warn "Failed to fetch latest version from GitHub. Falling back to: $latest_tag"
    else
        log_info "Latest Bat version found: $latest_tag"
    fi

    log_info "Downloading Bat ${latest_tag}..."
    local archive="$TMP_DIR/bat.tar.gz"
    github_download_asset "sharkdp/bat" "$latest_tag" "bat-${latest_tag}-${target}\.tar\.gz" "$archive"

    log_info "Extracting Bat binary..."
    tar -xzf "$archive" -C "$TMP_DIR"
    
    local extract_dir="$TMP_DIR/bat-${latest_tag}-${target}"
    
    local target_dir="$HOME/.local/bin"
    mkdir -p "$target_dir"
    
    log_info "Installing Bat to $target_dir/bat..."
    cp "$extract_dir/bat" "$target_dir/bat"
    chmod +x "$target_dir/bat"
    track_file "$target_dir/bat"

    register_tool "bat" "binary" "$latest_tag" "github:sharkdp/bat"
}

configure_shell() {
    # Clean up legacy in-place configuration blocks
    IFS=' ' read -ra target_files <<< "$(get_shell_configs)"
    for config_file in "${target_files[@]}"; do
        remove_block "$config_file" "bat alias"
    done
    if [ -f "$HOME/.bash_aliases" ]; then
        remove_block "$HOME/.bash_aliases" "bat alias"
    fi

    write_alias_snippet "bat" "alias cat='bat --paging=never -p'"
}

main() {
    install_bat
    configure_shell

    echo
    log_success "Bat installation and configuration complete."
}

main "$@"
