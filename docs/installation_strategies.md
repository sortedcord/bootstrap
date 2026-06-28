# Installation Strategies & Installer Lifecycle

This document explains how Bootstrap categorizes tool installations, the anatomy of an installer script, the full execution lifecycle from invocation to registry recording, and the helper infrastructure available to installers.

## 1. Installation Strategies

Every installer declares an explicit **strategy** that describes how it provisions software onto the system. The strategy is recorded in two places:

1. **At authoring time** — as a `# Strategy:` metadata comment in the installer script header.
2. **At runtime** — inside `$BOOTSTRAP_STATE_DIR/registry.json` via `register_tool`.

### Strategy Types

| Strategy | Description | Validation (`registry_check`) |
| :--- | :--- | :--- |
| `binary` | Tool is downloaded as a prebuilt binary (typically from a GitHub release) and placed into `$BOOTSTRAP_BIN`. | Confirms the registered binary path exists and is executable. |
| `managed` | Tool is installed through its own dedicated version manager or installer (e.g. NVM for Node.js, `rustup` for Rust). Bootstrap orchestrates the manager but doesn't own the binary directly. | Confirms the tool is available via `command -v`. |
| `system` | Tool is installed entirely through the system package manager (`pacman`, `apt`, `dnf`). | Validates recorded system packages using `pkg_check`, falling back to `command -v` when no dependencies are recorded. |

### Which Strategy to Use

- **Prefer `binary`** when the upstream project provides standalone Linux binaries on GitHub (e.g. `bat`, `lazygit`, `hyperfine`, `yazi`, `nvim`).
- **Use `managed`** when the tool has its own version/runtime manager that must be preserved for updates (e.g. `nvm` for Node.js, `rustup` for Rust, `zoxide` which uses its own install script).
- **Use `system`** when the tool is only available through the distro's package manager and there is no upstream binary distribution (e.g. `docker`, `yay`).

## 2. Installer Script Anatomy

Every installer lives at `installers/install_<tool>.sh` and follows a strict structure.

### 2.1 Metadata Header

The first lines of the file are structured comments parsed by `scripts/generate_registry.sh` to auto-generate `lib/registry.sh`:

```bash
#!/usr/bin/env bash
# Tool: bat
# DisplayName: Bat
# Description: Install Bat (alternative to cat) and configure alias
# Strategy: binary
#
```

| Field | Purpose |
| :--- | :--- |
| `Tool` | The CLI key used to invoke the installer (`b bat`). Must be lowercase, no spaces. |
| `DisplayName` | Human-readable name shown in `b ware` listings and log messages. |
| `Description` | One-line description. The word "Install" at the start is stripped automatically by the registry generator. |
| `Strategy` | One of `binary`, `managed`, or `system`. |

### 2.2 Script Body Structure

```bash
set -euo pipefail

# Temporary directory (auto-cleaned)
TMP_DIR="$(make_temp_dir)"
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

# Core installation function
install_<tool>() {
    # 1. Check if already installed, offer reinstall/upgrade
    # 2. Detect architecture, fetch latest version
    # 3. Download, extract, install
    # 4. Track files for rollback
    # 5. Register in the JSON registry
}

# Optional: shell environment configuration
configure_shell() {
    # Write env/alias/completion snippets
}

main() {
    install_<tool>
    configure_shell   # if needed

    echo
    log_success "<Tool> installation and configuration complete."
}

main "$@"
```

### 2.3 Key Conventions

- **No standalone execution guards**: Installers are always executed by the Bootstrap runtime, which sources all libraries before running the script. They must never check for or source libraries themselves.
- **No `curl` availability checks**: The runtime guarantees `curl` is available.
- **No direct `.bashrc` manipulation**: Use `write_env_snippet`, `write_alias_snippet`, and `write_completion_snippet` to write shell configuration fragments into the snippet directories (`env.d/`, `aliases.d/`, `completions.d/`). The loader sources these automatically.
- **Temp directories**: Use `make_temp_dir` (from `lib/common.sh`) for temporary work and clean up via a `trap cleanup EXIT`.

## 3. Available Helper Functions

Installers run inside a prepared environment where all Bootstrap libraries have been sourced. The following helper functions are available:

### 3.1 Common Utilities (`lib/common.sh`)

| Function | Purpose |
| :--- | :--- |
| `log_info`, `log_success`, `log_warn`, `log_error` | Coloured logging to stdout/stderr. |
| `confirm "<prompt>"` | Interactive yes/no prompt. Reads from `/dev/tty` to support piped execution. |
| `has_command <cmd>` | Returns `0` if the command exists on `$PATH`. |
| `make_temp_dir` | Creates a `mktemp -d` temporary directory and prints its path. |
| `download_file <url> <dest>` | Cached, resumable download. Files are first stored in `$BOOTSTRAP_CACHE_DIR/downloads/` and then copied to `<dest>`. |
| `version_lt <v1> <v2>` | Semver comparison. Returns `0` if `v1 < v2`. |

### 3.2 Platform & Package Management (`lib/platform.sh`)

| Function | Purpose |
| :--- | :--- |
| `detect_distro` | Returns `arch`, `debian`, `fedora`, or `unknown`. |
| `detect_arch` | Returns `x86_64` or `arm64`. |
| `pkg_install <spec>...` | Installs system packages. Supports distro-specific mappings: `"arch:docker\|debian:docker.io\|fedora:docker"`. |
| `pkg_check <spec>...` | Returns `0` if all specified packages are installed. |
| `pkg_remove <spec>...` | Removes system packages. |

### 3.3 GitHub Release Helpers (`lib/github.sh`)

| Function | Purpose |
| :--- | :--- |
| `github_get_latest_release <owner/repo>` | Queries the GitHub API and prints the `tag_name` of the latest release. |
| `github_get_download_url <owner/repo> <tag> <regex>` | Finds the asset matching the regex pattern in the given release and prints its download URL. |
| `github_download_asset <owner/repo> <tag> <regex> <dest>` | Resolves and downloads the matching asset to `<dest>`. |

**Why `github_get_latest_release` is separate from `github_download_asset`**: Asset filenames often embed the version string (e.g. `bat-v0.26.1-x86_64-unknown-linux-gnu.tar.gz`). The installer needs the concrete version *before* constructing the asset pattern and also passes it to `register_tool`.

### 3.4 Shell Configuration (`lib/shell_config.sh`)

| Function | Purpose |
| :--- | :--- |
| `write_env_snippet <name> <content>` | Writes content to `$BOOTSTRAP_DIR/env.d/<name>.sh`. Auto-registers a rollback command to delete the snippet. |
| `write_alias_snippet <name> <content>` | Writes content to `$BOOTSTRAP_DIR/aliases.d/<name>.sh`. Auto-registers rollback. |
| `write_completion_snippet <name> <content>` | Writes content to `$BOOTSTRAP_DIR/completions.d/<name>.sh`. Auto-registers rollback. |

### 3.5 Rollback & File Tracking (`lib/rollback.sh`)

| Function | Purpose |
| :--- | :--- |
| `track_file <path>` | Records `sudo rm -f '<path>'` in the uninstaller manifest for the current tool. |
| `track_dir <path>` | Records `sudo rm -rf '<path>'` in the uninstaller manifest. |
| `add_rollback_cmd <cmd>` | Prepends an arbitrary shell command to the manifest (LIFO order). |

### 3.6 Registry Helpers (`lib/registry_helpers.sh`)

| Function | Purpose |
| :--- | :--- |
| `register_tool <tool> <strategy> [version] [source]` | Records the tool in `registry.json` with its strategy, version, source, timestamp, and (for `binary` strategy) its binary path. |
| `registry_add_sys_deps <tool> <dep1> <dep2>...` | Appends system package dependency names to the tool's `system_dependencies` array in the registry (used for reference counting during uninstallation). |
| `registry_remove_tool <tool>` | Deletes the tool's entire entry from `registry.json`. |
| `registry_check <tool>` | Validates that the tool is correctly installed according to its declared strategy. |

## 4. Execution Lifecycle

This is the complete flow from when a user types `b <tool>` to when the installation is recorded.

### 4.1 Invocation

```
User types:  b bat
             │
             ▼
         b.sh (shell function)
             │
             ├── Auto-update check (once per 24h)
             │
             ▼
         bash routes.sh bat
```

`b.sh` is a shell function sourced from `~/.bashrc`. It delegates to `routes.sh` in a subshell.

### 4.2 Library Loading

`routes.sh` sources the core libraries in order:

1. `lib/common.sh` — Logging, `download_file`, `make_temp_dir`, XDG path variables
2. `lib/rollback.sh` — Manifest system, `track_file`, `track_dir`, `init_rollback_system`
3. `lib/platform.sh` — Distro/arch detection, `pkg_install`/`pkg_remove`
4. `lib/shell_config.sh` — `write_env_snippet`, `write_alias_snippet`, etc.
5. `lib/registry.sh` — Auto-generated lookup tables (`INSTALLERS`, `INSTALLER_DISPLAYS`, `INSTALLER_STRATEGIES`, `INSTALLER_KEYS`)
6. `lib/registry_helpers.sh` — `register_tool`, `registry_add_sys_deps`, etc.
7. `lib/github.sh` — GitHub release API helpers
8. `lib/plugins.sh` — Plugin system

All functions are exported to subshells so the installer script inherits them.

### 4.3 Routing

`routes.sh` resolves the command. If the argument matches a key in the `INSTALLERS` registry, it is treated as a tool name and routed to `run_ware`:

```
routes.sh receives "bat"
    │
    ├── Is it a built-in command (help, rb, fall, con, up, gone, etc.)?  → No
    ├── Is it a registered tool key in INSTALLERS?  → Yes
    │
    ▼
run_ware "bat" "-y"
```

### 4.4 Installer Resolution

`run_ware` locates the installer script:

1. **Local check**: Does `$BOOTSTRAP_DIR/installers/install_bat.sh` exist? If yes, use it directly.
2. **Remote download**: If not local, download from the primary Git server (`git.adityagupta.dev`). On failure, fall back to the GitHub mirror.

### 4.5 Pre-Execution Setup

Before running the installer, `run_ware` calls `setup_uninstaller_context "bat"`, which:

- Sets `BOOTSTRAP_CURRENT_TOOL=bat`
- Sets `BOOTSTRAP_UNINSTALLER_CMDS=$BOOTSTRAP_STATE_DIR/uninstallers/bat.cmds`
- If a manifest already exists from a previous interrupted run, it preserves it (resume support).
- Otherwise, creates a fresh empty manifest file.

Signal traps (`INT`, `TERM`) are installed to catch interruptions.

### 4.6 Installer Execution

The installer script runs in a `bash` subshell. During execution:

- **`track_file`/`track_dir`** calls prepend removal commands to `bat.cmds` (LIFO order).
- **`write_env_snippet`/`write_alias_snippet`** automatically record their own rollback commands.
- **`pkg_install`** installs system packages. If the tool uses `system` strategy, the installer calls `registry_add_sys_deps` to register these packages for reference counting.
- **`register_tool "bat" "binary" "$version" "github:sharkdp/bat"`** writes the tool's metadata to `$BOOTSTRAP_STATE_DIR/registry.json` using thread-safe `flock`.

### 4.7 Post-Execution

If the installer exits successfully (`exit 0`), `run_ware`:

1. Calls `mark_install_success "bat"` — appends `INSTALL: bat` to `$BOOTSTRAP_STATE_DIR/history.log`.
2. Re-sources `~/.bashrc` so new env/alias snippets take effect immediately.

If the installer fails or is interrupted, the user is offered a choice:

- **Rollback (`r`)**: Executes the manifest line-by-line to undo all recorded changes.
- **Keep (`k`)**: Preserves partial changes so the user can resume or debug.

## 5. The Registry (`registry.json`)

The JSON registry is the central source of truth for installed tool state. It lives at `$BOOTSTRAP_STATE_DIR/registry.json`.

### 5.1 Schema

```json
{
  "tools": {
    "bat": {
      "strategy": "binary",
      "version": "v0.26.1",
      "source": "github:sharkdp/bat",
      "installed_at": "2025-06-28T03:15:00Z",
      "bin": "/home/user/.local/share/bootstrap/bin/bat"
    },
    "docker": {
      "strategy": "system",
      "installed_at": "2025-06-28T03:20:00Z",
      "source": "os-package-manager",
      "system_dependencies": [
        "arch:docker|debian:docker.io|fedora:docker"
      ]
    },
    "node": {
      "strategy": "managed",
      "version": "v0.40.5",
      "source": "github:nvm-sh/nvm",
      "installed_at": "2025-06-28T03:25:00Z"
    }
  }
}
```

### 5.2 Thread Safety

All mutations go through `registry_set`, which acquires an exclusive file lock (`flock -x`) on `registry.json.lock` before applying a `jq` filter. This prevents race conditions if multiple installers run simultaneously.

## 6. The Auto-Generated Registry (`lib/registry.sh`)

`lib/registry.sh` is a **build-time artifact**, not a runtime state file. It is auto-generated by `scripts/generate_registry.sh`, which parses the metadata headers from every `installers/install_*.sh` file and produces four Bash data structures:

| Variable | Type | Purpose |
| :--- | :--- | :--- |
| `INSTALLERS` | `declare -A` | Maps tool key → description |
| `INSTALLER_DISPLAYS` | `declare -A` | Maps tool key → human-readable display name |
| `INSTALLER_STRATEGIES` | `declare -A` | Maps tool key → strategy (`binary`/`managed`/`system`) |
| `INSTALLER_KEYS` | Array | Sorted list of all tool keys |

These are used by `routes.sh` for command routing, by `b ware` (with no arguments) for listing available tools, and by `b help` for the help output.

**Important**: `lib/registry.sh` must be regenerated whenever an installer is added, removed, or has its metadata header changed. Run:

```bash
./scripts/generate_registry.sh
```

## 7. Uninstallation Flow

### 7.1 Named Uninstall (`b rb <tool>`)

```
b rb bat
    │
    ▼
uninstall_tool "bat"
    │
    ├── 1. execute_rollback "bat"
    │       → Reads bat.cmds line-by-line (LIFO)
    │       → Executes: rm binary, rm env snippet, rm alias snippet, etc.
    │       → Deletes bat.cmds
    │
    ├── 2. Reference-count system dependencies
    │       → For each dep in registry_get_sys_deps("bat"):
    │           → Count how many OTHER tools also list this dep
    │           → If count == 0: pkg_remove the dep
    │           → If count > 0: keep it
    │
    ├── 3. registry_remove_tool "bat"
    │       → Deletes .tools.bat from registry.json
    │
    └── 4. Remove "INSTALL: bat" from history.log
```

### 7.2 Multi-Tool Uninstall (`b rb bat,yazi,zoxide`)

The argument is split on commas and `uninstall_tool` is called for each tool sequentially.

### 7.3 Bare Rollback (`b rb`)

Reads the last line of `history.log`. If it is `INSTALL: <tool>`, calls `uninstall_tool` for that tool.

### 7.4 Savepoint Rollback (`b rb <savepoint>`)

If the argument doesn't match a registered tool, it is treated as a savepoint name. The system walks `history.log` backwards, uninstalling each tool encountered until it reaches the matching `SAVEPOINT:` entry.

## 8. Strategy-Specific Patterns

### 8.1 Binary Strategy Example (Bat)

```bash
# Detect arch, fetch latest tag from GitHub
latest_tag=$(github_get_latest_release "sharkdp/bat")

# Download the matching release asset
github_download_asset "sharkdp/bat" "$latest_tag" "bat-${latest_tag}-${target}\.tar\.gz" "$archive"

# Extract, copy binary to $BOOTSTRAP_BIN, make executable
cp "$extract_dir/bat" "$BOOTSTRAP_BIN/bat"
chmod +x "$BOOTSTRAP_BIN/bat"
track_file "$BOOTSTRAP_BIN/bat"

# Register
register_tool "bat" "binary" "$latest_tag" "github:sharkdp/bat"
```

### 8.2 Managed Strategy Example (Node.js via NVM)

```bash
# Download and extract NVM into $BOOTSTRAP_RUNTIMES/nvm
download_file "$nvm_url" "$TMP_DIR/nvm.tar.gz"
tar -xzf "$TMP_DIR/nvm.tar.gz" -C "$BOOTSTRAP_RUNTIMES/nvm" --strip-components=1
track_dir "$BOOTSTRAP_RUNTIMES/nvm"

# Write env snippet so NVM loads on shell startup
write_env_snippet "node" "$content"

# Use NVM to install Node LTS
nvm install --lts

# Register (NVM manages the actual node binary)
register_tool "node" "managed" "$latest_tag" "github:nvm-sh/nvm"
```

### 8.3 System Strategy Example (Docker)

```bash
# Install via system package manager
pkg_install "arch:docker|debian:docker.io|fedora:docker"

# Register the dependency for reference counting
registry_add_sys_deps "docker" "arch:docker|debian:docker.io|fedora:docker"

# Additional system configuration (groups, systemd)
sudo usermod -aG docker "$USER"
add_rollback_cmd "sudo gpasswd -d $USER docker || true"

# Register
register_tool "docker" "system" "" "os-package-manager"
```
