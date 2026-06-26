#!/usr/bin/env bash
# Tool: asciicinema
# DisplayName: asciicinema
# Description: Install asciinema terminal recorder
# Strategy: binary
#
# asciinema Installer Script
#

set -euo pipefail

TMP_DIR="$(make_temp_dir)"
cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

install_asciicinema() {
    if has_command curl; then
        log_info "Fetching latest asciinema version from GitHub..."
        latest_tag=$(github_get_latest_release "asciinema/asciinema")
    fi

    if [ -z "$latest_tag" ]; then
        latest_tag="v3.2.1"  # fallback
        log_warn "Failed to fetch latest version from GitHub. Falling back to: $latest_tag"
    else
        log_info "Latest asciinema version found: $latest_tag"
    fi


    if has_command asciinema; then
        local current_version
        current_version=$(asciinema --version | head -n1 | awk '{print $2}')
        if [[ "$current_version" != v* ]]; then
            current_version="v${current_version}"
        fi

        if [[ "$current_version" == "$latest_tag" ]]; then
            log_info "asciinema ${latest_tag} is already installed."
            if ! confirm "Reinstall/Upgrade asciinema?"; then
                log_info "Skipping asciinema installation."
                return
            fi
        else
            if ! confirm "Detecting asciinema ${current_version}. Upgrade to ${latest_tag}?"; then
                log_info "Skipping asciinema installation."
                return
            fi
        fi
    else
        if ! confirm "Install asciinema ${latest_tag}?"; then
            log_info "Skipping asciinema installation."
            return
        fi
    fi

    # Detect architecture
    local arch
    arch=$(detect_arch)
    local asciinema_arch=""
    case "$arch" in
        x86_64) asciinema_arch="x86_64-unknown-linux-gnu" ;;
        arm64)  asciinema_arch="aarch64-unknown-linux-gnu" ;;
        *)      log_error "Unsupported architecture: $arch"; exit 1 ;;
    esac

    log_info "Downloading asciinema ${latest_tag} for ${arch}..."
    github_download_asset "asciinema/asciinema" "$latest_tag" "asciinema-${asciinema_arch}" "$TMP_DIR/asciinema"

    log_info "Installing asciinema to /usr/local/bin..."
    sudo cp "$TMP_DIR/asciinema" /usr/local/bin/asciinema
    sudo chmod +x /usr/local/bin/asciinema
    track_file "/usr/local/bin/asciinema"

    # Create compatibility symlink matching the installer name spelling
    log_info "Creating compatibility symlink for asciicinema..."
    sudo ln -sf /usr/local/bin/asciinema /usr/local/bin/asciicinema
    track_file "/usr/local/bin/asciicinema"

    log_success "asciinema ${latest_tag} installed."
    register_tool "asciicinema" "binary" "$latest_tag" "github:asciinema/asciinema"
}

main() {
    install_asciicinema

    echo
    log_success "asciinema installation complete."
}

main "$@"
