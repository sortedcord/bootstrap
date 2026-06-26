#!/usr/bin/env bash

# Parses a plugin manifest using jq and outputs bash array assignments
parse_plugin_manifest() {
    jq -r '
        .plugins | to_entries[] | 
        (if .value.version then "PLUGIN_VERSIONS[\"" + .key + "\"]=\"" + .value.version + "\"" else empty end),
        (if .value.url then "PLUGIN_URLS[\"" + .key + "\"]=\"" + .value.url + "\"" else empty end),
        (if .value.bootstrap then "PLUGIN_BOOTSTRAP_VERSIONS[\"" + .key + "\"]=\"" + .value.bootstrap + "\"" else empty end)
    '
}

# Ensures that the plugin sources file exists, initializing it with the official repository by default
ensure_sources_file() {
    local sources_file="$BOOTSTRAP_DIR/plugin_sources.txt"
    if [ ! -f "$sources_file" ]; then
        mkdir -p "$BOOTSTRAP_DIR"
        echo "# Add raw URLs to JSON plugin manifests here, one per line." > "$sources_file"
        echo "# Official Bootstrap plugin repository" >> "$sources_file"
        echo "https://git.adityagupta.dev/sortedcord/bootstrap/raw/branch/master/plugins.json" >> "$sources_file"
    fi
}

# Fetches manifests from sources and generates the cache
update_plugin_cache() {
    ensure_sources_file
    local cache_file="$BOOTSTRAP_DIR/lib/plugin_cache.sh"
    local sources_file="$BOOTSTRAP_DIR/plugin_sources.txt"
    
    mkdir -p "$BOOTSTRAP_DIR/lib"
    
    # Initialize cache file
    cat << 'EOF' > "$cache_file"
# Auto-generated plugin cache. Do not edit manually.
declare -g -A PLUGIN_URLS
declare -g -A PLUGIN_VERSIONS
declare -g -A PLUGIN_BOOTSTRAP_VERSIONS
EOF

    if [ -f "$sources_file" ]; then
        local dl_args=()
        local temp_manifests=()
        
        while IFS= read -r url || [ -n "$url" ]; do
            # Skip empty lines and comments
            [[ -z "$url" || "$url" == \#* ]] && continue
            
            local temp_file
            temp_file=$(mktemp --suffix=".json" 2>/dev/null || mktemp)
            dl_args+=("$url" "$temp_file")
            temp_manifests+=("$temp_file")
        done < "$sources_file"
        
        if [ ${#dl_args[@]} -gt 0 ]; then
            log_info "Fetching ${#temp_manifests[@]} plugin manifests in parallel..."
            download_multiple_files_parallel "${dl_args[@]}"
            
            for temp_file in "${temp_manifests[@]}"; do
                if [ -s "$temp_file" ]; then
                    cat "$temp_file" | parse_plugin_manifest >> "$cache_file"
                fi
                rm -f "$temp_file"
            done
        fi
    fi
    
    # Clear downloaded scripts to force lazy re-download of the updated versions
    rm -rf "$BOOTSTRAP_DIR/plugins" 2>/dev/null || true
    
    log_success "Plugin cache updated successfully."
}

manage_plugin_sources() {
    ensure_sources_file
    local sources_file="$BOOTSTRAP_DIR/plugin_sources.txt"

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
    
    # Check compatibility version
    local compat_ver="${PLUGIN_BOOTSTRAP_VERSIONS[$plugin_name]:-}"
    if [ -n "$compat_ver" ]; then
        local current_ver="0.0.0"
        if [ -f "$BOOTSTRAP_DIR/VERSION" ]; then
            current_ver=$(cat "$BOOTSTRAP_DIR/VERSION" | tr -d '[:space:]')
        fi
        if version_lt "$compat_ver" "$current_ver"; then
            log_warn "Plugin '$plugin_name' is only tested up to bootstrap version $compat_ver (current: $current_ver). It may be incompatible."
        fi
    fi
    
    if [ "$is_ephemeral" = "true" ]; then
        log_info "Downloading and running plugin '$plugin_name' (ephemeral)..."
        local script_content
        if ! script_content=$(curl -fsSL "$url"); then
            log_error "Failed to download plugin '$plugin_name' from $url"
            return 1
        fi
        
        # Execute the plugin directly in memory in a subshell
        (
            export BOOTSTRAP_DIR
            # We use bash -c and pass the script content to keep stdin free for interactive plugins
            # The "$0" arg for bash -c is set to the plugin name
            bash -c "$script_content" "$plugin_name" "${cmd_args[@]}"
        )
        return $?
    else
        local plugin_dir="$BOOTSTRAP_DIR/plugins"
        local local_plugin="$plugin_dir/${plugin_name}.sh"
        
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
        
        log_info "Running plugin '$plugin_name'..."
        # Execute the plugin in a subshell, passing any additional arguments
        (
            export BOOTSTRAP_DIR
            bash "$local_plugin" "${cmd_args[@]}"
        )
        return $?
    fi
}
