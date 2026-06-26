#!/usr/bin/env bash
# Shared utility functions for bootstrap CLI

# Avoid double sourcing
if [ -n "${_LIB_COMMON_SOURCED:-}" ]; then
    return 0
fi
_LIB_COMMON_SOURCED=1

# Export global environment paths with default fallbacks
export BOOTSTRAP_DIR="${BOOTSTRAP_DIR:-$HOME/.config/bootstrap}"
export BOOTSTRAP_DATA_DIR="${BOOTSTRAP_DATA_DIR:-$HOME/.local/share/bootstrap}"
export BOOTSTRAP_STATE_DIR="${BOOTSTRAP_STATE_DIR:-$HOME/.local/state/bootstrap}"
export BOOTSTRAP_CACHE_DIR="${BOOTSTRAP_CACHE_DIR:-$HOME/.cache/bootstrap}"
export BOOTSTRAP_BIN="${BOOTSTRAP_BIN:-$BOOTSTRAP_DATA_DIR/bin}"
export BOOTSTRAP_OPT="${BOOTSTRAP_OPT:-$BOOTSTRAP_DATA_DIR/opt}"
export BOOTSTRAP_RUNTIMES="${BOOTSTRAP_RUNTIMES:-$BOOTSTRAP_DATA_DIR/runtimes}"

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
# Cached and resumable download helper
download_file() {
    local url="$1"
    local dest="$2"
    local cache_dir="$BOOTSTRAP_CACHE_DIR/downloads"
    
    mkdir -p "$cache_dir"
    
    local safe_name
    if has_command md5sum; then
        safe_name=$(echo -n "$url" | md5sum | cut -d' ' -f1)
    elif has_command shasum; then
        safe_name=$(echo -n "$url" | shasum | cut -d' ' -f1)
    else
        safe_name=$(echo -n "$url" | tr -c '[:alnum:]_.-' '_')
    fi
    
    local base_name
    base_name=$(basename "$url")
    local cache_file="$cache_dir/${safe_name}_${base_name}"
    
    log_info "Downloading $base_name (resumable)..."
    if ! curl -fL -C - "$url" -o "$cache_file"; then
        local exit_code=$?
        # Exit code 33: HTTP server doesn't support ranges/resuming
        # Exit code 36: Bad download resume offset
        if [ $exit_code -eq 33 ] || [ $exit_code -eq 36 ]; then
            log_warn "Server does not support resuming. Retrying from scratch..."
            rm -f "$cache_file"
            curl -fL "$url" -o "$cache_file" || return 1
        else
            return $exit_code
        fi
    fi
    
    mkdir -p "$(dirname "$dest")"
    cp "$cache_file" "$dest"
}

# Helper to download multiple files in parallel using background jobs (batched to 10 at a time)
download_multiple_files_parallel() {
    # Usage: download_multiple_files_parallel url1 dest1 [url2 dest2 ...]
    local urls=()
    local dests=()
    local exit_code=0
    
    while [ $# -ge 2 ]; do
        urls+=("$1")
        dests+=("$2")
        shift 2
    done
    
    local total=${#urls[@]}
    local batch_size=10
    
    for ((i=0; i<total; i+=batch_size)); do
        local pids=()
        local batch_urls=()
        
        # Start up to batch_size background jobs
        for ((j=i; j<i+batch_size && j<total; j++)); do
            local url="${urls[$j]}"
            local dest="${dests[$j]}"
            
            mkdir -p "$(dirname "$dest")" 2>/dev/null || true
            curl -fsSL "$url" -o "$dest" &
            pids+=($!)
            batch_urls+=("$url")
        done
        
        # Wait for all background jobs in the current batch to finish
        for ((j=0; j<${#pids[@]}; j++)); do
            if ! wait "${pids[$j]}"; then
                log_warn "Failed to download from ${batch_urls[$j]}"
                exit_code=1
            fi
        done
    done
    
    return $exit_code
}

# Export functions and variables for subshells
export _LIB_COMMON_SOURCED=1
export RED GREEN YELLOW BLUE NC
export -f require_bash log_info log_success log_warn log_error confirm has_command make_temp_dir version_lt download_file download_multiple_files_parallel
