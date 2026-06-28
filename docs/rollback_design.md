# Bootstrap CLI: Procedural Rollback System Design

## 1. Objective
Provide a robust rollback mechanism by dynamically generating an uninstallation command list during the installation process. This avoids external parsers, keeps dependencies low, and leverages native Bash execution. It also includes a stateful savepoint system to revert complex environments.

## 2. Core Concept: Procedural Manifests & JSON Registry
The system uses a hybrid approach:
1. **Procedural Command Manifests**: As the installation progresses, a LIFO script manifest (`$BOOTSTRAP_STATE_DIR/uninstallers/<tool>.cmds`) is built by prepending the inverse commands for each helper action (files, directories, env/alias snippets).
2. **Centralized JSON Registry**: Metadata, strategy, and system-level dependencies are tracked in a thread-safe `$BOOTSTRAP_STATE_DIR/registry.json` using `jq`. During uninstallation, this registry is used to reference-count and safely remove shared system dependencies.

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
When `b rb` is executed without arguments, it rolls back the single most recent installation:
1. Reads the last line of the history log (e.g., `INSTALL: nvim`).
2. Runs `uninstall_tool nvim` which executes `nvim.cmds` and cleans up registry entries.

### D. Named Rollback (`b rb <tool1>,<tool2>...`)
Users can uninstall specific tools by name (e.g., `b rb nvim` or `b rb nvim,yazi`). The system runs the corresponding uninstaller manifests, reference-counts and removes any orphaned system dependencies, and cleans up the history log and registry.

### E. Savepoint Rollback (`b rb <savepoint>`)
If the argument does not match an installed tool in the registry, it is treated as a savepoint:
1. Parses the history log from bottom to top.
2. For each `INSTALL: <tool>` encountered, it runs `uninstall_tool <tool>`.
3. Stops when it reaches the specified `SAVEPOINT: <name>`.
4. Truncates the history log back to that savepoint.

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

### C. Helper Operations
Helper functions record their inverse actions directly to the manifest:
- **`write_env_snippet` / `write_alias_snippet` / `write_completion_snippet`:**
  ```bash
  add_rollback_cmd "rm -f \"\$BOOTSTRAP_DIR/env.d/\$snippet_name.sh\""
  ```
- **`track_file` / `track_dir`**:
  ```bash
  track_file() { add_rollback_cmd "sudo rm -f '$1'"; }
  track_dir() { add_rollback_cmd "sudo rm -rf '$1'"; }
  ```
Note: distro packages are not tracked via `add_rollback_cmd`. Instead, installers declare them as system dependencies (see below).

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
System dependencies installed via `pkg_install` must be registered via `registry_add_sys_deps <tool> <dep1> <dep2>...`.
When a tool is uninstalled:
1. The registry is checked to see if any other installed tool still lists those dependencies.
2. If the reference count drops to `0`, the dependency is automatically removed using `pkg_remove`.
3. If other tools still depend on it, it is kept.

## 8. Fault Tolerance, Resumability, and Interrupted Installations

To handle failures during installation (e.g., network drops, script errors, or user cancellation via `Ctrl+C`), the CLI incorporates a transactional approach that balances **automatic rollback** and **resumability**:

### A. The Interruption Trap & Prompt
When running an installer, the central router (`lib/routes.sh`) traps `SIGINT` and `SIGTERM` signals. If the installation fails or is interrupted:
1. The trap catches the event and stops execution.
2. The user is prompted interactively:
   - **Rollback (r)**: Invokes `execute_rollback <tool>` immediately to clean up all partial modifications.
   - **Keep (k)**: Preserves the partial changes and leaves the `.cmds` manifest intact.
3. In non-interactive environments (e.g., CI/CD or scripts), the CLI defaults to **automatic rollback** to keep the system clean.

### B. Resuming via Preserved Manifests
If the user chooses to **keep** the partial state and runs `b <tool>` again:
1. `setup_uninstaller_context` detects that a manifest already exists and that the tool was *not* successfully installed (no `INSTALL: <tool>` in the history log).
2. It **preserves** the existing manifest instead of wiping it.
3. As the script runs again from the top, new rollback commands are prepended to the existing manifest, maintaining the correct LIFO order without losing the tracking of previously completed steps.

### C. Resumable Downloads (Caching Layer)
To make rerunning an interrupted script fast and efficient, installers use `download_file <url> <dest>` instead of raw `curl`:
1. It downloads the payload to a central cache directory: `~/.local/state/bootstrap/cache/`.
2. It uses `curl -C -` to continue the download from the byte offset where it was interrupted.
3. Once completed, it copies the cached file to the installer's temp directory.
4. Distro package manager commands (`pkg_install`) and shell snippets (`write_env_snippet`) are naturally idempotent, allowing the script to breeze through already completed steps in milliseconds and resume exactly where the heavy work failed.

