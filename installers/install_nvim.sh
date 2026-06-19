#!/usr/bin/env bash
#
# Neovim Installer Script
#
# What this script does:
# 1. Detects the Linux distribution.
# 2. Installs required dependencies (git, wget, tar, curl, unzip, ripgrep, fd, cmake, make, gcc, python, nodejs, npm, xclip, wl-clipboard, fzf).
# 3. Checks whether Neovim 0.11.7 is already installed.
# 4. Prompts before installing or upgrading Neovim.
# 5. Installs the official Neovim binary to /opt/nvim.
# 6. Creates a symlink at /usr/local/bin/nvim.
# 7. Clones the Neovim configuration into ~/.config/nvim.
# 8. Configures shell files (~/.bashrc / ~/.zshrc) to set alias vim="nvim" and export EDITOR="nvim".
#

# Run metascript to check if the shell is bash
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


NVIM_VERSION="0.11.7"
NVIM_URL="https://github.com/neovim/neovim/releases/download/v${NVIM_VERSION}/nvim-linux-x86_64.tar.gz"
NVIM_INSTALL_DIR="/opt/nvim"
NVIM_CONFIG_REPO="https://git.adityagupta.dev/sortedcord/editor.git"
NVIM_CONFIG_DIR="$HOME/.config/nvim"

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

check_config_dir() {
    if [[ -d "$NVIM_CONFIG_DIR" ]]; then
        if confirm "$NVIM_CONFIG_DIR already exists. Replace it?"; then
            echo "Existing configuration will be removed during setup."
            rm -rf "$NVIM_CONFIG_DIR"
        else
            while true; do
                read -r -p "Enter an alternative directory to clone the configuration into: " alt_dir </dev/tty || true
                
                # Expand tilde (~) to $HOME if the user uses it
                alt_dir="${alt_dir/#\~/$HOME}"

                if [[ -z "$alt_dir" ]]; then
                    echo "Directory path cannot be empty. Please try again."
                    continue
                fi

                NVIM_CONFIG_DIR="$alt_dir"
                break
            done
        fi
    fi
}

install_packages() {
    echo "Detecting distribution and installing dependencies..."

    if command -v pacman >/dev/null 2>&1; then
        echo "Arch Linux detected"
        sudo pacman -Sy --needed git wget tar curl unzip ripgrep fd cmake make gcc python nodejs npm xclip wl-clipboard fzf

    elif command -v apt >/dev/null 2>&1; then
        echo "Debian/Ubuntu detected"
        sudo apt update
        sudo apt install -y git wget tar curl unzip ripgrep fd-find cmake build-essential python3 python3-pip python3-venv nodejs npm xclip wl-clipboard fzf
        
        # Create a symlink for fd-find if it doesn't already exist as fd
        if ! command -v fd >/dev/null 2>&1 && command -v fdfind >/dev/null 2>&1; then
            echo "Creating symlink for fd..."
            sudo ln -sf "$(command -v fdfind)" /usr/local/bin/fd
        fi

    elif command -v dnf >/dev/null 2>&1; then
        echo "Fedora detected"
        sudo dnf install -y git wget tar curl unzip ripgrep fd-find cmake make gcc gcc-c++ python3 python3-pip nodejs npm xclip wl-clipboard fzf

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
    # Ensure parent directory for the chosen config path exists
    mkdir -p "$(dirname "$NVIM_CONFIG_DIR")"

    # Quick check if the alternative folder exists and clear it out
    if [[ -d "$NVIM_CONFIG_DIR" ]]; then
        rm -rf "$NVIM_CONFIG_DIR"
    fi

    echo "Cloning configuration to $NVIM_CONFIG_DIR..."
    git clone "$NVIM_CONFIG_REPO" "$NVIM_CONFIG_DIR"
    echo "Configuration installed."
}

configure_shell() {
    local target_files=()
    [ -f "$HOME/.bashrc" ] && target_files+=("$HOME/.bashrc")
    [ -f "$HOME/.zshrc" ] && target_files+=("$HOME/.zshrc")

    for config_file in "${target_files[@]}"; do
        local modified=false

        # Add alias vim=nvim if not present
        if ! grep -q "alias vim=" "$config_file" 2>/dev/null; then
            echo "Adding alias vim=nvim to $config_file..."
            echo 'alias vim="nvim"' >> "$config_file"
            modified=true
        fi

        # Add export EDITOR=nvim if not present
        if ! grep -q "export EDITOR=" "$config_file" 2>/dev/null; then
            echo "Setting EDITOR=nvim in $config_file..."
            echo 'export EDITOR="nvim"' >> "$config_file"
            modified=true
        fi

        # Source if modified
        if [ "$modified" = true ] && [ "$config_file" = "$HOME/.bashrc" ]; then
            . "$config_file" 2>/dev/null || true
        fi
    done
}

main() {
    check_config_dir
    install_packages
    install_nvim
    install_config
    configure_shell

    echo
    echo "Installation complete."
}

main "$@"