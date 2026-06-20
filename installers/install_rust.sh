#!/usr/bin/env bash
#
# Rust Installer Script (Simplified Local Rustup Init)
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

# Ensure we have curl or wget
install_downloader() {
    if ! has_command curl && ! has_command wget; then
        log_info "Neither curl nor wget found. Installing curl..."
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
    # Check for snap curl issue (snap curl cannot write to /tmp/ due to sandbox)
    local use_wget=false
    if has_command curl; then
        local curl_path
        curl_path=$(command -v curl)
        if echo "$curl_path" | grep -q "/snap/"; then
            if has_command wget; then
                use_wget=true
            else
                log_warn "curl is installed via snap and may fail to write to temp directory."
            fi
        fi
    else
        use_wget=true
    fi

    if [ "$use_wget" = true ]; then
        wget -qO "$dest" "$url"
    else
        curl -fsSL "$url" -o "$dest"
    fi

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
