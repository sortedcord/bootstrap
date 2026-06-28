#!/usr/bin/env bash
# shellcheck disable=SC2016
# Tool: rust
# DisplayName: Rust
# Description: Install Rustup and Rust compiler/toolchain
# Strategy: managed
#
# Rust Installer Script (Simplified Local Rustup Init)
#

set -euo pipefail

TMP_DIR="$(make_temp_dir)"
cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

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
    export CARGO_HOME="$BOOTSTRAP_RUNTIMES/cargo"
    export RUSTUP_HOME="$BOOTSTRAP_RUNTIMES/rustup"

    if has_command rustup || [ -f "$BOOTSTRAP_RUNTIMES/cargo/bin/rustup" ]; then
        log_info "Rust (rustup) is already installed."
    fi



    local target
    target=$(detect_target_triple)
    log_info "Detected target triple: $target"

    local url="https://static.rust-lang.org/rustup/dist/${target}/rustup-init"
    
    local dest="$TMP_DIR/rustup-init"

    log_info "Downloading rustup-init..."
    download_file "$url" "$dest"

    chmod +x "$dest"

    log_info "Running rustup-init..."
    # Run the downloaded binary
    # -y: skip prompts (we already confirmed)
    # --no-modify-path: let bootstrap manage the shell paths
    "$dest" -y --no-modify-path
    
    add_rollback_cmd "rustup self uninstall -y"
    register_tool "rust" "managed" "" "rustup"
}

configure_shell() {


    local snippet_content=$(cat << 'EOF'
export CARGO_HOME="$BOOTSTRAP_RUNTIMES/cargo"
export RUSTUP_HOME="$BOOTSTRAP_RUNTIMES/rustup"
. "$CARGO_HOME/env"
EOF
)
    write_env_snippet "rust" "$snippet_content"
}

main() {
    install_rust
    configure_shell

    echo
    log_success "Rust (rustup) installation and configuration complete."
}

main "$@"
