#!/usr/bin/env bash

# This is a metascript called by parent scripts to verify the execution environment.
# It checks if the current shell is bash or not. If not, it terminates execution.

if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: This script must be run using bash." >&2
    exit 1
fi

# Detect if the script is sourced
is_sourced=false
if [ -n "${ZSH_VERSION:-}" ]; then
    case $ZSH_EVAL_CONTEXT in
        *file*) is_sourced=true ;;
    esac
elif [ -n "${BASH_VERSION:-}" ]; then
    if [ -n "${BASH_SOURCE[0]:-}" ] && [ "${BASH_SOURCE[0]}" != "$0" ]; then
        is_sourced=true
    fi
fi

# Install/update the bootstrap loader and download b.sh & routes.sh
install_bootstrap() {
    local target_files=()
    [ -f "$HOME/.bashrc" ] && target_files+=("$HOME/.bashrc")
    [ -f "$HOME/.zshrc" ] && target_files+=("$HOME/.zshrc")

    local routes_dir="$HOME/.config/bootstrap"
    mkdir -p "$routes_dir"

    # Download b.sh and routes.sh from the repository, with fallback to local files if running inside the repo
    echo "Downloading bootstrap scripts..."
    local b_url="https://git.adityagupta.dev/sortedcord/bootstrap/raw/branch/master/b.sh"
    local routes_url="https://git.adityagupta.dev/sortedcord/bootstrap/raw/branch/master/routes.sh"

    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    if [ -f "$script_dir/b.sh" ] && [ -f "$script_dir/routes.sh" ]; then
        echo "Using local files from repository..."
        cp "$script_dir/b.sh" "$routes_dir/b.sh"
        cp "$script_dir/routes.sh" "$routes_dir/routes.sh"
    else
        if command -v curl >/dev/null 2>&1; then
            curl -fsSL "$b_url" -o "$routes_dir/b.sh"
            curl -fsSL "$routes_url" -o "$routes_dir/routes.sh"
        elif command -v wget >/dev/null 2>&1; then
            wget -qO "$routes_dir/b.sh" "$b_url"
            wget -qO "$routes_dir/routes.sh" "$routes_url"
        else
            echo "Error: Neither curl nor wget is installed." >&2
            exit 1
        fi
    fi

    # Set up shell configuration files
    for config_file in "${target_files[@]}"; do
        # 1. Clean up old embedded function block if it exists (from previous setup)
        if grep -q "# >>> bootstrap-cli b function >>>" "$config_file" 2>/dev/null; then
            sed -i '/# >>> bootstrap-cli b function >>>/,/# <<< bootstrap-cli b function <<</d' "$config_file"
        fi

        # 2. Clean up old loader block if it exists
        if grep -q "# >>> bootstrap-cli setup >>>" "$config_file" 2>/dev/null; then
            sed -i '/# >>> bootstrap-cli setup >>>/,/# <<< bootstrap-cli setup <<</d' "$config_file"
        fi

        # 3. Append the new lightweight loader block
        echo "Adding bootstrap loader to $config_file..."
        cat << 'EOF' >> "$config_file"

# >>> bootstrap-cli setup >>>
export BOOTSTRAP_DIR="$HOME/.config/bootstrap"
[ -f "$BOOTSTRAP_DIR/b.sh" ] && . "$BOOTSTRAP_DIR/b.sh"
# <<< bootstrap-cli setup <<<
EOF
    done
}

install_bootstrap

# Load the b function immediately in the current subshell
if [ -f "$HOME/.config/bootstrap/b.sh" ]; then
    . "$HOME/.config/bootstrap/b.sh"
fi

# Handle sourcing the shell configuration file
if [ "$is_sourced" = true ]; then
    if [ -n "${ZSH_VERSION:-}" ] && [ -f "$HOME/.zshrc" ]; then
        echo "Sourcing ~/.zshrc..."
        . "$HOME/.zshrc"
    elif [ -n "${BASH_VERSION:-}" ] && [ -f "$HOME/.bashrc" ]; then
        echo "Sourcing ~/.bashrc..."
        . "$HOME/.bashrc"
    fi
else
    echo
    echo "Bootstrap CLI installed successfully!"
    echo "To start using the 'b' command in this terminal session, run:"
    if [ -n "${ZSH_VERSION:-}" ] || [ -f "$HOME/.zshrc" ]; then
        echo "  source ~/.zshrc"
    else
        echo "  source ~/.bashrc"
    fi
fi
