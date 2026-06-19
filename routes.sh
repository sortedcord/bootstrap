#!/usr/bin/env bash

# Central routing script for bootstrap installers.
# This file is updated automatically by the 'b' command.

if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: This script must be run using bash." >&2
    exit 1
fi

declare -A INSTALLERS=(
    [nvim]="Install Neovim 0.11.7 and configuration"
    [yazi]="Install Yazi terminal file manager and dependencies"
    [zoxide]="Install Zoxide directory jumper"
)
# Order in which installers should be displayed
INSTALLER_KEYS=(nvim yazi zoxide)

SCRIPT_NAMES="${1:-}"
if [ -z "$SCRIPT_NAMES" ] || [ "$SCRIPT_NAMES" = "-h" ] || [ "$SCRIPT_NAMES" = "--help" ]; then
    SCRIPT_NAMES="all"
fi
shift

# Split comma-separated script names
IFS=',' read -ra SCRIPTS <<< "$SCRIPT_NAMES"

for script in "${SCRIPTS[@]}"; do
    # Check if it is a registered installer
    if [[ -n "${INSTALLERS[$script]:-}" ]]; then
        # Capitalize first letter for display (e.g. nvim -> Neovim)
        display_name="$(echo "${script:0:1}" | tr '[:lower:]' '[:upper:]')${script:1}"
        echo "Launching ${display_name} installer..."
        curl -fsSL "https://git.adityagupta.dev/sortedcord/bootstrap/raw/branch/master/installers/install_${script}.sh" | bash -s -- "$@"

    else
        # Handle non-installer commands
        case "$script" in
            all)
                echo "Available bootstrap commands:"
                # Non-installers first (aligned to 6 chars width)
                printf "  %-6s - %s\n" "all" "List all available commands"
                printf "  %-6s - %s\n" "conf" "Edit config (e.g. b conf nvim)"
                printf "  %-6s - %s\n" "bye" "Uninstall Bootstrap CLI helper"
                # Installers second (iterating procedurally)
                for key in "${INSTALLER_KEYS[@]}"; do
                    printf "  %-6s - %s\n" "$key" "${INSTALLERS[$key]}"
                done
                ;;
            conf)
                config_name="${1:-}"
                if [ -z "$config_name" ]; then
                    echo "Usage: b conf <config_name> [files...]" >&2
                    exit 1
                fi
                shift

                config_dir=""
                if [ -d "$HOME/.config/$config_name" ]; then
                    config_dir="$HOME/.config/$config_name"
                else
                    config_dir=$(find "$HOME/.config" -mindepth 1 -maxdepth 1 -type d -iname "*$config_name*" 2>/dev/null | head -n1)
                fi

                if [ -n "$config_dir" ] && [ -d "$config_dir" ]; then
                    cd "$config_dir"
                    editor="${EDITOR:-nvim}"
                    if [ $# -gt 0 ]; then
                        $editor "$@"
                    else
                        $editor .
                    fi
                else
                    echo "Could not find that directory" >&2
                    exit 1
                fi
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
                echo "Error: Unknown command '$script'." >&2
                echo "Run 'b all' to list all available commands." >&2
                exit 1
                ;;
        esac
    fi
done
