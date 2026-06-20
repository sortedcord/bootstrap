#!/usr/bin/env bash
#
# Yay Installer Script
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

# ─── Installation Logic ──────────────────────────────────────────────

install_yay() {
    local distro
    distro=$(detect_distro)

    if [ "$distro" != "arch" ]; then
        log_error "This installer only supports Arch Linux."
        exit 1
    fi

    if has_command yay; then
        if ! confirm "Yay is already installed. Reinstall/Upgrade?"; then
            log_info "Skipping Yay installation."
            return
        fi
    else
        if ! confirm "Install Yay?"; then
            log_info "Skipping Yay installation."
            return
        fi
    fi

    local needs_install=false
    if ! pacman -Qq git &>/dev/null; then
        needs_install=true
    fi
    if ! pacman -Qq base-devel &>/dev/null && ! pacman -Qg base-devel &>/dev/null; then
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
