#!/usr/bin/env bash
# Registry management helpers for Bootstrap

# Ensures the registry file exists
ensure_registry() {
    local registry_file="${BOOTSTRAP_DIR:-$HOME/.config/bootstrap}/registry.json"
    if [ ! -f "$registry_file" ]; then
        mkdir -p "$(dirname "$registry_file")"
        echo '{"tools": {}}' > "$registry_file"
    fi
    echo "$registry_file"
}

# Safely applies a jq filter to the registry using a file lock
registry_set() {
    local jq_filter="$1"
    shift
    local registry_file
    registry_file=$(ensure_registry)
    local lock_file="${registry_file}.lock"
    
    (
        flock -x 200
        local temp_file
        temp_file=$(mktemp)
        # Apply jq filter with any additional arguments passed in
        jq "$@" "$jq_filter" "$registry_file" > "$temp_file" && mv "$temp_file" "$registry_file"
    ) 200>"$lock_file"
}

# Usage: register_tool <tool_name> <strategy> [version] [source]
register_tool() {
    local tool="$1"
    local strategy="$2"
    local version="${3:-}"
    local source="${4:-}"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local bindir="${BOOTSTRAP_DIR:-$HOME/.config/bootstrap}/bin"
    
    local filter='if .tools == null then .tools = {} else . end |
        .tools[$tool].strategy = $strategy |
        .tools[$tool].installed_at = $timestamp |
        (if $version != "" then .tools[$tool].version = $version else . end) |
        (if $source != "" then .tools[$tool].source = $source else . end) |
        (if $strategy == "binary" then .tools[$tool].bin = ($bindir + "/" + $tool) else . end)'
        
    registry_set "$filter" \
       --arg tool "$tool" \
       --arg strategy "$strategy" \
       --arg version "$version" \
       --arg source "$source" \
       --arg timestamp "$timestamp" \
       --arg bindir "$bindir"
}

# Usage: registry_add_sys_deps <tool_name> <dep1> <dep2>...
registry_add_sys_deps() {
    local tool="$1"
    shift
    if [ $# -eq 0 ]; then
        return 0
    fi
    
    local deps_json
    deps_json=$(printf '%s\n' "$@" | jq -R . | jq -s .)

    local filter='if .tools == null then .tools = {} else . end |
        .tools[$tool].system_dependencies = ((.tools[$tool].system_dependencies // []) + $deps | unique)'

    registry_set "$filter" --arg tool "$tool" --argjson deps "$deps_json"
}

# Usage: registry_remove_tool <tool_name>
registry_remove_tool() {
    local tool="$1"
    registry_set 'del(.tools[$tool])' --arg tool "$tool"
}

# Usage: registry_get_sys_deps <tool_name>
registry_get_sys_deps() {
    local tool="$1"
    local registry_file="${BOOTSTRAP_DIR:-$HOME/.config/bootstrap}/registry.json"
    if [ -f "$registry_file" ]; then
        jq -r --arg tool "$tool" '.tools[$tool].system_dependencies[]? // empty' "$registry_file"
    fi
}

# Usage: registry_check <tool_name>
# Validates that a tool is actually installed according to its strategy
registry_check() {
    local tool="$1"
    local registry_file
    registry_file=$(ensure_registry)

    local strategy
    strategy=$(jq -r --arg tool "$tool" '.tools[$tool].strategy // empty' "$registry_file")

    if [ -z "$strategy" ]; then
        return 1
    fi

    if [ "$strategy" = "binary" ]; then
        local bin_path
        bin_path=$(jq -r --arg tool "$tool" '.tools[$tool].bin // empty' "$registry_file")
        if [ -n "$bin_path" ] && [ -x "$bin_path" ]; then
            return 0
        fi
    elif [ "$strategy" = "managed" ]; then
        if command -v "$tool" >/dev/null 2>&1; then
            return 0
        fi
    elif [ "$strategy" = "system" ]; then
        local deps=()
        while IFS= read -r dep; do
            [ -n "$dep" ] && deps+=("$dep")
        done < <(registry_get_sys_deps "$tool")
        
        if [ ${#deps[@]} -eq 0 ]; then
            if command -v "$tool" >/dev/null 2>&1; then
                return 0
            fi
        else
            if pkg_check "${deps[@]}"; then
                return 0
            fi
        fi
    fi
    
    return 1
}

export -f ensure_registry registry_set register_tool registry_add_sys_deps registry_remove_tool registry_get_sys_deps registry_check
