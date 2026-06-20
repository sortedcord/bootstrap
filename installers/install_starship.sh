#!/usr/bin/env bash
#
# Starship Installer Script
#

# Run metascript to check if the shell is bash and load libraries
PARENT_DIR="$(dirname "$0")/.."
METASCRIPT_LOCAL="$PARENT_DIR/bootstrap.sh"
METASCRIPT_URL="https://git.adityagupta.dev/sortedcord/bootstrap/raw/branch/master/bootstrap.sh"

if [ -f "$METASCRIPT_LOCAL" ]; then
    . "$METASCRIPT_LOCAL"
else
    if command -v wget >/dev/null 2>&1; then
        eval "$(wget -qO- "$METASCRIPT_URL")"
    elif command -v curl >/dev/null 2>&1; then
        eval "$(curl -fsSL "$METASCRIPT_URL")"
    else
        echo "Error: Neither wget nor curl is installed to fetch bootstrap.sh." >&2
        exit 1
    fi
fi

set -euo pipefail

TMP_DIR="$(make_temp_dir)"
cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

install_starship() {
    if has_command starship || [ -f "$HOME/.local/bin/starship" ]; then
        if ! confirm "Starship is already installed. Reinstall/Upgrade?"; then
            log_info "Skipping Starship installation."
            return
        fi
    else
        if ! confirm "Install Starship?"; then
            log_info "Skipping Starship installation."
            return
        fi
    fi

    # Ensure curl or wget is installed
    if ! has_command curl && ! has_command wget; then
        log_info "curl or wget not found. Installing curl..."
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
    if has_command curl; then
        latest_tag=$(curl -sL https://api.github.com/repos/starship/starship/releases/latest | grep '"tag_name":' | head -n1 | sed -E 's/.*"tag_name": "([^"]+)".*/\1/' || true)
    elif has_command wget; then
        latest_tag=$(wget -qO- https://api.github.com/repos/starship/starship/releases/latest | grep '"tag_name":' | head -n1 | sed -E 's/.*"tag_name": "([^"]+)".*/\1/' || true)
    fi

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
    if has_command curl; then
        curl -fsSL "$download_url" -o "$archive"
    else
        wget -qO "$archive" "$download_url"
    fi

    # Extract the binary
    log_info "Extracting Starship binary..."
    tar -xzf "$archive" -C "$TMP_DIR"

    # Install to ~/.local/bin
    local target_dir="$HOME/.local/bin"
    mkdir -p "$target_dir"
    log_info "Installing Starship to $target_dir/starship..."
    cp "$TMP_DIR/starship" "$target_dir/starship"
    chmod +x "$target_dir/starship"
}

configure_shell() {
    # Add ~/.local/bin to PATH for the current process
    export PATH="$HOME/.local/bin:$PATH"

    IFS=' ' read -ra target_files <<< "$(get_shell_configs)"

    for config_file in "${target_files[@]}"; do
        local shell_name="bash"
        if [[ "$config_file" == *".zshrc" ]]; then
            shell_name="zsh"
        fi

        # Ensure ~/.local/bin is in PATH for this file if not already present
        if [ -f "$config_file" ] && ! grep -q '\.local/bin' "$config_file" 2>/dev/null; then
            log_info "Adding ~/.local/bin to PATH in $config_file..."
            local path_content='export PATH="$HOME/.local/bin:$PATH"'
            inject_block "$config_file" "local-bin path" "$path_content"
        fi

        log_info "Adding starship initialization to $config_file..."
        local content
        content="eval \"\$(starship init $shell_name)\""
        
        inject_block "$config_file" "starship init" "$content"

        # Source if modified (only for bashrc)
        if [ "$config_file" = "$HOME/.bashrc" ]; then
            . "$config_file" 2>/dev/null || true
        fi
    done
}

main() {
    install_starship
    configure_shell

    echo
    log_success "Starship installation and configuration complete."
}

main "$@"
