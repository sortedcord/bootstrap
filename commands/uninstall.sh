# Command: uninstall (bye)
# Removes bootstrap CLI and cleans up shell configuration files

# Source libraries if needed (should already be sourced by routes.sh, but just in case)
if [ -z "${_LIB_SHELL_CONFIG_SOURCED:-}" ]; then
    _LIB_DIR="${BOOTSTRAP_DIR:-$HOME/.config/bootstrap}/lib"
    . "$_LIB_DIR/shell_config.sh"
fi

log_info "Removing bootstrap CLI completely..."

# Get targets using the library function
IFS=' ' read -ra target_files <<< "$(get_shell_configs)"

for config_file in "${target_files[@]}"; do
    # Remove loader setup block
    remove_block "$config_file" "bootstrap-cli setup"
    
    # Remove old embedded b function block
    remove_block "$config_file" "bootstrap-cli b function"
done

# Remove the installation directory
rm -rf "${BOOTSTRAP_DIR:-$HOME/.config/bootstrap}"

log_success "Bootstrap CLI removed successfully. (Note: Run 'unset -f b' to clear it from the current session)"
