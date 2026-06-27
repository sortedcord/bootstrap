#!/usr/bin/env bash
# Tool: hyperfine
# DisplayName: Hyperfine
# Description: Command-line benchmarking tool
#
# Hyperfine Installer Script
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

install_hyperfine() {
    if has_command hyperfine || [ -f "$HOME/.local/bin/hyperfine" ]; then
        if ! confirm "Hyperfine is already installed. Reinstall/Upgrade?"; then
            log_info "Skipping Hyperfine installation."
            return
        fi
    else
        if ! confirm "Install Hyperfine?"; then
            log_info "Skipping Hyperfine installation."
            return
        fi
    fi

    # Ensure curl is installed
    if ! has_command curl; then
        log_info "curl not found. Installing curl..."
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

    log_info "Fetching latest Hyperfine version from GitHub..."
    local latest_tag=""
    latest_tag=$(curl -sL https://api.github.com/repos/sharkdp/hyperfine/releases/latest | grep '"tag_name":' | head -n1 | sed -E 's/.*"tag_name": "([^"]+)".*/\1/' || true)

    local download_url
    if [ -n "$latest_tag" ]; then
        log_info "Latest Hyperfine version found: $latest_tag"
        download_url="https://github.com/sharkdp/hyperfine/releases/download/${latest_tag}/hyperfine-${latest_tag}-${arch}-unknown-linux-gnu.tar.gz"
    else
        latest_tag="v1.20.0"
        log_warn "Failed to fetch latest version from GitHub. Falling back to: $latest_tag"
        download_url="https://github.com/sharkdp/hyperfine/releases/download/${latest_tag}/hyperfine-${latest_tag}-${arch}-unknown-linux-gnu.tar.gz"
    fi

    log_info "Downloading Hyperfine from ${download_url}..."
    local archive="$TMP_DIR/hyperfine.tar.gz"
    download_file "$download_url" "$archive"

    # Extract the archive
    log_info "Extracting Hyperfine archive..."
    tar -xzf "$archive" -C "$TMP_DIR"

    local extract_dir="$TMP_DIR/hyperfine-${latest_tag}-${arch}-unknown-linux-gnu"
    if [ ! -d "$extract_dir" ]; then
        # Handle case where directory name might differ (e.g. without leading v in directory name or tag)
        extract_dir=$(find "$TMP_DIR" -maxdepth 1 -type d -name "hyperfine-*" | head -n1)
    fi

    if [ -z "$extract_dir" ] || [ ! -d "$extract_dir" ]; then
        log_error "Failed to locate extracted Hyperfine directory."
        exit 1
    fi

    # Install binary to ~/.local/bin
    local target_dir="$HOME/.local/bin"
    mkdir -p "$target_dir"
    log_info "Installing Hyperfine to $target_dir/hyperfine..."
    cp "$extract_dir/hyperfine" "$target_dir/hyperfine"
    chmod +x "$target_dir/hyperfine"
    track_file "$target_dir/hyperfine"

    # Install man page if present
    if [ -f "$extract_dir/hyperfine.1" ]; then
        local man_dir="$HOME/.local/share/man/man1"
        mkdir -p "$man_dir"
        log_info "Installing man page to $man_dir/hyperfine.1..."
        cp "$extract_dir/hyperfine.1" "$man_dir/hyperfine.1"
        track_file "$man_dir/hyperfine.1"
    fi

    # Install autocomplete if present
    if [ -f "$extract_dir/autocomplete/hyperfine.bash" ]; then
        log_info "Installing bash completions..."
        local comp_content
        comp_content=$(cat "$extract_dir/autocomplete/hyperfine.bash")
        write_completion_snippet "hyperfine" "$comp_content"
    fi
}

configure_shell() {
    # Add ~/.local/bin to PATH for the current process
    export PATH="$HOME/.local/bin:$PATH"

    # Clean up legacy in-place configuration blocks
    IFS=' ' read -ra target_files <<< "$(get_shell_configs)"
    for config_file in "${target_files[@]}"; do
        remove_block "$config_file" "local-bin path"
    done

    write_env_snippet "local-bin" 'export PATH="$HOME/.local/bin:$PATH"'
}

main() {
    install_hyperfine
    configure_shell

    echo
    log_success "Hyperfine installation and configuration complete."
}

main "$@"
