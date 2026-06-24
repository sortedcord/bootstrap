# Bootstrap CLI: Procedural Rollback System Design

## 1. Objective
Provide a robust rollback mechanism by dynamically generating an uninstallation command list during the installation process. This avoids external parsers, keeps dependencies low, and leverages native Bash execution. It also includes a stateful savepoint system to revert complex environments.

## 2. Core Concept: Dynamic Command Manifests
Instead of tracking state in data files (like JSON), the system procedurally builds a **Command Manifest** (`~/.local/state/bootstrap/uninstallers/<tool>.cmds`) as the installation progresses. Every helper action records its inverse command as an independent line in this manifest.

## 3. History & Savepoints (`b fall` and `b rb`)
To allow rolling back multiple installations or returning to a known good state, the system maintains a chronological **History Log** acting as a stack.

**Location:** `~/.local/state/bootstrap/history.log`

### A. Creating a Savepoint (`b fall <name>`)
The `b fall` command simply appends a marker to the history log.
```bash
echo "SAVEPOINT: $name" >> "$HOME/.local/state/bootstrap/history.log"
```

### B. Tracking Installations
Whenever an installation successfully completes, the `b` CLI appends an install marker:
```bash
echo "INSTALL: nvim" >> "$HOME/.local/state/bootstrap/history.log"
```
**Example History Log:**
```text
SAVEPOINT: init
INSTALL: rust
INSTALL: node
SAVEPOINT: dev_setup
INSTALL: yazi
INSTALL: nvim
```

### C. Bare Rollback (`b rb`)
When `b rb` is executed without arguments, it rolls back the single most recent change:
1. Reads the last line of the history log (e.g., `INSTALL: nvim`).
2. Executes the command manifest for `nvim`.
3. Deletes the last line from the history log.

### D. Savepoint Rollback (`b rb <name>`)
When `b rb init` is executed, it rolls back all changes made after that savepoint:
1. Parses the history log from bottom to top.
2. For each `INSTALL: <tool>` encountered, it executes the rollback manifest for `<tool>`.
3. Stops when it reaches `SAVEPOINT: init`.
4. Truncates the history log back to the savepoint.

## 4. Required Abstractions & Helper Modifications

### A. Context Initialization
Before executing an installer script, the `b` CLI initializes the command list:
```bash
export BOOTSTRAP_UNINSTALLER_CMDS="$HOME/.local/state/bootstrap/uninstallers/nvim.cmds"
mkdir -p "$(dirname "$BOOTSTRAP_UNINSTALLER_CMDS")"
touch "$BOOTSTRAP_UNINSTALLER_CMDS"
```

### B. Recording Commands (LIFO Execution)
Rollback steps are safest when executed in reverse order. A helper prepends commands to the top of the manifest.
```bash
add_rollback_cmd() {
    local cmd="$1"
    sed -i "1i $cmd" "$BOOTSTRAP_UNINSTALLER_CMDS"
}
```

### C. Modifying Existing Helpers
Existing helpers automatically generate their own inverse commands.
- **`pkg_install`:** 
  ```bash
  add_rollback_cmd "pkg_remove $pkg"
  ```
- **`write_env_snippet` / `write_alias_snippet`:**
  ```bash
  add_rollback_cmd "rm -f \"$HOME/.config/bootstrap/env.d/$snippet_name.sh\""
  ```

### D. New File Tracking Helpers
```bash
track_file() { add_rollback_cmd "sudo rm -f '$1'"; }
track_dir() { add_rollback_cmd "sudo rm -rf '$1'"; }
```

## 5. The Rollback Execution (`b rollback <tool>`)
Execution is line-by-line and fault-tolerant, allowing safe recovery even if a user injects a malformed command.

```bash
log_info "Rolling back..."
while IFS= read -r cmd; do
    [ -z "$cmd" ] && continue
    log_info "Executing: $cmd"
    eval "$cmd" || log_warn "Failed to execute rollback step: $cmd"
done < "$BOOTSTRAP_UNINSTALLER_CMDS"

rm -f "$BOOTSTRAP_UNINSTALLER_CMDS"
log_success "Rollback complete."
```

## 6. Resilience Against User Modifications
Because `b ware <tool>` allows users to modify installation scripts:
1. **Dynamic Adaptation:** The manifest is built *during* execution, adapting to whatever packages the user manually added.
2. **Fault Isolation:** The `eval` loop ensures that a syntax error in one custom rollback step doesn't crash the removal of other tracked packages.

## 7. Handling Shared Dependencies
The `pkg_remove` helper utilizes reference counting via simple text files (e.g., `~/.local/state/bootstrap/packages/curl`). 
- **On `pkg_install`**: Append tool name.
- **On `pkg_remove`**: Remove tool name. If empty, proceed with system uninstallation.
