#!/usr/bin/env bash
# Shell configuration file manipulation utilities for bootstrap CLI

if [ -n "${_LIB_SHELL_CONFIG_SOURCED:-}" ]; then
    return 0
fi
_LIB_SHELL_CONFIG_SOURCED=1

# Source common utilities if not already loaded
if [ -z "${_LIB_COMMON_SOURCED:-}" ]; then
    _LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    . "$_LIB_DIR/common.sh"
fi

# Find existing target shell RC files
get_shell_configs() {
    local target_files=()
    [ -f "$HOME/.bashrc" ] && target_files+=("$HOME/.bashrc")
    echo "${target_files[@]}"
}

# Remove block from a shell RC file
# Usage: remove_block <config_file> <block_name>
remove_block() {
    local config_file="$1"
    local block_name="$2"

    if [ -f "$config_file" ] && grep -q "# >>> $block_name >>>" "$config_file" 2>/dev/null; then
        log_info "Removing block '$block_name' from $config_file"
        # We use a temporary file to avoid issues with sed in-place options across BSD/GNU
        local tmp_file
        tmp_file=$(mktemp)
        sed "/# >>> $block_name >>>/,/# <<< $block_name <<</d" "$config_file" > "$tmp_file"
        cat "$tmp_file" > "$config_file"
        rm -f "$tmp_file"
    fi
}

# Append block to a shell RC file
# Usage: inject_block <config_file> <block_name> <content>
inject_block() {
    local config_file="$1"
    local block_name="$2"
    local content="$3"

    remove_block "$config_file" "$block_name"

    log_info "Adding block '$block_name' to $config_file"
    {
        echo ""
        echo "# >>> $block_name >>>"
        echo "$content"
        echo "# <<< $block_name <<<"
    } >> "$config_file"
}

# Add alias if not present
# Usage: add_alias_if_missing <config_file> <alias_name> <alias_value>
add_alias_if_missing() {
    local config_file="$1"
    local name="$2"
    local val="$3"

    local target_file="$config_file"
    if [ "$config_file" = "$HOME/.bashrc" ]; then
        # Migrate existing alias from ~/.bashrc if present to avoid duplicates/shadowing
        if [ -f "$HOME/.bashrc" ] && grep -q "alias ${name}=" "$HOME/.bashrc" 2>/dev/null; then
            log_info "Migrating alias $name from ~/.bashrc to ~/.bash_aliases"
            local tmp_file
            tmp_file=$(mktemp)
            sed "/^alias ${name}=/d" "$HOME/.bashrc" > "$tmp_file"
            cat "$tmp_file" > "$HOME/.bashrc"
            rm -f "$tmp_file"
        fi
        target_file="$HOME/.bash_aliases"
    fi

    if [ ! -f "$target_file" ]; then
        touch "$target_file"
    fi

    if ! grep -q "alias $name=" "$target_file" 2>/dev/null; then
        log_info "Adding alias $name to $target_file"
        echo "alias ${name}=\"${val}\"" >> "$target_file"
        return 0 # Added
    fi
    return 1 # Not added (already existed)
}

# Add environment variable if not present
# Usage: add_env_if_missing <config_file> <var_name> <var_value>
add_env_if_missing() {
    local config_file="$1"
    local name="$2"
    local val="$3"

    if [ -f "$config_file" ] && ! grep -q "export $name=" "$config_file" 2>/dev/null; then
        log_info "Setting $name in $config_file"
        echo "export ${name}=\"${val}\"" >> "$config_file"
        return 0 # Added
    fi
    return 1 # Not added
}

# Setup fd symlink for Debian/Ubuntu (fdfind -> fd)
create_fd_symlink() {
    if ! has_command fd && has_command fdfind; then
        log_info "Creating symlink for fd..."
        sudo ln -sf "$(command -v fdfind)" /usr/local/bin/fd
    fi
}

# Export functions and variables for subshells
export _LIB_SHELL_CONFIG_SOURCED=1
export -f get_shell_configs remove_block inject_block add_alias_if_missing add_env_if_missing create_fd_symlink

