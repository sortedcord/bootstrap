#!/usr/bin/env bash

# This is a metascript called by parent scripts to verify the execution environment.
# It checks if the current shell is bash or not. If not, it terminates execution.

if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: This script must be run using bash." >&2
    exit 1
fi

# Add a shortcut function 'b' to user's shell configurations if not already present
add_b_alias() {
    local target_files=()
    [ -f "$HOME/.bashrc" ] && target_files+=("$HOME/.bashrc")
    [ -f "$HOME/.zshrc" ] && target_files+=("$HOME/.zshrc")

    for config_file in "${target_files[@]}"; do
        # 1. Clean up old unmarkered function if it exists
        if grep -q "Shortcut for downloading bootstrap/install scripts" "$config_file" 2>/dev/null; then
            sed -i '/# Shortcut for downloading bootstrap\/install scripts/,/^}/d' "$config_file"
        fi

        # 2. Clean up old markered function if it exists
        if grep -q "# >>> bootstrap-cli b function >>>" "$config_file" 2>/dev/null; then
            sed -i '/# >>> bootstrap-cli b function >>>/,/# <<< bootstrap-cli b function <<</d' "$config_file"
        fi

        # 3. Append the new markered function block
        echo "Adding/updating helper function 'b' to $config_file..."
        cat << 'EOF' >> "$config_file"

# >>> bootstrap-cli b function >>>
# Shortcut for downloading and running bootstrap/install scripts
b() {
    if [ -z "$1" ]; then
        echo "Usage: b <script_name> [args...]" >&2
        return 1
    fi

    local routes_dir="$HOME/.config/bootstrap"
    local routes_file="$routes_dir/routes.sh"
    local routes_url="https://git.adityagupta.dev/sortedcord/bootstrap/raw/branch/master/routes.sh"

    mkdir -p "$routes_dir"

    # Attempt to update the routes.sh file
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$routes_url" -o "$routes_file" 2>/dev/null
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$routes_file" "$routes_url" 2>/dev/null
    fi

    if [ ! -f "$routes_file" ]; then
        echo "Error: Routes file not found at $routes_file and could not be downloaded." >&2
        return 1
    fi

    bash "$routes_file" "$@"
}
# <<< bootstrap-cli b function <<<
EOF
    done
}

add_b_alias

# Source ~/.bashrc to make changes immediately available
if [ -f "$HOME/.bashrc" ]; then
    echo "Sourcing ~/.bashrc..."
    . "$HOME/.bashrc"
fi
