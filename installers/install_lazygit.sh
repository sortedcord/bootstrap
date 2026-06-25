#!/usr/bin/env bash
# Tool: lazygit
# DisplayName: lazygit
# Description: Simple terminal UI for git commands
#
# lazygit Installer Script
#

# Prevent standalone execution
if [ -z "${_LIB_COMMON_SOURCED:-}" ]; then
    echo "Error: This script must be run through the 'b' CLI." >&2
    exit 1
fi

set -euo pipefail

# ─── Installation Logic ──────────────────────────────────────────────

install_lazygit() {
    if has_command lazygit; then
        if ! confirm "lazygit is already installed. Reinstall/Upgrade?"; then
            log_info "Skipping lazygit installation."
            return
        fi
    else
        if ! confirm "Install lazygit?"; then
            log_info "Skipping lazygit installation."
            return
        fi
    fi

    local latest_tag=""
    if has_command curl; then
        latest_tag=$(curl -sL https://api.github.com/repos/jesseduffield/lazygit/releases/latest \
            | grep '"tag_name":' | head -n1 \
            | sed -E 's/.*"tag_name": "([^"]+)".*/\1/' || true)
    fi

    if [ -z "$latest_tag" ]; then
        latest_tag="v0.62.2"  # fallback
        log_warn "Failed to fetch latest version. Falling back to: $latest_tag"
    fi

    local version="${latest_tag#v}"
    
    local arch=$(detect_arch)
    local arch_str="x86_64"
    if [ "$arch" = "arm64" ]; then
        arch_str="arm64"
    fi

    local url="https://github.com/jesseduffield/lazygit/releases/download/${latest_tag}/lazygit_${version}_linux_${arch_str}.tar.gz"

    TMP_DIR="$(make_temp_dir)"
    cleanup() { rm -rf "$TMP_DIR"; }
    trap cleanup EXIT

    local dest="$TMP_DIR/lazygit.tar.gz"

    log_info "Downloading lazygit ${latest_tag}..."
    download_file "$url" "$dest"

    log_info "Extracting..."
    tar -xzf "$dest" -C "$TMP_DIR"
    
    mkdir -p "$HOME/.local/bin"
    cp "$TMP_DIR/lazygit" "$HOME/.local/bin/lazygit"
    chmod +x "$HOME/.local/bin/lazygit"
    track_file "$HOME/.local/bin/lazygit"
}

# ─── Main ─────────────────────────────────────────────────────────────

main() {
    install_lazygit

    echo
    log_success "lazygit installation complete."
}

main "$@"
