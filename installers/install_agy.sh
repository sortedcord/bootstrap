#!/usr/bin/env bash
# Tool: agy
# DisplayName: Antigravity
# Description: Install Antigravity CLI
#
# Antigravity CLI Installer Script (Linux Only)
#

# Run metascript to check if the shell is bash and load libraries
PARENT_DIR="$(dirname "$0")/.."
METASCRIPT_LOCAL="$PARENT_DIR/bootstrap.sh"
METASCRIPT_URL="https://git.adityagupta.dev/sortedcord/bootstrap/raw/branch/master/bootstrap.sh"

if [ -f "$METASCRIPT_LOCAL" ]; then
    . "$METASCRIPT_LOCAL"
else
    if command -v curl >/dev/null 2>&1; then
        eval "$(curl -fsSL "$METASCRIPT_URL")"
    else
        echo "Error: curl is not installed to fetch bootstrap.sh." >&2
        exit 1
    fi
fi

set -euo pipefail

# Constants
DOWNLOAD_BASE_URL="https://antigravity-cli-auto-updater-974169037036.us-central1.run.app"
TARGET_DIR="$HOME/.local/bin"
BINARY_PATH="$TARGET_DIR/agy"

install_agy() {
    if [ -f "$BINARY_PATH" ]; then
        log_info "Notice: 'agy' is already installed at $BINARY_PATH."
        log_info "The Antigravity CLI automatically self-updates in the background during regular runs."
    fi

    # Detect Architecture (map uname -m to amd64 / arm64)
    local arch
    local raw_arch
    raw_arch=$(detect_arch)
    case "$raw_arch" in
        x86_64) arch="amd64" ;;
        arm64)  arch="arm64" ;;
        *)      log_error "Unsupported Linux architecture: $raw_arch"; exit 1 ;;
    esac

    # musl libc detection on Linux
    local platform="linux_${arch}"
    if [ -f /lib/libc.musl-x86_64.so.1 ] || [ -f /lib/libc.musl-aarch64.so.1 ] || ldd /bin/ls 2>&1 | grep -q musl; then
        platform="linux_${arch}_musl"
    fi

    log_info "Platform detected: $platform"
    log_info "Querying release repository..."

    # Construct Platform JSON Manifest URL
    local manifest_url="$DOWNLOAD_BASE_URL/manifests/$platform.json"
    local manifest_json=""

        manifest_json=$(curl -fsSL "$manifest_url" 2>/dev/null || true)

    if [ -z "$manifest_json" ]; then
        log_error "Could not connect to the release server to download the manifest."
        exit 1
    fi

    # POSIX-compliant JSON parser (no jq dependencies)
    parse_json_key() {
        local payload="$1"
        local key="$2"
        echo "$payload" | sed -n 's/.*"'"$key"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'
    }

    local version
    local url
    local sha512
    version=$(parse_json_key "$manifest_json" "version")
    url=$(parse_json_key "$manifest_json" "url")
    sha512=$(parse_json_key "$manifest_json" "sha512")

    if [ -z "$url" ] || [ -z "$sha512" ]; then
        log_error "Failed to parse release manifest."
        exit 1
    fi

    log_info "Latest available version: $version"

    # Setup temp/staging dir
    local staging_dir
    staging_dir="$(make_temp_dir)"
    
    local is_tar_gz=false
    if [[ "$url" == *.tar.gz* ]]; then
        is_tar_gz=true
    fi

    local staging_payload
    local extracted_binary
    if [ "$is_tar_gz" = true ]; then
        staging_payload="$staging_dir/agy.tar.gz"
        extracted_binary="$staging_dir/antigravity"
    else
        staging_payload="$staging_dir/agy"
        extracted_binary="$staging_payload"
    fi

    log_info "Downloading release package..."
        curl -fsSL "$url" -o "$staging_payload"

    # Verify SHA512 Checksum
    local actual_hash
    if has_command sha512sum; then
        actual_hash=$(sha512sum "$staging_payload" | cut -d' ' -f1 || true)
    elif has_command shasum; then
        actual_hash=$(shasum -a 512 "$staging_payload" | cut -d' ' -f1 || true)
    else
        log_error "Neither sha512sum nor shasum is available to verify the download."
        rm -rf "$staging_dir"
        exit 1
    fi

    if [ "$actual_hash" != "$sha512" ]; then
        log_error "Security Halt: Downloaded payload checksum does not match manifest. Installation aborted."
        rm -rf "$staging_dir"
        exit 1
    fi
    log_success "Download complete and checksum verified."

    # Direct Binary Extraction & Write Permission Validation
    mkdir -p "$TARGET_DIR"

    if [ "$is_tar_gz" = true ]; then
        log_info "Extracting binary from archive..."
        tar -xzf "$staging_payload" -C "$staging_dir" antigravity
    else
        log_info "Copying binary directly to destination..."
    fi

    cp "$extracted_binary" "$BINARY_PATH"
    chmod +x "$BINARY_PATH"
    rm -rf "$staging_dir"

    log_success "Antigravity CLI successfully installed to $BINARY_PATH."
}

configure_shell() {
    # Ensure $TARGET_DIR is in PATH for shell configurations if not present
    IFS=' ' read -ra target_files <<< "$(get_shell_configs)"
    
    local path_content='export PATH="$HOME/.local/bin:$PATH"'
    
    for config_file in "${target_files[@]}"; do
        if [ -f "$config_file" ] && ! grep -q '\.local/bin' "$config_file" 2>/dev/null; then
            log_info "Adding ~/.local/bin to PATH in $config_file..."
            inject_block "$config_file" "local-bin path" "$path_content"
            
            # Source if modified (only for bashrc)
            if [ "$config_file" = "$HOME/.bashrc" ]; then
                . "$config_file" 2>/dev/null || true
            fi
        fi
    done
}

run_handoff() {
    log_info "Configuring shell environment via agy native setup handoff..."
    # Run standard configuration and absorb non-fatal soft warning exits
    "$BINARY_PATH" install || true
}

main() {
    install_agy
    configure_shell
    run_handoff

    echo
    log_success "Antigravity CLI installation complete."
}

main "$@"
