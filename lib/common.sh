#!/usr/bin/env bash
# Shared utility functions for bootstrap CLI

# Avoid double sourcing
if [ -n "${_LIB_COMMON_SOURCED:-}" ]; then
    return 0
fi
_LIB_COMMON_SOURCED=1

# Ensure running in Bash
require_bash() {
    if [ -z "${BASH_VERSION:-}" ]; then
        echo "Error: This script must be run using bash." >&2
        exit 1
    fi
}

# Color definitions (only if stdout is a TTY)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Yes/No Confirmation prompt
confirm() {
    local prompt="$1"
    local response

    # Read from /dev/tty to support piped installations
    read -r -p "$prompt [y/N]: " response </dev/tty || true
    [[ "$response" =~ ^[Yy]$ ]]
}

# Check if a command is available
has_command() {
    command -v "$1" >/dev/null 2>&1
}

# Temporary directory helper with automatic cleanup on exit
make_temp_dir() {
    local tmp_dir
    tmp_dir="$(mktemp -d)"
    echo "$tmp_dir"
}

# Version comparison helper (returns 0 if $1 < $2, 1 otherwise)
version_lt() {
    [ "$1" = "$2" ] && return 1
    local IFS=.
    local i ver1=($1) ver2=($2)
    for ((i=${#ver1[@]}; i<3; i++)); do ver1[i]=0; done
    for ((i=${#ver2[@]}; i<3; i++)); do ver2[i]=0; done
    for ((i=0; i<3; i++)); do
        if ((10#${ver1[i]} < 10#${ver2[i]})); then
            return 0
        elif ((10#${ver1[i]} > 10#${ver2[i]})); then
            return 1
        fi
    done
    return 1
}

# Export functions and variables for subshells
export _LIB_COMMON_SOURCED=1
export RED GREEN YELLOW BLUE NC
export -f require_bash log_info log_success log_warn log_error confirm has_command make_temp_dir version_lt

