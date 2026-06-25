#!/usr/bin/env bash

if [ -f "$BOOTSTRAP_DIR/lib/json.sh" ]; then
    . "$BOOTSTRAP_DIR/lib/json.sh"
fi

# Parses a plugin manifest using the generic json parser and outputs bash array assignments
parse_plugin_manifest() {
    # The generic parser outputs lines like:
    # plugins.myplugin.version="1.0"
    # plugins.myplugin.url="https://..."
    # We want to extract myplugin and the keys to build:
    # PLUGIN_VERSIONS["myplugin"]="1.0"
    # PLUGIN_URLS["myplugin"]="https://..."
    
    parse_json | awk -F'=' '
    {
        path = $1
        val = $2
        
        # Remove quotes around value for bash array assignment
        gsub(/^"|"$/, "", val)
        
        # Match paths starting with "plugins."
        if (match(path, /^plugins\./)) {
            rest = substr(path, RLENGTH + 1)
            # Find the last dot to separate plugin name from the property key
            last_dot = 0
            for (i=length(rest); i>0; i--) {
                if (substr(rest, i, 1) == ".") {
                    last_dot = i
                    break
                }
            }
            if (last_dot > 0) {
                plugin_name = substr(rest, 1, last_dot - 1)
                prop = substr(rest, last_dot + 1)
                if (prop == "version") {
                    print "PLUGIN_VERSIONS[\"" plugin_name "\"]=\"" val "\""
                } else if (prop == "url") {
                    print "PLUGIN_URLS[\"" plugin_name "\"]=\"" val "\""
                }
            }
        }
    }'
}

# Fetches manifests from sources and generates the cache
update_plugin_cache() {
    local cache_file="$BOOTSTRAP_DIR/lib/plugin_cache.sh"
    local sources_file="$BOOTSTRAP_DIR/plugin_sources.txt"
    
    mkdir -p "$BOOTSTRAP_DIR/lib"
    
    # Initialize cache file
    cat << 'EOF' > "$cache_file"
# Auto-generated plugin cache. Do not edit manually.
declare -g -A PLUGIN_URLS
declare -g -A PLUGIN_VERSIONS
EOF

    if [ -f "$sources_file" ]; then
        while IFS= read -r url || [ -n "$url" ]; do
            # Skip empty lines and comments
            [[ -z "$url" || "$url" == \#* ]] && continue
            
            log_info "Fetching plugin manifest from $url..."
            local manifest_json
            if manifest_json=$(curl -fsSL "$url" 2>/dev/null); then
                echo "$manifest_json" | parse_plugin_manifest >> "$cache_file"
            else
                log_warn "Failed to fetch manifest from $url"
            fi
        done < "$sources_file"
    fi
    
    # Clear downloaded scripts to force lazy re-download of the updated versions
    rm -rf "$BOOTSTRAP_DIR/plugins" 2>/dev/null || true
    
    log_success "Plugin cache updated successfully."
}

manage_plugin_sources() {
    local sources_file="$BOOTSTRAP_DIR/plugin_sources.txt"
    if [ ! -f "$sources_file" ]; then
        touch "$sources_file"
        echo "# Add raw URLs to JSON plugin manifests here, one per line." > "$sources_file"
    fi

    local editor="${EDITOR:-}"
    if [ -z "$editor" ]; then
        if has_command nvim; then editor="nvim"
        elif has_command vim; then editor="vim"
        elif has_command nano; then editor="nano"
        else editor="vi"
        fi
    fi

    $editor "$sources_file"
    
    # Update cache after editing
    update_plugin_cache
}

handle_plugin() {
    local subcmd="${1:-}"
    case "$subcmd" in
        sources)
            manage_plugin_sources
            ;;
        update)
            update_plugin_cache
            ;;
        *)
            log_error "Unknown plugin command: $subcmd"
            log_info "Available commands: b plugin sources, b plugin update"
            exit 1
            ;;
    esac
}

run_plugin() {
    local plugin_name="$1"
    shift
    
    local is_ephemeral=false
    local cmd_args=()
    for arg in "$@"; do
        if [ "$arg" = "-e" ] || [ "$arg" = "--ephemeral" ]; then
            is_ephemeral=true
        else
            cmd_args+=("$arg")
        fi
    done
    
    local url="${PLUGIN_URLS[$plugin_name]:-}"
    if [ -z "$url" ]; then
        log_error "Plugin '$plugin_name' not found in cache."
        return 1
    fi
    
    local local_plugin
    
    if [ "$is_ephemeral" = "true" ]; then
        log_info "Downloading plugin '$plugin_name' (ephemeral)..."
        local_plugin=$(mktemp --suffix=".sh" 2>/dev/null || mktemp)
        if ! curl -fsSL "$url" -o "$local_plugin"; then
            log_error "Failed to download plugin '$plugin_name' from $url"
            rm -f "$local_plugin"
            return 1
        fi
        chmod +x "$local_plugin"
    else
        local plugin_dir="$BOOTSTRAP_DIR/plugins"
        local_plugin="$plugin_dir/${plugin_name}.sh"
        
        if [ ! -f "$local_plugin" ]; then
            log_info "Downloading plugin '$plugin_name'..."
            mkdir -p "$plugin_dir"
            if ! curl -fsSL "$url" -o "$local_plugin"; then
                log_error "Failed to download plugin '$plugin_name' from $url"
                rm -f "$local_plugin"
                return 1
            fi
            chmod +x "$local_plugin"
        fi
    fi
    
    log_info "Running plugin '$plugin_name'..."
    # Execute the plugin in a subshell, passing any additional arguments
    (
        export BOOTSTRAP_DIR
        bash "$local_plugin" "${cmd_args[@]}"
    )
    local ret=$?
    
    if [ "$is_ephemeral" = "true" ]; then
        rm -f "$local_plugin"
    fi
    
    return $ret
}

