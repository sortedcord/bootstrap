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

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null || pwd)"

# Source registry
if [ -f "$_SCRIPT_DIR/registry.sh" ]; then
    . "$_SCRIPT_DIR/registry.sh"
elif [ -f "$BOOTSTRAP_DIR/registry.sh" ]; then
    . "$BOOTSTRAP_DIR/registry.sh"
else
    # Standalone/remote fallback: download registry
    _tmp_registry=$(mktemp)
    BOOTSTRAP_BASE_URL="${BOOTSTRAP_BASE_URL:-https://git.adityagupta.dev/sortedcord/bootstrap/raw/branch/master}"
    BOOTSTRAP_FALLBACK_URL="${BOOTSTRAP_FALLBACK_URL:-https://raw.githubusercontent.com/sortedcord/bootstrap/refs/heads/master}"
    if has_command curl; then
        curl -fsSL "${BOOTSTRAP_BASE_URL}/registry.sh" -o "$_tmp_registry" 2>/dev/null || \
        curl -fsSL "${BOOTSTRAP_FALLBACK_URL}/registry.sh" -o "$_tmp_registry" 2>/dev/null
    elif has_command wget; then
        wget -qO "$_tmp_registry" "${BOOTSTRAP_BASE_URL}/registry.sh" 2>/dev/null || \
        wget -qO "$_tmp_registry" "${BOOTSTRAP_FALLBACK_URL}/registry.sh" 2>/dev/null
    fi
    if [ -s "$_tmp_registry" ]; then
        . "$_tmp_registry"
    else
        # Critical fallback
        declare -A INSTALLERS
        declare -A INSTALLER_DISPLAYS
        INSTALLER_KEYS=()
    fi
    rm -f "$_tmp_registry"
fi

# Helper function to run/edit installer scripts
run_ware() {
    local tool="$1"
    shift
    
    # Check if -y is in the remaining arguments
    local bypass_edit=false
    local cmd_args=()
    for arg in "$@"; do
        if [ "$arg" = "-y" ]; then
            bypass_edit=true
        else
            cmd_args+=("$arg")
        fi
    done

    # Resolve display name from metadata or fallback
    local display_name="${INSTALLER_DISPLAYS[$tool]:-}"
    if [ -z "$display_name" ]; then
        display_name="$(echo "${tool:0:1}" | tr '[:lower:]' '[:upper:]')${tool:1}"
    fi
    
    # Check for local installer first
    local local_installer="$BOOTSTRAP_DIR/installers/install_${tool}.sh"
    local temp_script
    temp_script=$(mktemp --suffix=".sh" 2>/dev/null || mktemp)

    if [ -f "$local_installer" ]; then
        cp "$local_installer" "$temp_script"
    else
        BOOTSTRAP_BASE_URL="${BOOTSTRAP_BASE_URL:-https://git.adityagupta.dev/sortedcord/bootstrap/raw/branch/master}"
        BOOTSTRAP_FALLBACK_URL="${BOOTSTRAP_FALLBACK_URL:-https://raw.githubusercontent.com/sortedcord/bootstrap/refs/heads/master}"
        local installer_path="installers/install_${tool}.sh"
        local download_status=0

        log_info "Downloading ${display_name} installer..."
        if has_command curl; then
            curl -fsSL "${BOOTSTRAP_BASE_URL}/${installer_path}" -o "$temp_script"
            download_status=$?
            if [ "$download_status" -ne 0 ]; then
                log_warn "Failed to download installer from primary URL, trying fallback..."
                curl -fsSL "${BOOTSTRAP_FALLBACK_URL}/${installer_path}" -o "$temp_script"
                download_status=$?
            fi
        elif has_command wget; then
            wget -qO "$temp_script" "${BOOTSTRAP_BASE_URL}/${installer_path}"
            download_status=$?
            if [ "$download_status" -ne 0 ]; then
                log_warn "Failed to download installer from primary URL, trying fallback..."
                wget -qO "$temp_script" "${BOOTSTRAP_FALLBACK_URL}/${installer_path}"
                download_status=$?
            fi
        else
            log_error "Neither curl nor wget is installed to download the installer."
            rm -f "$temp_script"
            exit 1
        fi

        if [ "$download_status" -ne 0 ]; then
            log_error "Failed to download the installer from both primary and fallback URLs."
            rm -f "$temp_script"
            exit 1
        fi
    fi

    # Edit if bypass_edit is false
    if [ "$bypass_edit" = "false" ]; then
        local editor="${EDITOR:-}"
        if [ -z "$editor" ]; then
            if has_command nvim; then
                editor="nvim"
            elif has_command vim; then
                editor="vim"
            elif has_command nano; then
                editor="nano"
            else
                editor="vi"
            fi
        fi
        log_info "Opening ${display_name} installer for editing using $editor..."
        $editor "$temp_script"
    fi

    # Run the script (edited or unchanged)
    log_info "Running ${display_name} installer..."
    bash "$temp_script" "${cmd_args[@]}"
    local run_status=$?
    
    # Cleanup
    rm -f "$temp_script"
    return "$run_status"
}

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
        run_ware "$script" -y "$@"

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
            ware|bware)
                tools_arg="${1:-}"
                if [ -z "$tools_arg" ]; then
                    echo "Available tools:"
                    for key in "${INSTALLER_KEYS[@]}"; do
                        printf "  %-10s - %s\n" "$key" "${INSTALLERS[$key]}"
                    done
                    exit 0
                fi
                shift
                IFS=',' read -ra WARE_TOOLS <<< "$tools_arg"
                for tool in "${WARE_TOOLS[@]}"; do
                    if [[ -z "${INSTALLERS[$tool]:-}" ]]; then
                        log_error "Unknown tool '$tool'."
                        exit 1
                    fi
                done
                for tool in "${WARE_TOOLS[@]}"; do
                    run_ware "$tool" "$@"
                done
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
