#!/usr/bin/env bash
# shellcheck disable=SC2016
# Tool: starship
# DisplayName: Starship
# Description: Install Starship shell prompt
# Strategy: binary
#
# Starship Installer Script
#

set -euo pipefail

TMP_DIR="$(make_temp_dir)"
cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

install_starship() {
    if has_command starship || [ -f "$HOME/.local/bin/starship" ]; then
        log_info "Starship is already installed."
    fi

    # Detect architecture
    local raw_arch
    raw_arch=$(detect_arch)
    local arch=""
    case "$raw_arch" in
        x86_64) arch="x86_64" ;;
        arm64)  arch="aarch64" ;;
        *)      log_error "Unsupported Linux architecture: $raw_arch"; exit 1 ;;
    esac

    local target="${arch}-unknown-linux-musl"

    log_info "Fetching latest Starship version from GitHub..."
    local latest_tag=""
    latest_tag=$(github_get_latest_release "starship/starship")
    
    if [ -z "$latest_tag" ]; then
        latest_tag="latest"
    fi

    log_info "Downloading Starship ${latest_tag}..."
    local archive="$TMP_DIR/starship.tar.gz"
    github_download_asset "starship/starship" "$latest_tag" "starship-${target}\.tar\.gz" "$archive"

    # Extract the binary
    log_info "Extracting Starship binary..."
    tar -xzf "$archive" -C "$TMP_DIR"

    # Install to ~/.local/bin
    local target_dir="$BOOTSTRAP_BIN"
    mkdir -p "$target_dir"
    log_info "Installing Starship to $target_dir/starship..."
    cp "$TMP_DIR/starship" "$target_dir/starship"
    chmod +x "$target_dir/starship"
    track_file "$target_dir/starship"
    register_tool "starship" "binary" "$latest_tag" "github:starship/starship"
}

configure_shell() {


    write_env_snippet "starship" 'eval "$(starship init bash)"'
}

main() {
    install_starship
    configure_shell

    echo
    log_success "Starship installation and configuration complete."
}

main "$@"
