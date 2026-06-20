#!/usr/bin/env bash
# Central routing script for bootstrap installers.
# This file is updated automatically by the 'b' command.

BOOTSTRAP_DIR="${BOOTSTRAP_DIR:-$HOME/.config/bootstrap}"

# Source common library
if [ -f "$BOOTSTRAP_DIR/lib/common.sh" ]; then
    . "$BOOTSTRAP_DIR/lib/common.sh"
else
    # Fallback/Bootstrap case if lib is not installed yet
    echo "Error: Bootstrap libraries not found at $BOOTSTRAP_DIR/lib/" >&2
    exit 1
fi

require_bash

# Registry of installers
declare -A INSTALLERS=(
    [agy]="Install Antigravity CLI"
    [bat]="Install Bat (alternative to cat) and configure alias"
    [node]="Install Node.js (LTS) and NVM"
    [nvim]="Install Neovim 0.11.7 and configuration"
    [pnpm]="Install pnpm package manager"
    [rust]="Install Rustup and Rust compiler/toolchain"
    [starship]="Install Starship shell prompt"
    [yay]="Install Yay AUR helper"
    [yazi]="Install Yazi terminal file manager and dependencies"
    [zoxide]="Install Zoxide directory jumper"
)
# Order in which installers should be displayed
INSTALLER_KEYS=(agy bat node nvim pnpm rust starship yay yazi zoxide)

SCRIPT_NAMES="${1:-}"
if [ -z "$SCRIPT_NAMES" ] || [ "$SCRIPT_NAMES" = "-h" ] || [ "$SCRIPT_NAMES" = "--help" ]; then
    SCRIPT_NAMES="all"
fi

# Guard shift (Fix 1)
if [ $# -gt 0 ]; then
    shift
fi

# Split comma-separated script names
IFS=',' read -ra SCRIPTS <<< "$SCRIPT_NAMES"

for script in "${SCRIPTS[@]}"; do
    # Check if it is a registered installer
    if [[ -n "${INSTALLERS[$script]:-}" ]]; then
        # Capitalize first letter for display (e.g. nvim -> Neovim)
        display_name="$(echo "${script:0:1}" | tr '[:lower:]' '[:upper:]')${script:1}"
        log_info "Launching ${display_name} installer..."
        
        # Check for local installer first, fallback to curl
        local_installer="$BOOTSTRAP_DIR/installers/install_${script}.sh"
        if [ -f "$local_installer" ]; then
            bash "$local_installer" "$@"
        else
            BOOTSTRAP_BASE_URL="${BOOTSTRAP_BASE_URL:-https://git.adityagupta.dev/sortedcord/bootstrap/raw/branch/master}"
            BOOTSTRAP_FALLBACK_URL="${BOOTSTRAP_FALLBACK_URL:-https://raw.githubusercontent.com/sortedcord/bootstrap/refs/heads/master}"
            installer_path="installers/install_${script}.sh"
            download_status=0

            if has_command curl; then
                curl -fsSL "${BOOTSTRAP_BASE_URL}/${installer_path}" | bash -s -- "$@"
                download_status="${PIPESTATUS[0]}"
                if [ "$download_status" -ne 0 ]; then
                    log_warn "Failed to download installer from primary URL, trying fallback..."
                    curl -fsSL "${BOOTSTRAP_FALLBACK_URL}/${installer_path}" | bash -s -- "$@"
                    download_status="${PIPESTATUS[0]}"
                fi
            elif has_command wget; then
                wget -qO- "${BOOTSTRAP_BASE_URL}/${installer_path}" | bash -s -- "$@"
                download_status="${PIPESTATUS[0]}"
                if [ "$download_status" -ne 0 ]; then
                    log_warn "Failed to download installer from primary URL, trying fallback..."
                    wget -qO- "${BOOTSTRAP_FALLBACK_URL}/${installer_path}" | bash -s -- "$@"
                    download_status="${PIPESTATUS[0]}"
                fi
            else
                log_error "Neither curl nor wget is installed to download the installer."
                exit 1
            fi

            if [ "$download_status" -ne 0 ]; then
                log_error "Failed to download the installer from both primary and fallback URLs."
                exit 1
            fi
        fi

    else
        # Handle non-installer commands
        case "$script" in
            all)
                if [ -f "$BOOTSTRAP_DIR/commands/help.sh" ]; then
                    . "$BOOTSTRAP_DIR/commands/help.sh"
                else
                    log_error "Help command script not found."
                    exit 1
                fi
                ;;
            con)
                if [ -f "$BOOTSTRAP_DIR/commands/con.sh" ]; then
                    . "$BOOTSTRAP_DIR/commands/con.sh" "$@"
                else
                    log_error "Config editor command script not found."
                    exit 1
                fi
                ;;
            up)
                if [ -f "$BOOTSTRAP_DIR/commands/up.sh" ]; then
                    . "$BOOTSTRAP_DIR/commands/up.sh" "$@"
                else
                    log_error "Update command script not found."
                    exit 1
                fi
                ;;
            bye)
                if [ -f "$BOOTSTRAP_DIR/commands/uninstall.sh" ]; then
                    . "$BOOTSTRAP_DIR/commands/uninstall.sh"
                else
                    log_error "Uninstall command script not found."
                    exit 1
                fi
                ;;
            *)
                log_error "Unknown command '$script'."
                log_info "Run 'b all' to list all available commands."
                exit 1
                ;;
        esac
    fi
done
