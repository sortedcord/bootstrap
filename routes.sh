#!/usr/bin/env bash

# Central routing script for bootstrap installers.
# This file is updated automatically by the 'b' command.

if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: This script must be run using bash." >&2
    exit 1
fi

SCRIPT_NAMES="${1:-}"
if [ -z "$SCRIPT_NAMES" ]; then
    echo "Usage: b <script1,script2,...> [args...]" >&2
    exit 1
fi
shift

# Split comma-separated script names
IFS=',' read -ra SCRIPTS <<< "$SCRIPT_NAMES"

for script in "${SCRIPTS[@]}"; do
    case "$script" in
        nvim)
            echo "Launching Neovim installer..."
            curl -fsSL "https://git.adityagupta.dev/sortedcord/bootstrap/raw/branch/master/installers/install_nvim.sh" | bash -s -- "$@"
            ;;
        yazi)
            echo "Launching Yazi installer..."
            curl -fsSL "https://git.adityagupta.dev/sortedcord/bootstrap/raw/branch/master/installers/install_yazi.sh" | bash -s -- "$@"
            ;;
        bye)
            echo "Removing bootstrap CLI completely..."
            
            target_files=()
            [ -f "$HOME/.bashrc" ] && target_files+=("$HOME/.bashrc")
            [ -f "$HOME/.zshrc" ] && target_files+=("$HOME/.zshrc")

            for config_file in "${target_files[@]}"; do
                # Remove loader setup
                if grep -q "# >>> bootstrap-cli setup >>>" "$config_file" 2>/dev/null; then
                    sed -i '/# >>> bootstrap-cli setup >>>/,/# <<< bootstrap-cli setup <<</d' "$config_file"
                    echo "Removed bootstrap loader from $config_file"
                fi
                # Remove any old embedded 'b function' blocks if they exist
                if grep -q "# >>> bootstrap-cli b function >>>" "$config_file" 2>/dev/null; then
                    sed -i '/# >>> bootstrap-cli b function >>>/,/# <<< bootstrap-cli b function <<</d' "$config_file"
                    echo "Removed old bootstrap function from $config_file"
                fi
            done

            rm -rf "$HOME/.config/bootstrap"
            echo "Bootstrap CLI removed successfully. (Note: Run 'unset -f b' to clear it from the current session)"
            ;;
        *)
            echo "Error: Unknown script '$script'." >&2
            echo "Available scripts: nvim, yazi, bye" >&2
            exit 1
            ;;
    esac
done
