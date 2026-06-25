#!/usr/bin/env bash
# Tool: bat
# DisplayName: Bat
# Description: Install Bat (alternative to cat) and configure alias
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

        pkg_install curl

        log_info "Fetching latest Bat version from GitHub..."
        local latest_tag=""
            latest_tag=$(curl -sL https://api.github.com/repos/sharkdp/bat/releases/latest | grep '"tag_name":' | head -n1 | sed -E 's/.*"tag_name": "([^"]+)".*/\1/' || true)

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
        download_file "$deb_url" "$TMP_DIR/bat.deb"

        log_info "Installing Bat package..."
        sudo apt install -y "$TMP_DIR/bat.deb"
        add_rollback_cmd "sudo apt remove -y bat"

    else
        log_error "Unsupported distribution."
        exit 1
    fi
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
