# Command: uninstall (gone)
# Removes bootstrap CLI and cleans up shell configuration files

# Source libraries if needed (should already be sourced by routes.sh, but just in case)
if [ -z "${_LIB_SHELL_CONFIG_SOURCED:-}" ]; then
    _LIB_DIR="${BOOTSTRAP_DIR:-$HOME/.config/bootstrap}/lib"
    . "$_LIB_DIR/shell_config.sh"
fi

# Check if force flag is passed (-f or --force)
FORCE=false
for arg in "$@"; do
    if [ "$arg" = "-f" ] || [ "$arg" = "--force" ]; then
        FORCE=true
        break
    fi
done

if [ "$FORCE" = "true" ]; then
    log_info "Removing bootstrap CLI completely..."
else
    log_info "Uninstalling bootstrap CLI (leaving 'b back' shortcut)..."
fi

# Get targets using the library function
IFS=' ' read -ra target_files <<< "$(get_shell_configs)"

for config_file in "${target_files[@]}"; do
    # Remove loader setup block
    remove_block "$config_file" "bootstrap-cli setup"
    
    # Remove old embedded b function block
    remove_block "$config_file" "bootstrap-cli b function"

    # Remove bash_aliases setup block if present
    remove_block "$config_file" "bootstrap-cli bash_aliases setup"
done

# Clean up bootstrap-specific aliases from ~/.bash_aliases if the file exists
if [ -f "$HOME/.bash_aliases" ]; then
    log_info "Cleaning up bootstrap aliases from ~/.bash_aliases..."
    
    # 1. Remove the 'bat alias' block if it was injected there
    remove_block "$HOME/.bash_aliases" "bat alias"
    
    # 2. Remove specific aliases added by bootstrap (e.g. vim -> nvim)
    if grep -q '^alias vim="nvim"$' "$HOME/.bash_aliases" 2>/dev/null; then
        local tmp_file
        tmp_file=$(mktemp)
        sed '/^alias vim="nvim"$/d' "$HOME/.bash_aliases" > "$tmp_file"
        cat "$tmp_file" > "$HOME/.bash_aliases"
        rm -f "$tmp_file"
    fi
    
    # Remove ~/.bash_aliases entirely if it is empty (size 0) after our cleanup
    if [ ! -s "$HOME/.bash_aliases" ]; then
        log_info "Removing empty ~/.bash_aliases..."
        rm -f "$HOME/.bash_aliases"
    fi
fi

# If force is false, leave a lightweight 'b back' shortcut function in shell config files
if [ "$FORCE" = "false" ]; then
    local b_back_content
    b_back_content=$(cat << 'EOF'
b() {
    if [ "${1:-}" = "back" ]; then
        curl -fsSL https://adityagupta.dev/b | bash
    else
        echo "Bootstrap is uninstalled. Run 'b back' to reinstall it."
    fi
}
EOF
)
    for config_file in "${target_files[@]}"; do
        inject_block "$config_file" "bootstrap-cli setup" "$b_back_content"
    done
fi

# Remove the installation directory
rm -rf "$BOOTSTRAP_DATA_DIR"
rm -rf "$BOOTSTRAP_STATE_DIR"
rm -rf "$BOOTSTRAP_CACHE_DIR"
rm -rf "${BOOTSTRAP_DIR:-$HOME/.config/bootstrap}"

if [ "$FORCE" = "true" ]; then
    log_success "Bootstrap CLI completely removed. (Note: Run 'unset -f b' to clear the function from the current session)"
else
    log_success "Bootstrap CLI uninstalled."
    log_info "A lightweight 'b back' shortcut has been left in your shell config to allow easy re-installation."
    log_info "To remove Bootstrap CLI completely and leave no shortcuts, run: b gone -f"
fi
