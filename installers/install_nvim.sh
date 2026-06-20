#!/usr/bin/env bash
# Tool: nvim
# DisplayName: Neovim
# Description: Install Neovim 0.11.7 and configuration
#
# Neovim Installer Script
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

NVIM_VERSION="0.11.7"
NVIM_INSTALL_DIR="/opt/nvim"
NVIM_CONFIG_REPO="https://git.adityagupta.dev/sortedcord/editor.git"
NVIM_CONFIG_DIR="$HOME/.config/nvim"

TMP_DIR="$(make_temp_dir)"
cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

check_config_dir() {
    # Skip prompt, handled during config clone
    return 0
}

install_packages() {
    log_info "Detecting distribution and installing dependencies..."
    pkg_install \
        git wget tar curl unzip ripgrep fzf nodejs npm xclip wl-clipboard \
        "arch:fd|debian:fd-find|fedora:fd-find" \
        "arch:cmake|debian:cmake|fedora:cmake" \
        "arch:make|debian:build-essential|fedora:make" \
        "arch:gcc|debian:build-essential|fedora:gcc" \
        "arch:python|debian:python3|fedora:python3" \
        "debian:python3-pip|fedora:python3-pip" \
        "debian:python3-venv" \
        "fedora:gcc-c++"
        
    create_fd_symlink
}

install_nvim() {
    local current_version=""

    if has_command nvim; then
        current_version="$(nvim --version | head -n1 | awk '{print $2}')"

        if [[ "$current_version" == "v${NVIM_VERSION}" ]] || [[ "$current_version" == "${NVIM_VERSION}" ]]; then
            log_info "Neovim ${current_version} already installed."
            return
        fi

        log_info "Detected Neovim ${current_version}. Upgrading to v${NVIM_VERSION}..."
    else
        log_info "Installing Neovim v${NVIM_VERSION}..."
    fi

    # Detect architecture to resolve the release binary name (Fix 4)
    local arch
    arch=$(detect_arch)
    local nvim_arch=""
    case "$arch" in
        x86_64) nvim_arch="linux-x86_64" ;;
        arm64)  nvim_arch="linux-arm64" ;;
        *)      log_error "Unsupported architecture: $arch"; exit 1 ;;
    esac

    local nvim_url="https://github.com/neovim/neovim/releases/download/v${NVIM_VERSION}/nvim-${nvim_arch}.tar.gz"

    log_info "Downloading Neovim v${NVIM_VERSION} for ${arch}..."
    if has_command curl; then
        curl -fsSL "$nvim_url" -o "$TMP_DIR/nvim.tar.gz"
    else
        wget -qO "$TMP_DIR/nvim.tar.gz" "$nvim_url"
    fi

    tar -xzf "$TMP_DIR/nvim.tar.gz" -C "$TMP_DIR"

    sudo rm -rf "$NVIM_INSTALL_DIR"
    sudo mv "$TMP_DIR/nvim-${nvim_arch}" "$NVIM_INSTALL_DIR"

    sudo ln -sf "$NVIM_INSTALL_DIR/bin/nvim" /usr/local/bin/nvim

    log_success "Installed:"
    nvim --version | head -n1
}

install_config() {
    if [[ -d "$NVIM_CONFIG_DIR" ]]; then
        log_info "Neovim configuration directory $NVIM_CONFIG_DIR already exists. Skipping config clone."
        return
    fi

    # Ensure parent directory for the chosen config path exists
    mkdir -p "$(dirname "$NVIM_CONFIG_DIR")"

    log_info "Cloning configuration to $NVIM_CONFIG_DIR..."
    git clone "$NVIM_CONFIG_REPO" "$NVIM_CONFIG_DIR"
    log_success "Configuration installed."
}

configure_shell() {
    IFS=' ' read -ra target_files <<< "$(get_shell_configs)"

    for config_file in "${target_files[@]}"; do
        local modified=false

        if add_alias_if_missing "$config_file" "vim" "nvim"; then
            modified=true
        fi

        if add_env_if_missing "$config_file" "EDITOR" "nvim"; then
            modified=true
        fi

        # Source if modified (only for bashrc, and not when sourced to prevent recursion)
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
    log_success "Installation complete."
}

main "$@"