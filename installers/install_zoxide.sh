#!/usr/bin/env bash
# Tool: zoxide
# DisplayName: Zoxide
# Description: Install Zoxide directory jumper
#
# Zoxide Installer Script
#

# Prevent standalone execution
if [ -z "${_LIB_COMMON_SOURCED:-}" ]; then
    echo "Error: This script must be run through the 'b' CLI." >&2
    exit 1
fi

set -euo pipefail

install_curl() {
    if ! has_command curl; then
        log_info "curl not found. Installing curl..."
        pkg_install curl
    fi
}

install_fzf() {
    if has_command fzf; then
        log_info "fzf is already installed."
        return
    fi

    log_info "fzf not found. Installing fzf..."
    pkg_install fzf
}

install_zoxide() {
    if has_command zoxide || [ -f "$HOME/.local/bin/zoxide" ]; then
        log_info "Zoxide is already installed."
    fi

    install_curl

    log_info "Downloading and running the official zoxide installer..."
    curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
}

configure_shell() {
    # Add ~/.local/bin to PATH for the current process
    export PATH="$HOME/.local/bin:$PATH"

    IFS=' ' read -ra target_files <<< "$(get_shell_configs)"

    for config_file in "${target_files[@]}"; do
        log_info "Adding zoxide initialization to $config_file..."
        local content="eval \"\$(zoxide init --cmd cd bash)\""
        
        inject_block "$config_file" "zoxide init" "$content"

        # Source if modified (only for bashrc)
        if [ "$config_file" = "$HOME/.bashrc" ]; then
            . "$config_file" 2>/dev/null || true
        fi
    done
}

main() {
    install_zoxide
    configure_shell
    install_fzf

    echo
    log_success "Zoxide installation and configuration complete."
}

main "$@"
