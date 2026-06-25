#!/usr/bin/env bash
# Weather Plugin for bootstrap CLI

main() {
    if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
        echo "Usage: b weather [location]"
        echo ""
        echo "Fetches and displays a neat weather forecast."
        echo "If no location is specified, it auto-detects based on your IP."
        return 0
    fi

    local location="$*"
    log_info "Fetching weather forecast..."
    
    if [ -n "$location" ]; then
        # URL encode the location (replace spaces with +)
        local encoded_location
        encoded_location=$(echo "$location" | tr ' ' '+')
        if ! curl -sS "wttr.in/${encoded_location}?0&m"; then
            log_error "Failed to fetch weather for '$location'."
            return 1
        fi
    else
        if ! curl -sS "wttr.in/?0&m"; then
            log_error "Failed to fetch weather."
            return 1
        fi
    fi
}

main "$@"
