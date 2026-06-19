#!/usr/bin/env bash

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

add_y_wrapper() {
    local target_files=()
    [ -f "$HOME/.bashrc" ] && target_files+=("$HOME/.bashrc")
    [ -f "$HOME/.zshrc" ] && target_files+=("$HOME/.zshrc")

    for config_file in "${target_files[@]}"; do
        # Clean up old versions if any exist
        if grep -q "# >>> yazi wrapper >>>" "$config_file" 2>/dev/null; then
            sed -i '/# >>> yazi wrapper >>>/,/# <<< yazi wrapper <<</d' "$config_file"
        fi

        echo "Adding yazi wrapper function 'y' to $config_file..."
        cat << 'EOF' >> "$config_file"

# >>> yazi wrapper >>>
# Shell wrapper for yazi to change directory on exit
y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        builtin cd -- "$cwd"
    fi
    rm -f -- "$tmp"
}
# <<< yazi wrapper <<<
EOF
    done

    # Source ~/.bashrc to make the alias immediately available in the current shell context (if sourced)
    if [ -f "$HOME/.bashrc" ]; then
        echo "Sourcing ~/.bashrc..."
        . "$HOME/.bashrc"
    fi
}

install_yazi() {
    echo "Detecting distribution..."

    if command -v pacman >/dev/null 2>&1; then
        echo "Arch Linux detected"
        if command -v yazi >/dev/null 2>&1; then
            if ! confirm "Yazi is already installed. Reinstall/Upgrade?"; then
                echo "Skipping Yazi installation."
                return
            fi
        else
            if ! confirm "Install Yazi and its dependencies?"; then
                echo "Skipping Yazi installation."
                return
            fi
        fi

        echo "Installing Yazi..."
        sudo pacman -Sy --needed yazi

        echo "Installing dependencies subsequently..."
        sudo pacman -S --needed ffmpeg 7zip jq poppler fd ripgrep fzf zoxide resvg imagemagick

    elif command -v apt >/dev/null 2>&1; then
        echo "Debian/Ubuntu detected"
        if command -v yazi >/dev/null 2>&1; then
            if ! confirm "Yazi is already installed. Reinstall/Upgrade?"; then
                echo "Skipping Yazi installation."
                return
            fi
        else
            if ! confirm "Install Yazi and its dependencies?"; then
                echo "Skipping Yazi installation."
                return
            fi
        fi

        sudo apt update
        sudo apt install -y curl wget git

        echo "Fetching latest Yazi version from GitHub..."
        LATEST_TAG=$(curl -sL https://api.github.com/repos/sxyazi/yazi/releases/latest | grep '"tag_name":' | head -n1 | sed -E 's/.*"tag_name": "([^"]+)".*/\1/')
        if [ -z "$LATEST_TAG" ]; then
            LATEST_TAG="v26.5.6"
        fi

        DEB_URL="https://github.com/sxyazi/yazi/releases/download/${LATEST_TAG}/yazi-x86_64-unknown-linux-gnu.deb"
        echo "Downloading Yazi ${LATEST_TAG} from ${DEB_URL}..."
        wget -qO "$TMP_DIR/yazi.deb" "$DEB_URL"

        echo "Installing Yazi package..."
        sudo apt install -y "$TMP_DIR/yazi.deb"

        echo "Installing dependencies subsequently..."
        sudo apt install -y ffmpeg jq poppler-utils fd-find ripgrep fzf zoxide resvg imagemagick 7zip || \
        sudo apt install -y ffmpeg jq poppler-utils fd-find ripgrep fzf zoxide resvg imagemagick p7zip-full

        # Create a symlink for fd-find if it doesn't already exist as fd
        if ! command -v fd >/dev/null 2>&1 && command -v fdfind >/dev/null 2>&1; then
            echo "Creating symlink for fd..."
            sudo ln -sf "$(command -v fdfind)" /usr/local/bin/fd
        fi

    elif command -v dnf >/dev/null 2>&1; then
        echo "Fedora detected"
        if command -v yazi >/dev/null 2>&1; then
            if ! confirm "Yazi is already installed. Reinstall/Upgrade?"; then
                echo "Skipping Yazi installation."
                return
            fi
        else
            if ! confirm "Install Yazi and its dependencies?"; then
                echo "Skipping Yazi installation."
                return
            fi
        fi

        echo "Installing dnf-plugins-core..."
        sudo dnf install -y dnf-plugins-core

        echo "Enabling lihaohong/yazi copr repo..."
        sudo dnf copr enable -y lihaohong/yazi

        echo "Installing Yazi (without weak dependencies first)..."
        sudo dnf install -y yazi --setopt=install_weak_deps=False

        echo "Installing weak dependencies subsequently..."
        sudo dnf install -y yazi

    else
        echo "Unsupported distribution."
        exit 1
    fi
}

main() {
    install_yazi
    add_y_wrapper
    echo
    echo "Yazi installation and configuration complete."
}

main "$@"
