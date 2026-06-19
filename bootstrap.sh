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
    local script_name="$1"
    shift
    curl -fsSL "https://adityagupta.dev/b/${script_name}" | bash -s -- "$@"
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
