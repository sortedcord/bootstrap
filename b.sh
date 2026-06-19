# >>> bootstrap-cli b function >>>
# Shortcut for downloading and running bootstrap/install scripts
b() {
    if [ -z "$1" ]; then
        echo "Usage: b <script1,script2,...> [args...]" >&2
        return 1
    fi

    local routes_dir="$HOME/.config/bootstrap"
    local b_file="$routes_dir/b.sh"
    local routes_file="$routes_dir/routes.sh"
    local last_update_file="$routes_dir/.last_b_update"

    # 1. Check for b.sh updates (once every 24 hours)
    local current_time
    current_time=$(date +%s 2>/dev/null || date +%s)
    local last_update=0
    [ -f "$last_update_file" ] && last_update=$(cat "$last_update_file" 2>/dev/null || echo 0)

    if [ $((current_time - last_update)) -gt 86400 ]; then
        local b_url="https://git.adityagupta.dev/sortedcord/bootstrap/raw/branch/master/b.sh"
        if curl -fsSL "$b_url" -o "$b_file" 2>/dev/null; then
            echo "$current_time" > "$last_update_file"
            . "$b_file" # Load the updated function in current shell context
        fi
    fi

    # 2. Update routes.sh on every run
    local routes_url="https://git.adityagupta.dev/sortedcord/bootstrap/raw/branch/master/routes.sh"
    mkdir -p "$routes_dir"
    if curl -fsSL "$routes_url" -o "$routes_file" 2>/dev/null || wget -qO "$routes_file" "$routes_url" 2>/dev/null; then
        :
    fi

    if [ ! -f "$routes_file" ]; then
        echo "Error: Routes file not found at $routes_file and could not be downloaded." >&2
        return 1
    fi

    # 3. Execute the routes file
    bash "$routes_file" "$@"
}
# <<< bootstrap-cli b function <<<
