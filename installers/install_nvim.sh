#!/usr/bin/env bash
set -euo pipefail

NVIM_VERSION="0.11.7"
NVIM_URL="https://github.com/neovim/neovim/releases/download/v${NVIM_VERSION}/nvim-linux-x86_64.tar.gz"
NVIM_INSTALL_DIR="/opt/nvim"

TMP_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

confirm() {
    local prompt="$1"
    local response

    read -r -p "$prompt [y/N]: " response </dev/tty || true

    [[ "$response" =~ ^[Yy]$ ]]
}

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
        echo "Unsupported distribution."
        exit 1
    fi
}

install_nvim() {
    local current_version=""

    if command -v nvim >/dev/null 2>&1; then
        current_version="$(nvim --version | head -n1 | awk '{print $2}')"

        if [[ "$current_version" == "v${NVIM_VERSION}" ]] || [[ "$current_version" == "${NVIM_VERSION}" ]]; then
            echo "Neovim ${current_version} already installed."
            return
        fi

        echo "Detected Neovim ${current_version}"

        if ! confirm "Upgrade to Neovim v${NVIM_VERSION}?"; then
            echo "Skipping Neovim upgrade."
            return
        fi
    else
        echo "Neovim not installed."

        if ! confirm "Install Neovim v${NVIM_VERSION}?"; then
            echo "Skipping Neovim installation."
            return
        fi
    fi

    echo "Downloading Neovim v${NVIM_VERSION}..."

    wget -qO "$TMP_DIR/nvim.tar.gz" "$NVIM_URL"

    tar -xzf "$TMP_DIR/nvim.tar.gz" -C "$TMP_DIR"

    sudo rm -rf "$NVIM_INSTALL_DIR"
    sudo mv "$TMP_DIR/nvim-linux-x86_64" "$NVIM_INSTALL_DIR"

    sudo ln -sf "$NVIM_INSTALL_DIR/bin/nvim" /usr/local/bin/nvim

    echo "Installed:"
    nvim --version | head -n1
}

install_config() {
    local config_dir="$HOME/.config/nvim"

    if [[ -d "$config_dir" ]]; then
        if ! confirm "~/.config/nvim already exists. Replace it?"; then
            echo "Skipping config installation."
            return
        fi

        rm -rf "$config_dir"
    fi

    mkdir -p "$HOME/.config"

    echo "Cloning configuration..."

    git clone \
        https://git.adityagupta.dev/sortedcord/editor.git \
        "$config_dir"

    echo "Configuration installed."
}

main() {
    install_packages
    install_nvim
    install_config

    echo
    echo "Installation complete."
}

main "$@"