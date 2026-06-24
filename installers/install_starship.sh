#!/usr/bin/env bash
# Tool: starship
# DisplayName: Starship
# Description: Install Starship shell prompt
#
# Starship Installer Script
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

install_starship() {
    if has_command starship || [ -f "$HOME/.local/bin/starship" ]; then
        log_info "Starship is already installed."
    fi

    # Ensure curl is installed
    if ! has_command curl; then
        log_info "curl not found. Installing curl..."
        pkg_install curl
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
        latest_tag=$(curl -sL https://api.github.com/repos/starship/starship/releases/latest | grep '"tag_name":' | head -n1 | sed -E 's/.*"tag_name": "([^"]+)".*/\1/' || true)

    local download_url
    if [ -n "$latest_tag" ]; then
        log_info "Latest Starship version found: $latest_tag"
        download_url="https://github.com/starship/starship/releases/download/${latest_tag}/starship-${target}.tar.gz"
    else
        latest_tag="latest"
        log_warn "Failed to fetch latest version from GitHub. Falling back to downloading latest release directly."
        download_url="https://github.com/starship/starship/releases/latest/download/starship-${target}.tar.gz"
    fi

    log_info "Downloading Starship from ${download_url}..."
    local archive="$TMP_DIR/starship.tar.gz"
    download_file "$download_url" "$archive"

    # Extract the binary
    log_info "Extracting Starship binary..."
    tar -xzf "$archive" -C "$TMP_DIR"

    # Install to ~/.local/bin
    local target_dir="$HOME/.local/bin"
    mkdir -p "$target_dir"
    log_info "Installing Starship to $target_dir/starship..."
    cp "$TMP_DIR/starship" "$target_dir/starship"
    chmod +x "$target_dir/starship"
    track_file "$target_dir/starship"
}

configure_shell() {
    # Add ~/.local/bin to PATH for the current process
    export PATH="$HOME/.local/bin:$PATH"

    # Clean up legacy in-place configuration blocks
    IFS=' ' read -ra target_files <<< "$(get_shell_configs)"
    for config_file in "${target_files[@]}"; do
        remove_block "$config_file" "local-bin path"
        remove_block "$config_file" "starship init"
    done

    write_env_snippet "local-bin" 'export PATH="$HOME/.local/bin:$PATH"'
    write_env_snippet "starship" 'eval "$(starship init bash)"'
}

main() {
    install_starship
    configure_shell

    echo
    log_success "Starship installation and configuration complete."
}

main "$@"
