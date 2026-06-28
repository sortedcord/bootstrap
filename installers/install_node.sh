#!/usr/bin/env bash
# Tool: node
# DisplayName: Node
# Description: Install Node.js (LTS) and NVM
# Strategy: managed
#
# Node.js and NVM Installer Script
#

set -euo pipefail

TMP_DIR="$(make_temp_dir)"
cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

install_nvm() {
    if has_command nvm || [ -s "$BOOTSTRAP_RUNTIMES/nvm/nvm.sh" ]; then
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
    latest_tag=$(github_get_latest_release "nvm-sh/nvm")

    if [ -z "$latest_tag" ]; then
        latest_tag="v0.40.5" # Fallback version if API request fails
        log_warn "Failed to fetch latest version from GitHub. Falling back to hardcoded version: $latest_tag"
    else
        log_info "Latest NVM version found: $latest_tag"
    fi

    local nvm_url="https://github.com/nvm-sh/nvm/archive/refs/tags/${latest_tag}.tar.gz"
    log_info "Downloading NVM from $nvm_url..."
    download_file "$nvm_url" "$TMP_DIR/nvm.tar.gz"

    log_info "Extracting NVM archive directly to $BOOTSTRAP_RUNTIMES/nvm (stripping versioned subfolder to keep config generic)..."
    mkdir -p "$BOOTSTRAP_RUNTIMES/nvm"
    tar -xzf "$TMP_DIR/nvm.tar.gz" -C "$BOOTSTRAP_RUNTIMES/nvm" --strip-components=1
    
    track_dir "$BOOTSTRAP_RUNTIMES/nvm"

    log_success "NVM source files successfully extracted to $BOOTSTRAP_RUNTIMES/nvm."
}

configure_shell() {

    local content
    content=$(cat << 'EOF'
export NVM_DIR="$BOOTSTRAP_RUNTIMES/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # Load NVM
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # Load NVM bash completion
EOF
)

    write_env_snippet "node" "$content"
}

install_node() {
    # Ensure NVM is loaded in this script context
    if [ -s "$BOOTSTRAP_RUNTIMES/nvm/nvm.sh" ]; then
        # Temporarily disable nounset as nvm.sh does not support set -u
        set +u
        # shellcheck source=/dev/null
        . "$BOOTSTRAP_RUNTIMES/nvm/nvm.sh"
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
    register_tool "node" "managed" "$latest_tag" "github:nvm-sh/nvm"
}

main() {
    install_nvm
    configure_shell
    install_node

    echo
    if has_command node; then
        log_success "Node.js (via NVM) installation and configuration complete."
        log_info "Installed Node version: $(node --version)"
        log_info "Installed NVM version: $(nvm --version 2>/dev/null || grep '"version":' "$BOOTSTRAP_RUNTIMES/nvm/package.json" | head -n1 | sed -E 's/.*"version": "([^"]+)".*/\1/' || echo "unknown")"
    else
        log_success "Installation complete."
    fi
}

main "$@"
