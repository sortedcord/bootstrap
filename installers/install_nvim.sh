#!/usr/bin/env bash
set -euo pipefail

NVIM_VERSION="v0.11.7"
NVIM_URL="https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-linux-x86_64.tar.gz"
TMP_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

install_packages() {
    echo "Detecting distribution..."

    if command -v pacman >/dev/null 2>&1; then
        echo "Arch Linux detected"
        sudo pacman -Sy --needed git wget tar

    elif command -v apt >/dev/null 2>&1; then
        echo "Debian/Ubuntu detected"
        sudo apt update
        sudo apt install -y git wget tar

    elif command -v dnf >/dev/null 2>&1; then
        echo "Fedora detected"
        sudo dnf install -y git wget tar

    else
        echo "Unsupported distribution"
        exit 1
    fi
}

install_nvim() {
    local current_version=""

    if command -v nvim >/dev/null 2>&1; then
        current_version="$(nvim --version | head -n1 | awk '{print $2}')"

        if [[ "$current_version" == "${NVIM_VERSION#v}" ]]; then
            echo "Neovim ${current_version} already installed."
            return
        fi

        echo "Detected Neovim ${current_version}"
    else
        echo "Neovim not installed."
    fi

    read -rp "Install/upgrade to Neovim ${NVIM_VERSION}? [y/N]: " confirm

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Skipping Neovim installation."
        return
    fi

    echo "Downloading Neovim ${NVIM_VERSION}..."

    wget -qO "$TMP_DIR/nvim.tar.gz" "$NVIM_URL"

    tar -xzf "$TMP_DIR/nvim.tar.gz" -C "$TMP_DIR"

    sudo rm -rf /opt/nvim
    sudo mv "$TMP_DIR/nvim-linux-x86_64" /opt/nvim

    sudo ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim

    echo "Neovim installed:"
    nvim --version | head -n1
}

install_config() {
    local config_dir="$HOME/.config/nvim"

    if [[ -d "$config_dir" ]]; then
        read -rp "~/.config/nvim already exists. Replace it? [y/N]: " confirm

        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            rm -rf "$config_dir"
        else
            echo "Skipping config installation."
            return
        fi
    fi

    mkdir -p "$HOME/.config"

    git clone \
        https://git.adityagupta.dev/sortedcord/editor.git \
        "$config_dir"

    echo "Neovim config installed."
}

main() {
    install_packages
    install_nvim
    install_config

    echo
    echo "Done."
}

main "$@"