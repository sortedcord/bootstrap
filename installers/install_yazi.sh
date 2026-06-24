#!/usr/bin/env bash
# Tool: yazi
# DisplayName: Yazi
# Description: Install Yazi terminal file manager and dependencies
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
    # Clean up legacy in-place configuration blocks
    IFS=' ' read -ra target_files <<< "$(get_shell_configs)"
    for config_file in "${target_files[@]}"; do
        remove_block "$config_file" "yazi wrapper"
    done

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
    local distro
    distro=$(detect_distro)

    if [ "$distro" = "arch" ]; then
        log_info "Arch Linux detected"
        if has_command yazi; then
            log_info "Yazi is already installed."
        fi

        log_info "Installing Yazi..."
        pkg_install yazi
        log_info "Installing dependencies subsequently..."
        pkg_install ffmpeg 7zip jq poppler fd ripgrep fzf zoxide resvg imagemagick

    elif [ "$distro" = "debian" ]; then
        log_info "Debian/Ubuntu detected"
        if has_command yazi; then
            log_info "Yazi is already installed."
        fi

        pkg_install curl git

        log_info "Fetching latest Yazi version from GitHub..."
        local latest_tag
        latest_tag=$(curl -sL https://api.github.com/repos/sxyazi/yazi/releases/latest | grep '"tag_name":' | head -n1 | sed -E 's/.*"tag_name": "([^"]+)".*/\1/' || true)
        if [ -z "$latest_tag" ]; then
            latest_tag="v26.5.6"
        fi

        local deb_url="https://github.com/sxyazi/yazi/releases/download/${latest_tag}/yazi-x86_64-unknown-linux-gnu.deb"
        log_info "Downloading Yazi ${latest_tag} from ${deb_url}..."
        download_file "$deb_url" "$TMP_DIR/yazi.deb"

        log_info "Installing Yazi package..."
        sudo apt install -y "$TMP_DIR/yazi.deb"
        add_rollback_cmd "sudo apt remove -y yazi"

        log_info "Installing dependencies subsequently..."
        pkg_install ffmpeg jq poppler-utils fd-find ripgrep fzf zoxide resvg imagemagick 7zip || \
        pkg_install ffmpeg jq poppler-utils fd-find ripgrep fzf zoxide resvg imagemagick p7zip-full

        create_fd_symlink

    elif [ "$distro" = "fedora" ]; then
        log_info "Fedora detected"
        if has_command yazi; then
            log_info "Yazi is already installed."
        fi

        log_info "Installing dnf-plugins-core..."
        pkg_install dnf-plugins-core

        log_info "Enabling lihaohong/yazi copr repo..."
        sudo dnf copr enable -y lihaohong/yazi

        log_info "Installing Yazi (without weak dependencies first)..."
        sudo dnf install -y yazi --setopt=install_weak_deps=False
        add_rollback_cmd "sudo dnf remove -y yazi"

        log_info "Installing weak dependencies subsequently..."
        pkg_install yazi

    else
        log_error "Unsupported distribution."
        exit 1
    fi
}

main() {
    install_yazi
    add_y_wrapper
    echo
    log_success "Yazi installation and configuration complete."
}

main "$@"
