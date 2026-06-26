#!/usr/bin/env bash
# Tool: zoxide
# DisplayName: Zoxide
# Description: Install Zoxide directory jumper
# Strategy: managed
#
# Zoxide Installer Script
#

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
    track_file "$HOME/.local/bin/zoxide"
    register_tool "zoxide" "managed" "" "github:ajeetdsouza/zoxide"
}

configure_shell() {
    # Add ~/.local/bin to PATH for the current process
    export PATH="$HOME/.local/bin:$PATH"


    write_env_snippet "local-bin" 'export PATH="$HOME/.local/bin:$PATH"'
    write_env_snippet "zoxide" 'eval "$(zoxide init --cmd cd bash)"'
}

main() {
    install_zoxide
    configure_shell
    install_fzf

    echo
    log_success "Zoxide installation and configuration complete."
}

main "$@"
