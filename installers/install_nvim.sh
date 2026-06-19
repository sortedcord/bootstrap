#!/usr/bin/env bash

set -euo pipefail

NVIM_VERSION="0.11.7"
NVIM_URL="https://github.com/neovim/neovim/releases/download/v${NVIM_VERSION}/nvim-linux-x86_64.tar.gz"
CONFIG_REPO="https://git.adityagupta.dev/sortedcord/editor.git"

TMP_DIR="$(mktemp -d)"

cleanup() {
rm -rf "$TMP_DIR"
}

trap cleanup EXIT

prompt_yes_no() {
local prompt="$1"
local response

```
read -r -p "$prompt [y/N]: " response < /dev/tty || true

[[ "$response" =~ ^[Yy]$ ]]
```

}

install_packages() {
echo "Detecting distribution..."

```
if command -v pacman >/dev/null 2>&1; then
    echo "Arch Linux detected"
    sudo pacman -Sy --needed git curl tar

elif command -v apt >/dev/null 2>&1; then
    echo "Debian/Ubuntu detected"
    sudo apt update
    sudo apt install -y git curl tar

elif command -v dnf >/dev/null 2>&1; then
    echo "Fedora detected"
    sudo dnf install -y git curl tar

else
    echo "Unsupported distribution."
    exit 1
fi
```

}

install_nvim() {
local current_version=""

```
if command -v nvim >/dev/null 2>&1; then
    current_version="$(nvim --version | head -n1 | awk '{print $2}')"

    if [[ "$current_version" == "v${NVIM_VERSION}" ]]; then
        echo "Neovim ${current_version} already installed."
        return
    fi

    echo "Current Neovim version: ${current_version}"

    if ! prompt_yes_no "Upgrade to Neovim v${NVIM_VERSION}?"; then
        echo "Skipping Neovim upgrade."
        return
    fi
else
    if ! prompt_yes_no "Install Neovim v${NVIM_VERSION}?"; then
        echo "Skipping Neovim installation."
        return
    fi
fi

echo "Downloading Neovim..."

curl -L "$NVIM_URL" -o "$TMP_DIR/nvim.tar.gz"

tar -xzf "$TMP_DIR/nvim.tar.gz" -C "$TMP_DIR"

sudo rm -rf /opt/nvim
sudo mv "$TMP_DIR/nvim-linux-x86_64" /opt/nvim

sudo ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim

echo "Installed:"
nvim --version | head -n1
```

}

install_config() {
local config_dir="$HOME/.config/nvim"

```
mkdir -p "$HOME/.config"

if [[ -d "$config_dir" ]]; then
    local backup="${config_dir}.bak.$(date +%s)"

    echo "Existing config found."
    echo "Backing up to: $backup"

    mv "$config_dir" "$backup"
fi

git clone "$CONFIG_REPO" "$config_dir"

echo "Neovim configuration installed."
```

}

main() {
echo "=== SortedCord Neovim Bootstrap ==="
echo

```
install_packages
install_nvim
install_config

echo
echo "Bootstrap complete."
```

}

main "$@"
