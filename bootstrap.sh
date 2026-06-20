#!/usr/bin/env bash

# This is a metascript called by parent scripts to verify the execution environment.
# It checks if the current shell is bash or not. If not, it terminates execution.

if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: This script must be run using bash." >&2
    exit 1
fi

# Detect if the script is sourced
is_sourced=false
if [ -n "${BASH_SOURCE[0]:-}" ] && [ "${BASH_SOURCE[0]}" != "$0" ]; then
    is_sourced=true
fi

# Locate or download libraries so that sourced installers can use them
BOOTSTRAP_DIR="${BOOTSTRAP_DIR:-$HOME/.config/bootstrap}"
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null || pwd)"

if [ -f "$_SCRIPT_DIR/lib/common.sh" ]; then
    # Dev/local mode: source directly from repo
    . "$_SCRIPT_DIR/lib/common.sh"
    . "$_SCRIPT_DIR/lib/platform.sh"
    . "$_SCRIPT_DIR/lib/shell_config.sh"
elif [ -f "$BOOTSTRAP_DIR/lib/common.sh" ]; then
    # Installed mode: source from bootstrap dir
    . "$BOOTSTRAP_DIR/lib/common.sh"
    . "$BOOTSTRAP_DIR/lib/platform.sh"
    . "$BOOTSTRAP_DIR/lib/shell_config.sh"
else
    # Standalone/remote mode: download to a temp directory and source
    export BOOTSTRAP_TMP_DIR
    BOOTSTRAP_TMP_DIR="$(mktemp -d)"
    trap 'rm -rf "$BOOTSTRAP_TMP_DIR"' EXIT
    
    _BASE_URL="https://git.adityagupta.dev/sortedcord/bootstrap/raw/branch/master"
    _LIBS=("lib/common.sh" "lib/platform.sh" "lib/shell_config.sh")
    for _lib in "${_LIBS[@]}"; do
        mkdir -p "$BOOTSTRAP_TMP_DIR/$(dirname "$_lib")"
        if command -v curl >/dev/null 2>&1; then
            curl -fsSL "$_BASE_URL/$_lib" -o "$BOOTSTRAP_TMP_DIR/$_lib" 2>/dev/null
        elif command -v wget >/dev/null 2>&1; then
            wget -qO "$BOOTSTRAP_TMP_DIR/$_lib" "$_BASE_URL/$_lib" 2>/dev/null
        fi
    done
    
    if [ -f "$BOOTSTRAP_TMP_DIR/lib/common.sh" ]; then
        . "$BOOTSTRAP_TMP_DIR/lib/common.sh"
        . "$BOOTSTRAP_TMP_DIR/lib/platform.sh"
        . "$BOOTSTRAP_TMP_DIR/lib/shell_config.sh"
    else
        echo "Error: Failed to download bootstrap libraries." >&2
        exit 1
    fi
fi

# Install/update the bootstrap loader and download all necessary files
install_bootstrap() {
    local target_files=()
    [ -f "$HOME/.bashrc" ] && target_files+=("$HOME/.bashrc")
    [ -f "$HOME/.zshrc" ] && target_files+=("$HOME/.zshrc")

    local routes_dir="$HOME/.config/bootstrap"
    mkdir -p "$routes_dir"

    # List of all files to download/copy
    local files=(
        "b.sh"
        "routes.sh"
        "lib/common.sh"
        "lib/platform.sh"
        "lib/shell_config.sh"
        "commands/help.sh"
        "commands/con.sh"
        "commands/uninstall.sh"
    )

    if [ -f "$_SCRIPT_DIR/b.sh" ] && [ -f "$_SCRIPT_DIR/routes.sh" ]; then
        log_info "Using local files from repository..."
        for file in "${files[@]}"; do
            mkdir -p "$(dirname "$routes_dir/$file")"
            if [ -f "$_SCRIPT_DIR/$file" ]; then
                cp "$_SCRIPT_DIR/$file" "$routes_dir/$file"
            fi
        done
        
        # Also copy installers if they exist locally
        if [ -d "$_SCRIPT_DIR/installers" ]; then
            mkdir -p "$routes_dir/installers"
            cp -r "$_SCRIPT_DIR/installers/"* "$routes_dir/installers/"
        fi
    else
        log_info "Downloading bootstrap scripts..."
        local base_url="https://git.adityagupta.dev/sortedcord/bootstrap/raw/branch/master"
        for file in "${files[@]}"; do
            mkdir -p "$(dirname "$routes_dir/$file")"
            local file_url="$base_url/$file"
            if command -v curl >/dev/null 2>&1; then
                curl -fsSL "$file_url" -o "$routes_dir/$file"
            elif command -v wget >/dev/null 2>&1; then
                wget -qO "$routes_dir/$file" "$file_url"
            else
                log_error "Neither curl nor wget is installed."
                exit 1
            fi
        done
    fi

    # Set up shell configuration files
    for config_file in "${target_files[@]}"; do
        # 1. Clean up old embedded function block if it exists (from previous setup)
        remove_block "$config_file" "bootstrap-cli b function"

        # 2. Clean up old loader block if it exists
        remove_block "$config_file" "bootstrap-cli setup"

        # 3. Append the new lightweight loader block
        log_info "Adding bootstrap loader to $config_file..."
        cat << 'EOF' >> "$config_file"

# >>> bootstrap-cli setup >>>
export BOOTSTRAP_DIR="$HOME/.config/bootstrap"
[ -f "$BOOTSTRAP_DIR/b.sh" ] && . "$BOOTSTRAP_DIR/b.sh"
# <<< bootstrap-cli setup <<<
EOF
    done

    # Initialize the last update timestamp to prevent immediate update on first execution (Fix 2)
    local last_update_file="$routes_dir/.last_b_update"
    date +%s 2>/dev/null > "$last_update_file" || date +%s > "$last_update_file"
}

# Only execute installation if not sourced (Fix 3)
if [ "$is_sourced" = false ]; then
    install_bootstrap

    # Load the b function immediately in the current subshell
    if [ -f "$HOME/.config/bootstrap/b.sh" ]; then
        . "$HOME/.config/bootstrap/b.sh"
    fi

    # Handle sourcing the shell configuration file or printing instructions (Fix 1)
    echo
    log_success "Bootstrap CLI installed successfully!"
    log_info "To start using the 'b' command in this terminal session, run:"
    if [ -f "$HOME/.zshrc" ]; then
        echo "  source ~/.zshrc"
    else
        echo "  source ~/.bashrc"
    fi
else
    # Sourced mode (e.g., when sourced by installers or manually by user)
    # Load the b function in the current shell context
    if [ -f "$HOME/.config/bootstrap/b.sh" ]; then
        . "$HOME/.config/bootstrap/b.sh"
    fi
fi

