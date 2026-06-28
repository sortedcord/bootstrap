#!/usr/bin/env bash
# Platform and package manager detection for bootstrap CLI

if [ -n "${_LIB_PLATFORM_SOURCED:-}" ]; then
    return 0
fi
_LIB_PLATFORM_SOURCED=1

# Source common utilities if not already loaded
if [ -z "${_LIB_COMMON_SOURCED:-}" ]; then
    # Assumes common.sh is in the same directory as platform.sh
    # We resolve the directory of the current script
    _LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # shellcheck source=/dev/null
    . "$_LIB_DIR/common.sh"
fi

detect_distro() {
    if has_command pacman; then
        echo "arch"
    elif has_command apt; then
        echo "debian"
    elif has_command dnf; then
        echo "fedora"
    else
        echo "unknown"
    fi
}

detect_arch() {
    local arch
    arch="$(uname -m)"
    case "$arch" in
        x86_64)  echo "x86_64" ;;
        aarch64|arm64) echo "arm64" ;;
        *)       echo "$arch" ;;
    esac
}

_resolve_pkg_names() {
    local distro="$1"
    shift
    local pkgs=()
    for arg in "$@"; do
        # Format can be "pkg" or "arch:pkg_a|debian:pkg_d|fedora:pkg_f"
        if [[ "$arg" =~ : ]]; then
            IFS='|' read -ra PARTS <<< "$arg"
            local mapped=""
            for part in "${PARTS[@]}"; do
                local d_prefix="${part%%:*}"
                local d_pkg="${part#*:}"
                if [ "$d_prefix" = "$distro" ]; then
                    mapped="$d_pkg"
                    break
                fi
            done
            if [ -n "$mapped" ]; then
                pkgs+=("$mapped")
            fi
        else
            pkgs+=("$arg")
        fi
    done
    echo "${pkgs[@]}"
}

# Install packages depending on detected distro
# Usage: pkg_install <package_name_arch> <package_name_debian> <package_name_fedora>
# Or simpler: map common packages to their distro equivalents
pkg_install() {
    local distro
    distro=$(detect_distro)
    
    if [ "$distro" = "unknown" ]; then
        log_error "Unsupported distribution. Cannot install packages automatically."
        return 1
    fi

    IFS=' ' read -ra pkgs <<< "$(_resolve_pkg_names "$distro" "$@")"

    if [ ${#pkgs[@]} -eq 0 ]; then
        return 0
    fi

    local to_install=()
    for pkg in "${pkgs[@]}"; do
        if ! pkg_check "$pkg"; then
            to_install+=("$pkg")
        fi

    done

    if [ ${#to_install[@]} -eq 0 ]; then
        return 0
    fi

    log_info "Installing packages via $distro package manager: ${to_install[*]}"
    case "$distro" in
        arch)
            sudo pacman -Sy --needed --noconfirm "${to_install[@]}"
            ;;
        debian)
            sudo apt update
            sudo apt install -y "${to_install[@]}"
            ;;
        fedora)
            sudo dnf install -y "${to_install[@]}"
            ;;
    esac
}

# Check if packages are installed
# Returns 0 if all are installed, 1 otherwise
pkg_check() {
    local distro
    distro=$(detect_distro)
    
    if [ "$distro" = "unknown" ]; then
        return 1
    fi

    IFS=' ' read -ra pkgs <<< "$(_resolve_pkg_names "$distro" "$@")"

    if [ ${#pkgs[@]} -eq 0 ]; then
        return 0
    fi

    case "$distro" in
        arch)
            pacman -Qq "${pkgs[@]}" >/dev/null 2>&1
            return $?
            ;;
        debian)
            dpkg -s "${pkgs[@]}" >/dev/null 2>&1
            return $?
            ;;
        fedora)
            rpm -q "${pkgs[@]}" >/dev/null 2>&1
            return $?
            ;;
    esac
}

# Remove packages depending on detected distro
pkg_remove() {
    local distro
    distro=$(detect_distro)
    
    if [ "$distro" = "unknown" ]; then
        log_error "Unsupported distribution. Cannot remove packages automatically."
        return 1
    fi

    IFS=' ' read -ra pkgs <<< "$(_resolve_pkg_names "$distro" "$@")"

    if [ ${#pkgs[@]} -eq 0 ]; then
        return 0
    fi

    local to_remove=()
    for pkg in "${pkgs[@]}"; do
        local is_installed=0
        if pkg_check "$pkg"; then
            is_installed=1
        fi

        
        if [ "$is_installed" -eq 1 ]; then
            to_remove+=("$pkg")
        fi
    done

    if [ ${#to_remove[@]} -eq 0 ]; then
        return 0
    fi

    log_info "Removing packages via $distro package manager: ${to_remove[*]}"
    case "$distro" in
        arch)
            local pac_remove=()
            for pkg in "${to_remove[@]}"; do
                if pacman -Qq "$pkg" >/dev/null 2>&1; then
                    pac_remove+=("$pkg")
                fi
            done
            if [ ${#pac_remove[@]} -gt 0 ]; then
                sudo pacman -R --noconfirm "${pac_remove[@]}"
            fi
            ;;
        debian)
            sudo apt remove -y "${to_remove[@]}"
            ;;
        fedora)
            sudo dnf remove -y "${to_remove[@]}"
            ;;
    esac
}

# Export functions and variables for subshells
export _LIB_PLATFORM_SOURCED=1
export -f detect_distro detect_arch _resolve_pkg_names pkg_install pkg_check pkg_remove

