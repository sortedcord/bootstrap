#!/usr/bin/env bash
# Tool: pnpm
# DisplayName: Pnpm
# Description: Install pnpm package manager
# Strategy: binary
#
# pnpm Installer Script
#
# Installs pnpm (fast, disk-space-efficient package manager for Node.js).
# Supports glibc and musl (Alpine) Linux on x86_64 and arm64.
#
# Linux runtime requirements:
#   - glibc 2.27+ and libatomic.so.1 (for glibc builds)
#   - Debian/Ubuntu: apt-get install -y libatomic1
#   - Fedora/RHEL:   dnf install -y libatomic
#
# Docker usage:
#   curl -fsSL https://get.pnpm.io/install.sh | ENV="$HOME/.bashrc" SHELL="$(which bash)" bash -
#

set -euo pipefail

TMP_DIR="$(make_temp_dir)"
cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# ─── Helper Functions ─────────────────────────────────────────────────

download() {
    if [ -n "${2:-}" ]; then
        download_file "$1" "$2"
    else
        curl -fsSL "$1"
    fi
}

is_glibc_compatible() {
    getconf GNU_LIBC_VERSION >/dev/null 2>&1 || ldd --version >/dev/null 2>&1 || return 1
}

# Detect libc suffix — empty for glibc, "-musl" for musl-based distros
detect_libc_suffix() {
    if ! is_glibc_compatible; then
        printf -- '-musl'
    fi
}

# pnpm v11.0.0-rc.3 renamed release assets. Older versions use legacy names.
use_legacy_assets() {
    local version="$1"
    local major
    major="$(echo "$version" | cut -d. -f1)"
    if [ "$major" -lt 11 ] 2>/dev/null; then
        return 0
    fi
    case "$version" in
        11.0.0-rc.1|11.0.0-rc.2) return 0 ;;
        *) return 1 ;;
    esac
}

# Legacy asset basename for pre-v11.0.0-rc.3 releases
legacy_asset_basename() {
    local arch libc_suffix
    arch="$1"
    libc_suffix="$2"
    if [ -n "$libc_suffix" ]; then
        printf 'pnpm-linuxstatic-%s' "$arch"
    else
        printf 'pnpm-linux-%s' "$arch"
    fi
}

# Release-page asset basename (without extension)
asset_basename() {
    local version arch libc_suffix
    version="$1"
    arch="$2"
    libc_suffix="$3"
    if use_legacy_assets "$version"; then
        legacy_asset_basename "$arch" "$libc_suffix"
    else
        printf 'pnpm-linux-%s%s' "$arch" "$libc_suffix"
    fi
}

# Map system arch to pnpm's naming (x64 / arm64)
detect_pnpm_arch() {
    local arch
    arch="$(uname -m | tr '[:upper:]' '[:lower:]')"

    case "${arch}" in
        x86_64 | amd64) arch="x64" ;;
        arm64 | aarch64) arch="arm64" ;;
        *) return 1 ;;
    esac

    # Double check 32-bit OS reported as 64-bit
    if [ "${arch}" = "x64" ] && [ "$(getconf LONG_BIT)" -eq 32 ]; then
        return 1
    elif [ "${arch}" = "arm64" ] && [ "$(getconf LONG_BIT)" -eq 32 ]; then
        return 1
    fi

    printf '%s' "${arch}"
}

# ─── Installation Logic ──────────────────────────────────────────────

install_pnpm() {
    if has_command pnpm; then
        log_info "pnpm is already installed ($(pnpm --version))."
    fi

    local arch libc_suffix version_json version major_version asset_base

    arch="$(detect_pnpm_arch)" || {
        log_error "pnpm currently only provides pre-built binaries for x86_64/arm64 architectures."
        return 1
    }
    libc_suffix="$(detect_libc_suffix)"

    # Fetch the latest version from GitHub, or use PNPM_VERSION if set
    if [ -z "${PNPM_VERSION:-}" ]; then
        log_info "Fetching latest pnpm version from GitHub..."
        local tag
        tag=$(github_get_latest_release "pnpm/pnpm")
        if [ -n "$tag" ]; then
            version="${tag#v}"
        else
            log_error "Failed to fetch pnpm version info from GitHub."
            return 1
        fi
    else
        version="${PNPM_VERSION}"
    fi

    # Normalize major version (strip leading "v", extract digits)
    major_version="$(printf '%s' "$version" | sed -E 's/^v//; s/^([0-9]+).*/\1/')"
    if [ -z "$major_version" ]; then
        log_error "Invalid PNPM_VERSION: $version"
        return 1
    fi

    log_info "Downloading pnpm v${version} (linux-${arch}${libc_suffix})..."
    asset_base="$(asset_basename "$version" "$arch" "$libc_suffix")"

    if [ "$major_version" -ge 11 ]; then
        # v11+: distributed as tarballs containing the binary and dist/ directory
        github_download_asset "pnpm/pnpm" "v${version}" "${asset_base}\.tar\.gz" "$TMP_DIR/pnpm.tar.gz" || {
            log_error "Failed to download pnpm tarball."
            return 1
        }
        tar -xzf "$TMP_DIR/pnpm.tar.gz" -C "$TMP_DIR" || {
            log_error "Failed to extract pnpm tarball."
            return 1
        }
        chmod +x "$TMP_DIR/pnpm"
        SHELL="${SHELL:-/bin/bash}" "$TMP_DIR/pnpm" setup --force || {
            log_error "pnpm setup failed."
            return 1
        }
    else
        # Older versions: distributed as a single executable binary
        github_download_asset "pnpm/pnpm" "v${version}" "${asset_base}" "$TMP_DIR/pnpm" || {
            log_error "Failed to download pnpm binary."
            return 1
        }
        chmod +x "$TMP_DIR/pnpm"
        SHELL="${SHELL:-/bin/bash}" "$TMP_DIR/pnpm" setup --force || {
            log_error "pnpm setup failed."
            return 1
        }
    fi

    track_dir "$HOME/.local/share/pnpm"
    log_success "pnpm v${version} installed successfully!"
    register_tool "pnpm" "binary" "$version" "github:pnpm/pnpm"
}

# ─── Shell Configuration ─────────────────────────────────────────────

configure_shell() {

    # pnpm's `setup --force` configures PNPM_HOME and PATH automatically,
    # but we also add an env block to ensure PNPM_HOME is set consistently.
    local content
    content=$(cat << 'EOF'
# pnpm
export PNPM_HOME="$BOOTSTRAP_RUNTIMES/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
EOF
)

    write_env_snippet "pnpm" "$content"
}

# ─── Main ─────────────────────────────────────────────────────────────

main() {
    install_pnpm
    configure_shell

    echo
    if has_command pnpm; then
        log_success "pnpm installation and configuration complete."
        log_info "Installed pnpm version: $(pnpm --version 2>/dev/null || echo 'unknown')"
    else
        log_success "Installation complete."
    fi
}

main "$@"
