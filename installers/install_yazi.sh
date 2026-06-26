#!/usr/bin/env bash
# Tool: yazi
# DisplayName: Yazi
# Description: Install Yazi terminal file manager and dependencies
# Strategy: binary
#
# Yazi Installer Script
#

# Prevent standalone execution
if [ -z "${_LIB_COMMON_SOURCED:-}" ]; then
    echo "Error: This script must be run through the 'b' CLI." >&2
    exit 1
fi

set -euo pipefail

TMP_DIR="$(make_temp_dir)"
cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

add_y_wrapper() {

    local wrapper_content
    wrapper_content=$(cat << 'EOF'
# Shell wrapper for yazi to change directory on exit
y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        builtin cd -- "$cwd"
    fi
    rm -f -- "$tmp"
}
EOF
)

    write_alias_snippet "yazi" "$wrapper_content"
}

install_yazi() {
    if has_command yazi; then
        if ! confirm "Yazi is already installed. Reinstall/Upgrade?"; then
            log_info "Skipping Yazi installation."
            return
        fi
    fi

    # Ensure required extraction tools are installed
    if ! has_command unzip; then
        log_info "unzip not found. Installing unzip..."
        pkg_install unzip
    fi

    local arch
    arch=$(detect_arch)
    local target=""
    case "$arch" in
        x86_64) target="x86_64-unknown-linux-gnu" ;;
        arm64)  target="aarch64-unknown-linux-gnu" ;;
        *)      log_error "Unsupported architecture: $arch"; exit 1 ;;
    esac

    log_info "Fetching latest Yazi version from GitHub..."
    local latest_tag=""
    latest_tag=$(github_get_latest_release "sxyazi/yazi")
    
    if [ -z "$latest_tag" ]; then
        latest_tag="v0.3.3"
        log_warn "Failed to fetch latest version from GitHub. Falling back to: $latest_tag"
    fi

    log_info "Downloading Yazi ${latest_tag}..."
    local archive="$TMP_DIR/yazi.zip"
    github_download_asset "sxyazi/yazi" "$latest_tag" "yazi-${target}\.zip" "$archive"

    log_info "Extracting Yazi binaries..."
    unzip -q "$archive" -d "$TMP_DIR"
    
    local extract_dir="$TMP_DIR/yazi-${target}"
    local target_dir="$HOME/.local/bin"
    mkdir -p "$target_dir"

    log_info "Installing Yazi to $target_dir..."
    cp "$extract_dir/yazi" "$target_dir/yazi"
    cp "$extract_dir/ya" "$target_dir/ya"
    chmod +x "$target_dir/yazi" "$target_dir/ya"
    track_file "$target_dir/yazi"
    track_file "$target_dir/ya"

    log_info "Installing system dependencies for Yazi..."
    pkg_install ffmpeg jq ripgrep fzf zoxide resvg imagemagick "arch:7zip|debian:7zip|fedora:p7zip" "arch:poppler|debian:poppler-utils|fedora:poppler-utils" "arch:fd|debian:fd-find|fedora:fd-find"
    
    create_fd_symlink
    
    register_tool "yazi" "binary" "$latest_tag" "github:sxyazi/yazi"
    
    # Add the system dependencies to the registry for uninstallation tracking
    registry_add_sys_deps "yazi" ffmpeg jq ripgrep fzf zoxide resvg imagemagick "arch:7zip|debian:7zip|fedora:p7zip" "arch:poppler|debian:poppler-utils|fedora:poppler-utils" "arch:fd|debian:fd-find|fedora:fd-find"
}

main() {
    install_yazi
    add_y_wrapper
    echo
    log_success "Yazi installation and configuration complete."
}

main "$@"
