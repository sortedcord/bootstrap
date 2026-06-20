#!/usr/bin/env bash
# Tool: uv
# DisplayName: uv
# Description: Fast Python package installer and resolver
#
# uv Installer Script
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

TMP_DIR="$(make_temp_dir)"
cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

install_uv() {
    if has_command uv || [ -f "$HOME/.local/bin/uv" ]; then
        if ! confirm "uv is already installed. Reinstall/Upgrade?"; then
            log_info "Skipping uv installation."
            return
        fi
    fi

    # Ensure curl or wget is installed
    if ! has_command curl && ! has_command wget; then
        log_info "curl or wget not found. Installing curl..."
        pkg_install curl
    fi

    # Detect architecture
    local raw_arch
    raw_arch=$(detect_arch)
    local arch=""
    case "$raw_arch" in
        x86_64) arch="x86_64" ;;
        arm64)  arch="aarch64" ;;
        *)      log_error "Unsupported Linux architecture: $raw_arch"; exit 1 ;;
    esac

    # Determine target based on libc
    local target=""
    if ldd --version 2>&1 | grep -q "GLIBC"; then
        target="${arch}-unknown-linux-gnu"
    else
        target="${arch}-unknown-linux-musl"
    fi

    log_info "Fetching latest uv version from GitHub..."
    local latest_tag=""
    if has_command curl; then
        latest_tag=$(curl -sL https://api.github.com/repos/astral-sh/uv/releases/latest | grep '"tag_name":' | head -n1 | sed -E 's/.*"tag_name": "([^"]+)".*/\1/' || true)
    elif has_command wget; then
        latest_tag=$(wget -qO- https://api.github.com/repos/astral-sh/uv/releases/latest | grep '"tag_name":' | head -n1 | sed -E 's/.*"tag_name": "([^"]+)".*/\1/' || true)
    fi

    local download_url
    if [ -n "$latest_tag" ]; then
        log_info "Latest uv version found: $latest_tag"
        download_url="https://github.com/astral-sh/uv/releases/download/${latest_tag}/uv-${target}.tar.gz"
    else
        latest_tag="latest"
        log_warn "Failed to fetch latest version from GitHub. Falling back to downloading latest release directly."
        download_url="https://github.com/astral-sh/uv/releases/latest/download/uv-${target}.tar.gz"
    fi

    log_info "Downloading uv from ${download_url}..."
    local archive="$TMP_DIR/uv.tar.gz"
    if has_command curl; then
        curl -fsSL "$download_url" -o "$archive"
    else
        wget -qO "$archive" "$download_url"
    fi

    # Extract the binaries
    log_info "Extracting uv binaries..."
    tar -xzf "$archive" --strip-components 1 -C "$TMP_DIR"

    # Install to ~/.local/bin
    local target_dir="$HOME/.local/bin"
    mkdir -p "$target_dir"
    log_info "Installing uv and uvx to $target_dir..."
    cp "$TMP_DIR/uv" "$target_dir/uv"
    cp "$TMP_DIR/uvx" "$target_dir/uvx"
    chmod +x "$target_dir/uv" "$target_dir/uvx"
}

configure_shell() {
    # Add ~/.local/bin to PATH for the current process
    export PATH="$HOME/.local/bin:$PATH"

    IFS=' ' read -ra target_files <<< "$(get_shell_configs)"

    for config_file in "${target_files[@]}"; do
        # Ensure ~/.local/bin is in PATH for this file if not already present
        if ! grep -q '\.local/bin' "$config_file" 2>/dev/null; then
            log_info "Adding ~/.local/bin to PATH in $config_file..."
            local path_content='export PATH="$HOME/.local/bin:$PATH"'
            inject_block "$config_file" "local-bin path" "$path_content"
        fi

        log_info "Adding uv completion to $config_file..."
        local content='eval "$(uv generate-shell-completion bash)"'
        inject_block "$config_file" "uv completion" "$content"

        # Source to apply changes in the current context
        if [ "$config_file" = "$HOME/.bashrc" ]; then
            . "$config_file" 2>/dev/null || true
        fi
    done
}

main() {
    install_uv
    configure_shell

    echo
    log_success "uv installation and configuration complete."
}

main "$@"
