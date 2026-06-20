#!/usr/bin/env bash
# Tool: bat
# DisplayName: Bat
# Description: Install Bat (alternative to cat) and configure alias
#
# Bat Installer Script
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

install_bat() {
    local distro
    distro=$(detect_distro)

    if [ "$distro" = "arch" ]; then
        log_info "Arch Linux detected"
        log_info "Installing Bat..."
        pkg_install bat

    elif [ "$distro" = "fedora" ]; then
        log_info "Fedora detected"
        log_info "Installing Bat..."
        pkg_install bat

    elif [ "$distro" = "debian" ]; then
        log_info "Debian/Ubuntu detected"

        pkg_install curl wget

        log_info "Fetching latest Bat version from GitHub..."
        local latest_tag=""
        if has_command curl; then
            latest_tag=$(curl -sL https://api.github.com/repos/sharkdp/bat/releases/latest | grep '"tag_name":' | head -n1 | sed -E 's/.*"tag_name": "([^"]+)".*/\1/' || true)
        elif has_command wget; then
            latest_tag=$(wget -qO- https://api.github.com/repos/sharkdp/bat/releases/latest | grep '"tag_name":' | head -n1 | sed -E 's/.*"tag_name": "([^"]+)".*/\1/' || true)
        fi

        if [ -z "$latest_tag" ]; then
            latest_tag="v0.26.1"
            log_warn "Failed to fetch latest version from GitHub. Falling back to: $latest_tag"
        else
            log_info "Latest Bat version found: $latest_tag"
        fi

        # Remove leading 'v' for file name version
        local version="${latest_tag#v}"

        # Detect architecture mapping
        local arch
        arch=$(detect_arch)
        local deb_arch="amd64"
        if [ "$arch" = "arm64" ]; then
            deb_arch="arm64"
        fi

        local deb_url="https://github.com/sharkdp/bat/releases/download/${latest_tag}/bat_${version}_${deb_arch}.deb"
        log_info "Downloading Bat from ${deb_url}..."
        if has_command curl; then
            curl -fsSL "$deb_url" -o "$TMP_DIR/bat.deb"
        else
            wget -qO "$TMP_DIR/bat.deb" "$deb_url"
        fi

        log_info "Installing Bat package..."
        sudo apt install -y "$TMP_DIR/bat.deb"

    else
        log_error "Unsupported distribution."
        exit 1
    fi
}

configure_shell() {
    IFS=' ' read -ra target_files <<< "$(get_shell_configs)"

    local content="alias cat='bat --paging=never -p'"

    for config_file in "${target_files[@]}"; do
        local target_file="$config_file"
        if [ "$config_file" = "$HOME/.bashrc" ]; then
            # Clean up old block from ~/.bashrc if present to avoid duplication
            remove_block "$config_file" "bat alias"
            target_file="$HOME/.bash_aliases"
            # Ensure the file exists
            if [ ! -f "$target_file" ]; then
                touch "$target_file"
            fi
        fi

        log_info "Adding bat alias to $target_file..."
        inject_block "$target_file" "bat alias" "$content"
        
        # Source if modified (only for bashrc)
        if [ "$config_file" = "$HOME/.bashrc" ]; then
            log_info "Sourcing $config_file..."
            . "$config_file" 2>/dev/null || true
        fi
    done
}

main() {
    install_bat
    configure_shell

    echo
    log_success "Bat installation and configuration complete."
    log_info "Please close and reopen your terminal or run: source ~/.bashrc to apply changes."
}

main "$@"
