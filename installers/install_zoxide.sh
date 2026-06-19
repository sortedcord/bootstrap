#!/usr/bin/env bash
#
# Zoxide Installer Script
#
# What this script does:
# 1. Detects the Linux distribution.
# 2. Checks whether zoxide is already installed.
# 3. Prompts before installing or upgrading zoxide.
# 4. Downloads and runs the official zoxide installer script.
# 5. Configures shell configuration files (~/.bashrc / ~/.zshrc) to initialize zoxide.
# 6. Checks if fzf is installed; if not, installs it using the system package manager.
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

confirm() {
    local prompt="$1"
    local response

    read -r -p "$prompt [y/N]: " response </dev/tty || true

    [[ "$response" =~ ^[Yy]$ ]]
}

install_curl() {
    if ! command -v curl >/dev/null 2>&1; then
        echo "curl not found. Installing curl..."
        if command -v pacman >/dev/null 2>&1; then
            sudo pacman -Sy --needed curl
        elif command -v apt >/dev/null 2>&1; then
            sudo apt update
            sudo apt install -y curl
        elif command -v dnf >/dev/null 2>&1; then
            sudo dnf install -y curl
        fi
    fi
}

install_fzf() {
    if command -v fzf >/dev/null 2>&1; then
        echo "fzf is already installed."
        return
    fi

    echo "fzf not found. Installing fzf..."
    if command -v pacman >/dev/null 2>&1; then
        sudo pacman -Sy --needed fzf
    elif command -v apt >/dev/null 2>&1; then
        sudo apt update
        sudo apt install -y fzf
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y fzf
    else
        echo "Warning: Unsupported distribution. Please install fzf manually." >&2
    fi
}

install_zoxide() {
    if command -v zoxide >/dev/null 2>&1 || [ -f "$HOME/.local/bin/zoxide" ]; then
        if ! confirm "Zoxide is already installed. Reinstall/Upgrade?"; then
            echo "Skipping Zoxide installation."
            return
        fi
    else
        if ! confirm "Install Zoxide?"; then
            echo "Skipping Zoxide installation."
            return
        fi
    fi

    install_curl

    echo "Downloading and running the official zoxide installer..."
    curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
}

configure_shell() {
    local target_files=()
    [ -f "$HOME/.bashrc" ] && target_files+=("$HOME/.bashrc")
    [ -f "$HOME/.zshrc" ] && target_files+=("$HOME/.zshrc")

    # Add ~/.local/bin to PATH for the current process
    export PATH="$HOME/.local/bin:$PATH"

    for config_file in "${target_files[@]}"; do
        # Clean up old block if it exists
        if grep -q "# >>> zoxide init >>>" "$config_file" 2>/dev/null; then
            sed -i '/# >>> zoxide init >>>/,/# <<< zoxide init <<</d' "$config_file"
        fi

        local shell_name="bash"
        if [[ "$config_file" == *".zshrc" ]]; then
            shell_name="zsh"
        fi

        echo "Adding zoxide initialization to $config_file..."
        cat << EOF >> "$config_file"

# >>> zoxide init >>>
eval "\$(zoxide init --cmd cd $shell_name)"
# <<< zoxide init <<<
EOF
        # Source if modified (only for bashrc currently)
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
    echo "Zoxide installation and configuration complete."
}

main "$@"
