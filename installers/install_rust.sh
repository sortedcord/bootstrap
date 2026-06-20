#!/usr/bin/env bash
#
# Rust Installer Script
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

install_curl() {
    if ! has_command curl; then
        log_info "curl not found. Installing curl..."
        pkg_install curl
    fi
}

install_rust() {
    if has_command rustup || [ -f "$HOME/.cargo/bin/rustup" ]; then
        if ! confirm "Rust (rustup) is already installed. Reinstall/Upgrade?"; then
            log_info "Skipping Rust installation."
            return
        fi
    else
        if ! confirm "Install Rust (rustup)?"; then
            log_info "Skipping Rust installation."
            return
        fi
    fi

    install_curl

    log_info "Downloading and running the official rustup installer..."
    # The -s -- -y flag runs the rustup installer non-interactively, accepting defaults.
    # --no-modify-path prevents the installer from modifying the shell startup files,
    # as we handle this cleanly ourselves using bootstrap's configure_shell.
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
}

configure_shell() {
    # Add ~/.cargo/bin to PATH for the current process
    export PATH="$HOME/.cargo/bin:$PATH"

    IFS=' ' read -ra target_files <<< "$(get_shell_configs)"

    for config_file in "${target_files[@]}"; do
        log_info "Configuring Rust environment in $config_file..."
        local content='. "$HOME/.cargo/env"'
        
        inject_block "$config_file" "rust init" "$content"

        # Source if modified (only for bashrc)
        if [ "$config_file" = "$HOME/.bashrc" ]; then
            . "$config_file" 2>/dev/null || true
        fi
    done
}

main() {
    install_rust
    configure_shell

    echo
    log_success "Rust (rustup) installation and configuration complete."
}

main "$@"
