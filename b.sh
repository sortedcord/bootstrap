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
# <<< bootstrap-cli b function <<<
