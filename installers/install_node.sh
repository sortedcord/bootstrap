#!/usr/bin/env bash
# Tool: node
# DisplayName: Node
# Description: Install Node.js (LTS) and NVM
#
# Node.js and NVM Installer Script
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

install_nvm() {
    if has_command nvm || [ -s "$HOME/.nvm/nvm.sh" ]; then
        log_info "NVM is already installed."
    fi

    # Ensure required commands are installed
    if ! has_command tar; then
        log_info "tar not found. Installing tar..."
        pkg_install tar
    fi

    # Try to fetch the latest version of NVM from GitHub API
    log_info "Fetching the latest NVM version..."
    local latest_tag=""
        latest_tag=$(curl -sL https://api.github.com/repos/nvm-sh/nvm/releases/latest | grep '"tag_name":' | head -n1 | sed -E 's/.*"tag_name": "([^"]+)".*/\1/' || true)

    if [ -z "$latest_tag" ]; then
        latest_tag="v0.40.5" # Fallback version if API request fails
        log_warn "Failed to fetch latest version from GitHub. Falling back to hardcoded version: $latest_tag"
    else
        log_info "Latest NVM version found: $latest_tag"
    fi

    local nvm_url="https://github.com/nvm-sh/nvm/archive/refs/tags/${latest_tag}.tar.gz"
    log_info "Downloading NVM from $nvm_url..."

        curl -fsSL "$nvm_url" -o "$TMP_DIR/nvm.tar.gz"

    log_info "Extracting NVM archive directly to $HOME/.nvm (stripping versioned subfolder to keep config generic)..."
    mkdir -p "$HOME/.nvm"
    tar -xzf "$TMP_DIR/nvm.tar.gz" -C "$HOME/.nvm" --strip-components=1

    log_success "NVM source files successfully extracted to $HOME/.nvm."
}

configure_shell() {
    IFS=' ' read -ra target_files <<< "$(get_shell_configs)"

    local content
    content=$(cat << 'EOF'
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # Load NVM
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # Load NVM bash completion
EOF
)

    for config_file in "${target_files[@]}"; do
        log_info "Adding NVM configuration block to $config_file..."
        inject_block "$config_file" "nvm setup" "$content"
        
        # Source if modified (only for bashrc)
        if [ "$config_file" = "$HOME/.bashrc" ]; then
            log_info "Sourcing $config_file..."
            . "$config_file" 2>/dev/null || true
        fi
    done
}

install_node() {
    # Ensure NVM is loaded in this script context
    if [ -s "$HOME/.nvm/nvm.sh" ]; then
        # Temporarily disable nounset as nvm.sh does not support set -u
        set +u
        . "$HOME/.nvm/nvm.sh"
    else
        log_error "Could not load NVM to install Node.js."
        return 1
    fi

    if has_command node; then
        log_info "Currently installed Node.js version: $(node --version)"
    fi

    log_info "Installing Node.js LTS version..."
    nvm install --lts
    nvm use --lts
    nvm alias default 'lts/*'
    log_success "Node.js installed successfully!"
    set -u
}

main() {
    install_nvm
    configure_shell
    install_node

    echo
    if has_command node; then
        log_success "Node.js (via NVM) installation and configuration complete."
        log_info "Installed Node version: $(node --version)"
        log_info "Installed NVM version: $(nvm --version 2>/dev/null || cat "$HOME/.nvm/package.json" | grep '"version":' | head -n1 | sed -E 's/.*"version": "([^"]+)".*/\1/' || echo "unknown")"
    else
        log_success "Installation complete."
        log_info "Please close and reopen your terminal or run: source ~/.bashrc to verify."
    fi
}

main "$@"
