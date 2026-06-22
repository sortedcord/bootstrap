#!/usr/bin/env bash
# Tool: rust
# DisplayName: Rust
# Description: Install Rustup and Rust compiler/toolchain
#
# Rust Installer Script (Simplified Local Rustup Init)
#

# Prevent standalone execution
if [ -z "${_LIB_COMMON_SOURCED:-}" ]; then
    echo "Error: This script must be run through the 'b' CLI." >&2
    exit 1
fi

set -euo pipefail

# Ensure we have curl
install_downloader() {
    if ! has_command curl; then
        log_info "curl not found. Installing curl..."
        pkg_install curl
    fi
}

detect_target_triple() {
    local ostype
    ostype="$(uname -s)"
    if [ "$ostype" != "Linux" ]; then
        log_error "This simplified installer only supports Linux."
        exit 1
    fi

    local clibtype="gnu"
    if ldd --version 2>&1 | grep -q 'musl'; then
        clibtype="musl"
    fi

    local raw_arch
    raw_arch="$(uname -m)"
    local cputype
    case "$raw_arch" in
        x86_64)               cputype="x86_64" ;;
        aarch64|arm64)        cputype="aarch64" ;;
        armv7l|armv8l|armv7)  cputype="armv7" ;;
        i386|i486|i686|x86)   cputype="i686" ;;
        *)                    cputype="$raw_arch" ;;
    esac

    local target="${cputype}-unknown-linux-${clibtype}"
    if [ "$cputype" = "armv7" ]; then
        target="${cputype}-unknown-linux-gnueabihf"
    fi

    echo "$target"
}

install_rust() {
    if has_command rustup || [ -f "$HOME/.cargo/bin/rustup" ]; then
        log_info "Rust (rustup) is already installed."
    fi

    install_downloader

    local target
    target=$(detect_target_triple)
    log_info "Detected target triple: $target"

    local url="https://static.rust-lang.org/rustup/dist/${target}/rustup-init"
    
    local tmpdir
    tmpdir="$(make_temp_dir)"
    cleanup() {
        rm -rf "$tmpdir"
    }
    trap cleanup EXIT

    local dest="$tmpdir/rustup-init"

    log_info "Downloading rustup-init..."
    curl -fsSL \"$url\" -o \"$dest\"|    curl -fsSL \"$url\" -o \"$dest\"

    chmod +x "$dest"

    log_info "Running rustup-init..."
    # Run the downloaded binary
    # -y: skip prompts (we already confirmed)
    # --no-modify-path: let bootstrap manage the shell paths
    "$dest" -y --no-modify-path
}

configure_shell() {
    # Add ~/.cargo/bin to PATH for the current process
    export PATH="$HOME/.cargo/bin:$PATH"

    IFS=' ' read -ra target_files <<< "$(get_shell_configs)"

    for config_file in "${target_files[@]}"; do
        log_info "Configuring Rust environment in $config_file..."
        local content='. "$HOME/.cargo/env"'
        
        inject_block "$config_file" "rust init" "$content"

        # Source if modified (only for bashrc)
        if [ "$config_file" = "$HOME/.bashrc" ]; then
            . "$config_file" 2>/dev/null || true
        fi
    done
}

main() {
    install_rust
    configure_shell

    echo
    log_success "Rust (rustup) installation and configuration complete."
}

main "$@"
