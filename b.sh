# >>> bootstrap-cli b function >>>
# Shortcut for downloading and running bootstrap/install scripts
b() {
    if [ -z "${1:-}" ]; then
        echo "Usage: b <script1,script2,...> [args...]" >&2
        return 1
    fi

    local routes_dir="$HOME/.config/bootstrap"
    local routes_file="$routes_dir/lib/routes.sh"
    local last_update_file="$routes_dir/.last_b_update"

    local current_time
    current_time=$(date +%s 2>/dev/null || date +%s)
    local last_update=0
    [ -f "$last_update_file" ] && last_update=$(cat "$last_update_file" 2>/dev/null || echo 0)

    # Version comparison helper (returns 0 if $1 < $2, 1 otherwise)
    _version_lt() {
        [ "$1" = "$2" ] && return 1
        local IFS=.
        local i ver1=($1) ver2=($2)
        for ((i=${#ver1[@]}; i<3; i++)); do ver1[i]=0; done
        for ((i=${#ver2[@]}; i<3; i++)); do ver2[i]=0; done
        for ((i=0; i<3; i++)); do
            if ((10#${ver1[i]} < 10#${ver2[i]})); then
                return 0
            elif ((10#${ver1[i]} > 10#${ver2[i]})); then
                return 1
            fi
        done
        return 1
    }

    # Auto-update check: once every 24 hours, or if routes.sh or VERSION is missing
    # Skip when uninstalling — no point updating bootstrap if we're about to remove it
    if [ "${1:-}" != "gone" ]; then
        if [ $((current_time - last_update)) -gt 86400 ] || [ ! -f "$routes_file" ] || [ ! -f "$routes_dir/VERSION" ]; then
            # Update the timestamp immediately to prevent spamming on connection errors
            echo "$current_time" > "$last_update_file"

            local base_url="https://git.adityagupta.dev/sortedcord/bootstrap/raw/branch/master"
            local local_ver="0.0.0"
            [ -f "$routes_dir/VERSION" ] && local_ver=$(cat "$routes_dir/VERSION" 2>/dev/null | tr -d '[:space:]')

            local remote_ver
            if remote_ver=$(curl -fsSL "$base_url/VERSION" 2>/dev/null); then
                remote_ver=$(echo "$remote_ver" | tr -d '[:space:]')
                if [ -n "$remote_ver" ] && _version_lt "$local_ver" "$remote_ver"; then
                    echo "New version $remote_ver available (local: $local_ver). Auto-updating..." >&2
                    local tmp_bootstrap
                    tmp_bootstrap="$(mktemp)"
                    if curl -fsSL "$base_url/bootstrap.sh" -o "$tmp_bootstrap" 2>/dev/null; then
                        bash "$tmp_bootstrap" >/dev/null 2>&1
                    fi
                    rm -f "$tmp_bootstrap"
                fi
            fi
        fi
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
        opts="all con gone up ware bware"
        
        local routes_dir="$HOME/.config/bootstrap"
        local installer_keys=""
        if [ -d "$routes_dir/installers" ]; then
            for f in "$routes_dir/installers"/install_*.sh; do
                if [ -f "$f" ]; then
                    local tool
                    tool=$(grep -E "^# Tool:" "$f" | head -n1 | sed -E 's/^# Tool:\s*//I')
                    if [ -n "$tool" ]; then
                        installer_keys="$installer_keys $tool"
                    fi
                fi
            done
        fi
        if [ -n "$installer_keys" ]; then
            opts="$opts $installer_keys"
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

    # If completing arguments for 'b ware <tool>' or 'b bware <tool>'
    if [ "$COMP_CWORD" -eq 2 ] && { [ "$prev" = "ware" ] || [ "$prev" = "bware" ]; }; then
        local routes_dir="$HOME/.config/bootstrap"
        local installer_keys=""
        if [ -d "$routes_dir/installers" ]; then
            for f in "$routes_dir/installers"/install_*.sh; do
                if [ -f "$f" ]; then
                    local tool
                    tool=$(grep -E "^# Tool:" "$f" | head -n1 | sed -E 's/^# Tool:\s*//I')
                    if [ -n "$tool" ]; then
                        installer_keys="$installer_keys $tool"
                    fi
                fi
            done
        fi
        [ -z "$installer_keys" ] && installer_keys="agy bat node nvim pnpm rust starship yay yazi zoxide"

        # Support comma-separated completions (e.g. b ware nvim,ya<TAB>)
        if [[ "$cur" == *,* ]]; then
            local prefix="${cur%,*}"
            local last="${cur##*,}"
            local matches
            matches=$(compgen -W "$installer_keys" -- "$last")
            if [ -n "$matches" ]; then
                COMPREPLY=()
                for m in $matches; do
                    if [[ ",$prefix," != *",$m,"* ]]; then
                        COMPREPLY+=("${prefix},${m}")
                    fi
                done
            fi
            return 0
        fi

        COMPREPLY=( $(compgen -W "$installer_keys" -- "$cur") )
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
