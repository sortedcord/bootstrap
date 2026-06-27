#!/usr/bin/env bash
# Central routing script for bootstrap installers.
# This file is updated automatically by the 'b' command.

_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null || pwd)"
BOOTSTRAP_DIR="${BOOTSTRAP_DIR:-$(dirname "$_LIB_DIR")}"

# Fallback to ~/.config/bootstrap if not found locally
if [ ! -d "$BOOTSTRAP_DIR/lib" ]; then
    BOOTSTRAP_DIR="$HOME/.config/bootstrap"
fi
export BOOTSTRAP_DIR

# Source libraries
if [ -f "$BOOTSTRAP_DIR/lib/common.sh" ]; then
    . "$BOOTSTRAP_DIR/lib/common.sh"
    . "$BOOTSTRAP_DIR/lib/rollback.sh"
    . "$BOOTSTRAP_DIR/lib/platform.sh"
    . "$BOOTSTRAP_DIR/lib/shell_config.sh"
    init_rollback_system
else
    echo "Error: Bootstrap libraries not found at $BOOTSTRAP_DIR/lib/" >&2
    exit 1
fi

require_bash

# Source registry
if [ -f "$BOOTSTRAP_DIR/lib/registry.sh" ]; then
    . "$BOOTSTRAP_DIR/lib/registry.sh"
else
    # Critical fallback
    declare -A INSTALLERS
    declare -A INSTALLER_DISPLAYS
    INSTALLER_KEYS=()
fi

# Source plugin system
if [ -f "$BOOTSTRAP_DIR/lib/plugins.sh" ]; then
    . "$BOOTSTRAP_DIR/lib/plugins.sh"
    if [ ! -f "$BOOTSTRAP_DIR/lib/plugin_cache.sh" ]; then
        # Silently auto-generate cache if missing so official plugins are ready instantly
        update_plugin_cache >/dev/null 2>&1 || true
    fi
    if [ -f "$BOOTSTRAP_DIR/lib/plugin_cache.sh" ]; then
        . "$BOOTSTRAP_DIR/lib/plugin_cache.sh"
    fi
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
    
    if [ "$bypass_edit" = "true" ] && [ -f "$local_installer" ]; then
        log_info "Running ${display_name} installer..."
        bash "$local_installer" "${cmd_args[@]}"
        return $?
    fi

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
        curl -fsSL "${BOOTSTRAP_BASE_URL}/${installer_path}" -o "$temp_script"
        download_status=$?
        if [ "$download_status" -ne 0 ]; then
            log_warn "Failed to download installer from primary URL, trying fallback..."
            curl -fsSL "${BOOTSTRAP_FALLBACK_URL}/${installer_path}" -o "$temp_script"
            download_status=$?
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
    setup_uninstaller_context "$tool"
    
    # Set trap for signals to intercept interruption and allow user to choose rollback/keep
    local interrupted=false
    trap 'interrupted=true' INT TERM
    
    bash "$temp_script" "${cmd_args[@]}"
    local run_status=$?
    
    # Restore default traps
    trap - INT TERM
    
    if [ "$run_status" -eq 0 ] && [ "$interrupted" = "false" ]; then
        mark_install_success "$tool"
        source_bashrc
    else
        echo
        if [ "$interrupted" = "true" ]; then
            log_error "Installation of ${display_name} was interrupted."
            run_status=130
        else
            log_error "Installation of ${display_name} failed with exit code $run_status."
        fi
        
        local choice=""
        if [ -t 0 ]; then
            while true; do
                read -r -p "Would you like to [r]ollback partial changes, or [k]eep them to resume/debug later? (r/k): " choice </dev/tty || choice="r"
                case "$choice" in
                    [Rr]*)
                        execute_rollback "$tool"
                        run_status=1
                        break
                        ;;
                    [Kk]*)
                        log_info "Keeping partial changes. Run 'b ${tool}' again to resume."
                        run_status=1
                        break
                        ;;
                    *)
                        echo "Invalid choice. Please enter 'r' or 'k'."
                        ;;
                esac
            done
        else
            # Non-interactive environment, default to safe rollback
            log_warn "Non-interactive shell detected. Defaulting to automatic rollback to keep system clean."
            execute_rollback "$tool"
            run_status=1
        fi
    fi
    
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
            plugin)
                handle_plugin "$@"
                # Once handle_plugin completes, we should exit so it doesn't process more SCRIPTS
                exit $?
                ;;
            all)
                if [ -f "$BOOTSTRAP_DIR/commands/help.sh" ]; then
                    . "$BOOTSTRAP_DIR/commands/help.sh"
                else
                    log_error "Help command script not found."
                    exit 1
                fi
                ;;
            me)
                run_plugin "auth" "me" "$@"
                exit $?
                ;;
            trust)
                run_plugin "auth" "trust" "$@"
                exit $?
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
            gone)
                if [ -f "$BOOTSTRAP_DIR/commands/uninstall.sh" ]; then
                    . "$BOOTSTRAP_DIR/commands/uninstall.sh"
                else
                    log_error "Uninstall command script not found."
                    exit 1
                fi
                ;;
            fall)
                local savepoint_name="${1:-}"
                if [ -z "$savepoint_name" ]; then
                    log_error "Usage: b fall <savepoint_name>"
                    exit 1
                fi
                create_savepoint "$savepoint_name"
                exit 0
                ;;
            rb)
                local target="${1:-}"
                if [ -z "$target" ]; then
                    rollback_bare
                else
                    rollback_to_savepoint "$target"
                fi
                exit 0
                ;;
            *)
                if [[ -n "${PLUGIN_URLS[$script]:-}" ]]; then
                    run_plugin "$script" "$@"
                else
                    log_error "Unknown command '$script'."
                    log_info "Run 'b all' to list all available commands."
                    exit 1
                fi
                ;;
        esac
    fi
done
