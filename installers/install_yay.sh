#!/usr/bin/env bash
# Tool: yay
# DisplayName: Yay
# Description: Install Yay AUR helper
#
# Yay Installer Script
#

# Prevent standalone execution
if [ -z "${_LIB_COMMON_SOURCED:-}" ]; then
    echo "Error: This script must be run through the 'b' CLI." >&2
    exit 1
fi

set -euo pipefail

# ─── Installation Logic ──────────────────────────────────────────────

install_yay() {
    local distro
    distro=$(detect_distro)

    if [ "$distro" != "arch" ]; then
        log_error "This installer only supports Arch Linux."
        exit 1
    fi

    if has_command yay; then
        log_info "Yay is already installed."
    fi

    local needs_install=false
    if ! pkg_check git; then
        needs_install=true
    fi
    if ! pkg_check base-devel && ! pacman -Qg base-devel &>/dev/null; then
        needs_install=true
    fi

    if [ "$needs_install" = "true" ]; then
        log_info "Installing missing dependencies (git, base-devel)..."
        pkg_install git base-devel
    else
        log_info "Dependencies (git and base-devel) are already present. Skipping package installation."
    fi

    log_info "Cloning yay-bin repository..."
    local clone_dir
    clone_dir="$(pwd)/yay-bin"

    # Remove any pre-existing clone directory to avoid git clone failure
    rm -rf "$clone_dir"

    git clone https://aur.archlinux.org/yay-bin.git "$clone_dir"

    # Store original directory to go back to it
    local orig_dir
    orig_dir="$(pwd)"

    cd "$clone_dir"

    log_info "Building and installing yay..."
    makepkg -si
    add_rollback_cmd "sudo pacman -R --noconfirm yay"

    cd "$orig_dir"
    log_info "Cleaning up installer directory..."
    rm -rf "$clone_dir"
}

# ─── Main ─────────────────────────────────────────────────────────────

main() {
    install_yay

    echo
    log_success "Yay installation complete."
}

main "$@"
