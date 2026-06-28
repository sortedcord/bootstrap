#!/usr/bin/env bash
# Tool: hyperfine
# DisplayName: Hyperfine
# Description: Command-line benchmarking tool
# Strategy: binary
#

set -euo pipefail

TMP_DIR="$(make_temp_dir)"
cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

install_hyperfine() {
    if has_command hyperfine; then
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
    latest_tag=$(github_get_latest_release "sharkdp/hyperfine")

    if [ -z "$latest_tag" ]; then
        latest_tag="v1.20.0"
        log_warn "Failed to fetch latest version from GitHub. Falling back to: $latest_tag"
    else
        log_info "Latest Hyperfine version found: $latest_tag"
    fi

    local archive="$TMP_DIR/hyperfine.tar.gz"
    github_download_asset "sharkdp/hyperfine" "$latest_tag" "hyperfine-${latest_tag}-${arch}-unknown-linux-gnu.tar.gz" "$archive"

    # Extract the archive
    log_info "Extracting Hyperfine archive..."
    tar -xzf "$archive" -C "$TMP_DIR"

    local extract_dir="$TMP_DIR/hyperfine-${latest_tag}-${arch}-unknown-linux-gnu"
    if [ ! -d "$extract_dir" ]; then
        # Handle case where directory name might differ
        extract_dir=$(find "$TMP_DIR" -maxdepth 1 -type d -name "hyperfine-*" | head -n1)
    fi

    if [ -z "$extract_dir" ] || [ ! -d "$extract_dir" ]; then
        log_error "Failed to locate extracted Hyperfine directory."
        exit 1
    fi

    # Install binary to $BOOTSTRAP_BIN
    local target_dir="$BOOTSTRAP_BIN"
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

    register_tool "hyperfine" "binary" "$latest_tag" "github:sharkdp/hyperfine"
}

main() {
    install_hyperfine

    echo
    log_success "Hyperfine installation complete."
}

main "$@"
