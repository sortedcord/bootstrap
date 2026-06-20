# >>> bootstrap-cli b function >>>
# Shortcut for downloading and running bootstrap/install scripts
b() {
    if [ -z "${1:-}" ]; then
        echo "Usage: b <script1,script2,...> [args...]" >&2
        return 1
    fi

    local routes_dir="$HOME/.config/bootstrap"
    local routes_file="$routes_dir/routes.sh"
    local last_update_file="$routes_dir/.last_b_update"

    local current_time
    current_time=$(date +%s 2>/dev/null || date +%s)
    local last_update=0
    [ -f "$last_update_file" ] && last_update=$(cat "$last_update_file" 2>/dev/null || echo 0)

    # Update everything once every 24 hours, or if routes.sh is missing
    if [ $((current_time - last_update)) -gt 86400 ] || [ ! -f "$routes_file" ]; then
        local bootstrap_url="https://git.adityagupta.dev/sortedcord/bootstrap/raw/branch/master/bootstrap.sh"
        local tmp_bootstrap
        tmp_bootstrap="$(mktemp)"
        
        # Download and run the bootstrap installer to update all CLI files
        if curl -fsSL "$bootstrap_url" -o "$tmp_bootstrap" 2>/dev/null || wget -qO "$tmp_bootstrap" "$bootstrap_url" 2>/dev/null; then
            if bash "$tmp_bootstrap"; then
                echo "$current_time" > "$last_update_file"
            fi
        fi
        rm -f "$tmp_bootstrap"
    fi

    if [ ! -f "$routes_file" ]; then
        echo "Error: Routes file not found at $routes_file and could not be downloaded." >&2
        return 1
    fi

    # Execute the routes file
    bash "$routes_file" "$@"
}

# Autocompletion for the b command in Bash
_b_completion() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # If completing the first argument after 'b'
    if [ "$COMP_CWORD" -eq 1 ]; then
        opts="all con bye"
        
        local routes_file="$HOME/.config/bootstrap/routes.sh"
        if [ -f "$routes_file" ]; then
            # Extract installer keys dynamically from the routes.sh file
            local installer_keys
            installer_keys=$(grep -E "^INSTALLER_KEYS=" "$routes_file" 2>/dev/null | sed -E 's/INSTALLER_KEYS=\(([^)]+)\)/\1/' 2>/dev/null)
            if [ -n "$installer_keys" ]; then
                opts="$opts $installer_keys"
            fi
        fi

        # Support comma-separated completions (e.g. b nvim,ya<TAB>)
        if [[ "$cur" == *,* ]]; then
            local prefix="${cur%,*}"
            local last="${cur##*,}"
            local matches
            matches=$(compgen -W "$opts" -- "$last")
            if [ -n "$matches" ]; then
                COMPREPLY=()
                for m in $matches; do
                    # Do not offer the command if it's already in the comma-separated list
                    if [[ ",$prefix," != *",$m,"* ]]; then
                        COMPREPLY+=("${prefix},${m}")
                    fi
                done
            fi
            return 0
        fi

        COMPREPLY=( $(compgen -W "$opts" -- "$cur") )
        return 0
    fi

    # If completing arguments for 'b con <config_dir>'
    if [ "$COMP_CWORD" -eq 2 ] && [ "$prev" = "con" ]; then
        # List of directories in ~/.config/ to choose from
        local config_dirs
        config_dirs=$(find "$HOME/.config" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null)
        COMPREPLY=( $(compgen -W "$config_dirs" -- "$cur") )
        return 0
    fi
}

# Register completion for b command
if [ -n "${BASH_VERSION:-}" ]; then
    complete -F _b_completion b
fi
# <<< bootstrap-cli b function <<<
