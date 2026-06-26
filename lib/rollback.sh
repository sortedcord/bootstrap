#!/usr/bin/env bash

if [ -n "${_LIB_ROLLBACK_SOURCED:-}" ]; then
    return 0
fi
_LIB_ROLLBACK_SOURCED=1

BOOTSTRAP_STATE_DIR="$HOME/.local/state/bootstrap"
BOOTSTRAP_HISTORY_LOG="$BOOTSTRAP_STATE_DIR/history.log"
BOOTSTRAP_UNINSTALLERS_DIR="$BOOTSTRAP_STATE_DIR/uninstallers"


init_rollback_system() {
    mkdir -p "$BOOTSTRAP_UNINSTALLERS_DIR"

    touch "$BOOTSTRAP_HISTORY_LOG"
}

setup_uninstaller_context() {
    local tool="$1"
    export BOOTSTRAP_CURRENT_TOOL="$tool"
    export BOOTSTRAP_UNINSTALLER_CMDS="$BOOTSTRAP_UNINSTALLERS_DIR/${tool}.cmds"
    
    # If a manifest already exists and the tool is NOT marked as successfully installed
    # in history.log, we treat this as a resumed run. We preserve the manifest so
    # that new commands are prepended to the existing ones.
    if [ -f "$BOOTSTRAP_UNINSTALLER_CMDS" ] && ! grep -q "^INSTALL: $tool$" "$BOOTSTRAP_HISTORY_LOG" 2>/dev/null; then
        log_info "Resuming installation of '$tool'. Preserving existing rollback manifest."
    else
        # Fresh installation or reinstall, start with a clean slate
        rm -f "$BOOTSTRAP_UNINSTALLER_CMDS"
    fi
    touch "$BOOTSTRAP_UNINSTALLER_CMDS"
}

add_rollback_cmd() {
    local cmd="$1"
    if [ -n "${BOOTSTRAP_UNINSTALLER_CMDS:-}" ] && [ -f "$BOOTSTRAP_UNINSTALLER_CMDS" ]; then
        # Prepend to the top of the file
        sed -i "1i $cmd" "$BOOTSTRAP_UNINSTALLER_CMDS"
    fi
}

track_file() {
    add_rollback_cmd "sudo rm -f '$1'"
}

track_dir() {
    add_rollback_cmd "sudo rm -rf '$1'"
}

create_savepoint() {
    local name="$1"
    echo "SAVEPOINT: $name" >> "$BOOTSTRAP_HISTORY_LOG"
    log_success "Savepoint '$name' created."
}

mark_install_success() {
    local tool="$1"
    # Only record if we actually have an uninstaller
    if [ -f "$BOOTSTRAP_UNINSTALLERS_DIR/${tool}.cmds" ]; then
        echo "INSTALL: $tool" >> "$BOOTSTRAP_HISTORY_LOG"
    fi
}

execute_rollback() {
    local tool="$1"
    local manifest="$BOOTSTRAP_UNINSTALLERS_DIR/${tool}.cmds"
    
    if [ ! -f "$manifest" ]; then
        log_warn "No rollback manifest found for '$tool'."
        return 0
    fi
    
    export BOOTSTRAP_CURRENT_TOOL="$tool"
    log_info "Rolling back '$tool'..."
    while IFS= read -r cmd; do
        [ -z "$cmd" ] && continue
        log_info "Executing: $cmd"
        eval "$cmd" || log_warn "Failed to execute: $cmd"
    done < "$manifest"
    
    rm -f "$manifest"
    log_success "Rollback of '$tool' complete."
}


uninstall_tool() {
    local tool="$1"
    
    # 1. Execute the rollback manifest to remove files/dirs/env/aliases
    execute_rollback "$tool"

    # 2. Reference counting and cleanup of system dependencies
    local registry_file="$BOOTSTRAP_STATE_DIR/registry.json"
    if [ -f "$registry_file" ] && jq -e --arg tool "$tool" '.tools | has($tool)' "$registry_file" >/dev/null; then
        while IFS= read -r dep; do
            [ -z "$dep" ] && continue
            local other_users
            other_users=$(jq -r --arg tool "$tool" --arg dep "$dep" '
                .tools | to_entries | map(select(.key != $tool and (.value.system_dependencies | type == "array") and (.value.system_dependencies | index($dep)))) | length
            ' "$registry_file")
            
            if [ "$other_users" -eq 0 ]; then
                log_info "System dependency '$dep' is no longer required by any registered tool. Removing..."
                pkg_remove "$dep"
            else
                log_info "Keeping system dependency '$dep' (required by other tools)"
            fi
        done < <(registry_get_sys_deps "$tool")
        
        # Remove from registry
        registry_remove_tool "$tool"
    fi
    
    # 3. Remove the tool from history.log
    if [ -f "$BOOTSTRAP_HISTORY_LOG" ]; then
        sed -i "/^INSTALL: ${tool}$/d" "$BOOTSTRAP_HISTORY_LOG"
    fi
}

rollback_bare() {
    if [ ! -s "$BOOTSTRAP_HISTORY_LOG" ]; then
        log_info "No history available to rollback."
        return 0
    fi
    
    local last_line
    last_line=$(tail -n 1 "$BOOTSTRAP_HISTORY_LOG")
    
    if [[ "$last_line" == INSTALL:* ]]; then
        local tool="${last_line#INSTALL: }"
        uninstall_tool "$tool"
    elif [[ "$last_line" == SAVEPOINT:* ]]; then
        local sp="${last_line#SAVEPOINT: }"
        log_warn "Last action was savepoint '$sp'. Cannot bare-rollback a savepoint."
    fi
}

rollback_to_savepoint() {
    local target_sp="$1"
    
    if ! grep -q "SAVEPOINT: $target_sp" "$BOOTSTRAP_HISTORY_LOG"; then
        log_error "Savepoint '$target_sp' not found in history."
        return 1
    fi
    
    while [ -s "$BOOTSTRAP_HISTORY_LOG" ]; do
        local last_line
        last_line=$(tail -n 1 "$BOOTSTRAP_HISTORY_LOG")
        
        if [[ "$last_line" == SAVEPOINT:\ $target_sp ]]; then
            log_success "Reached savepoint '$target_sp'."
            # Optionally remove the savepoint itself or keep it? Let's keep it.
            break
        elif [[ "$last_line" == INSTALL:* ]]; then
            local tool="${last_line#INSTALL: }"
            uninstall_tool "$tool"
        elif [[ "$last_line" == SAVEPOINT:* ]]; then
            local sp="${last_line#SAVEPOINT: }"
            log_info "Removing intermediate savepoint '$sp'..."
            sed -i '$ d' "$BOOTSTRAP_HISTORY_LOG"
        else
            # Unknown line format, just remove it
            sed -i '$ d' "$BOOTSTRAP_HISTORY_LOG"
        fi
    done
}

export -f init_rollback_system setup_uninstaller_context add_rollback_cmd track_file track_dir create_savepoint mark_install_success execute_rollback uninstall_tool rollback_bare rollback_to_savepoint
