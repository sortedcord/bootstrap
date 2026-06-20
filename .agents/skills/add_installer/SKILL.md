---
name: add_installer
description: Add a new installer script to the bootstrap CLI project. Use this skill whenever the user asks to create a new installer, add a new tool/package to bootstrap, or register a new `b <name>` command.
---

# Add a New Installer to Bootstrap CLI

This skill provides everything needed to add a new installer to the bootstrap project without reading the entire codebase.

## Project Overview

Bootstrap CLI (`b`) is a bash-based tool installer and system bootstrapper. Users run `b <name>` to install tools (e.g., `b nvim`, `b bat`). The project lives at the workspace root.

### Key Directories

```
bootstrap/
├── installers/          # Individual installer scripts (install_<name>.sh)
├── lib/                 # Shared libraries sourced by all installers
│   ├── common.sh        # Logging, confirm(), has_command(), make_temp_dir()
│   ├── platform.sh      # detect_distro(), detect_arch(), pkg_install()
│   └── shell_config.sh  # get_shell_configs(), inject_block(), remove_block(), add_alias_if_missing(), add_env_if_missing()
├── commands/            # Non-installer commands (help, con, uninstall)
├── routes.sh            # Central router + installer registry
├── bootstrap.sh         # Metascript for environment setup + library loading
├── b.sh                 # The `b` shell function and autocompletion
└── VERSION
```

## Step-by-Step Checklist

When adding a new installer named `<name>`:

### Step 1: Create the installer script

Create `installers/install_<name>.sh` using the template below.

### Step 2: Register in `routes.sh`

Make **two** edits to `routes.sh`:

1. **Add to the `INSTALLERS` associative array** (line ~19-26). Insert a new entry in alphabetical order:
   ```bash
   [<name>]="Short description of what it installs"
   ```

2. **Add to the `INSTALLER_KEYS` array** (line ~28). Insert the key in alphabetical order:
   ```bash
   INSTALLER_KEYS=(agy bat <name> node nvim yazi zoxide)
   ```

> [!IMPORTANT]
> Both arrays must be kept in sync and in alphabetical order.

### Step 3: Verify (optional)

Run `bash routes.sh` or `b all` to confirm the new installer appears in the help output.

---

## Installer Script Template

Every installer follows this exact boilerplate structure. Copy this and fill in the tool-specific logic:

```bash
#!/usr/bin/env bash
#
# <ToolName> Installer Script
#

# Run metascript to check if the shell is bash and load libraries
PARENT_DIR="$(dirname "$0")/.."
METASCRIPT_LOCAL="$PARENT_DIR/bootstrap.sh"
METASCRIPT_URL="https://git.adityagupta.dev/sortedcord/bootstrap/raw/branch/master/bootstrap.sh"

if [ -f "$METASCRIPT_LOCAL" ]; then
    . "$METASCRIPT_LOCAL"
else
    if command -v wget >/dev/null 2>&1; then
        eval "$(wget -qO- "$METASCRIPT_URL")"
    elif command -v curl >/dev/null 2>&1; then
        eval "$(curl -fsSL "$METASCRIPT_URL")"
    else
        echo "Error: Neither wget nor curl is installed to fetch bootstrap.sh." >&2
        exit 1
    fi
fi

set -euo pipefail

# ─── Installation Logic ──────────────────────────────────────────────

install_<name>() {
    if has_command <command_name>; then
        if ! confirm "<ToolName> is already installed. Reinstall/Upgrade?"; then
            log_info "Skipping <ToolName> installation."
            return
        fi
    else
        if ! confirm "Install <ToolName>?"; then
            log_info "Skipping <ToolName> installation."
            return
        fi
    fi

    # --- Tool-specific installation logic goes here ---
    # Use pkg_install for distro packages:
    #   pkg_install <package>
    # Use detect_distro for distro-specific logic:
    #   local distro; distro=$(detect_distro)
    # Use detect_arch for arch-specific logic:
    #   local arch; arch=$(detect_arch)
    # For GitHub releases, use curl/wget pattern (see bat installer for reference)
}

# ─── Shell Configuration (if needed) ─────────────────────────────────

configure_shell() {
    IFS=' ' read -ra target_files <<< "$(get_shell_configs)"

    for config_file in "${target_files[@]}"; do
        log_info "Configuring <ToolName> in $config_file..."

        # Use inject_block to add shell init/aliases/env vars:
        #   inject_block "$config_file" "<name> init" "<content>"
        # Use add_alias_if_missing for simple aliases:
        #   add_alias_if_missing "$config_file" "<alias>" "<value>"
        # Use add_env_if_missing for environment variables:
        #   add_env_if_missing "$config_file" "VAR_NAME" "value"

        # Source if modified (only for bashrc)
        if [ "$config_file" = "$HOME/.bashrc" ]; then
            . "$config_file" 2>/dev/null || true
        fi
    done
}

# ─── Main ─────────────────────────────────────────────────────────────

main() {
    install_<name>
    configure_shell   # Remove this line if no shell config is needed

    echo
    log_success "<ToolName> installation and configuration complete."
}

main "$@"
```

---

## Available Library Functions

These are pre-loaded by `bootstrap.sh` — no need to source them manually in installers.

### From `lib/common.sh`

| Function | Description |
|---|---|
| `log_info "msg"` | Blue `[INFO]` message to stdout |
| `log_success "msg"` | Green `[SUCCESS]` message to stdout |
| `log_warn "msg"` | Yellow `[WARNING]` message to stderr |
| `log_error "msg"` | Red `[ERROR]` message to stderr |
| `confirm "prompt"` | Interactive yes/no prompt, returns 0 for yes |
| `has_command <cmd>` | Check if a command exists (returns 0/1) |
| `make_temp_dir` | Create and echo a temp directory path |

### From `lib/platform.sh`

| Function | Description |
|---|---|
| `detect_distro` | Echoes `arch`, `debian`, `fedora`, or `unknown` |
| `detect_arch` | Echoes `x86_64` or `arm64` |
| `pkg_install <pkg>...` | Install packages via the system package manager. Supports distro-specific mapping: `"arch:pkg_a\|debian:pkg_d\|fedora:pkg_f"` |

### From `lib/shell_config.sh`

| Function | Description |
|---|---|
| `get_shell_configs` | Space-separated list of existing RC files (`~/.bashrc`, `~/.zshrc`) |
| `inject_block <file> <name> <content>` | Idempotently inject a named block into a config file (removes old block first) |
| `remove_block <file> <name>` | Remove a named block from a config file |
| `add_alias_if_missing <file> <alias> <value>` | Add an alias line if not already present |
| `add_env_if_missing <file> <var> <value>` | Add an `export VAR="value"` line if not already present |
| `create_fd_symlink` | Symlink `fdfind` → `fd` on Debian/Ubuntu |

---

## Common Patterns

### Temp directory with cleanup

```bash
TMP_DIR="$(make_temp_dir)"
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT
```

### Distro-specific installation (e.g., GitHub .deb for Debian, pacman for Arch)

```bash
local distro
distro=$(detect_distro)

case "$distro" in
    arch)
        pkg_install <package>
        ;;
    debian)
        # Download .deb from GitHub releases
        ;;
    fedora)
        pkg_install <package>
        ;;
    *)
        log_error "Unsupported distribution."
        exit 1
        ;;
esac
```

### Fetching latest GitHub release tag

```bash
local latest_tag=""
if has_command curl; then
    latest_tag=$(curl -sL https://api.github.com/repos/<owner>/<repo>/releases/latest \
        | grep '"tag_name":' | head -n1 \
        | sed -E 's/.*"tag_name": "([^"]+)".*/\1/' || true)
elif has_command wget; then
    latest_tag=$(wget -qO- https://api.github.com/repos/<owner>/<repo>/releases/latest \
        | grep '"tag_name":' | head -n1 \
        | sed -E 's/.*"tag_name": "([^"]+)".*/\1/' || true)
fi

if [ -z "$latest_tag" ]; then
    latest_tag="v1.0.0"  # fallback
    log_warn "Failed to fetch latest version. Falling back to: $latest_tag"
fi
```

### Shell block injection (idempotent)

```bash
# Block name should be unique and descriptive
inject_block "$config_file" "<tool> init" 'eval "$(tool init bash)"'
```

---

## Rules & Conventions

1. **File naming**: Always `install_<name>.sh` in the `installers/` directory.
2. **Alphabetical order**: Keep `INSTALLERS` entries and `INSTALLER_KEYS` in alphabetical order in `routes.sh`.
3. **Confirmation prompts**: Always ask before installing. Check if already installed first.
4. **Idempotent**: Installers must be safe to re-run. Use `inject_block` (not append) for shell configs.
5. **No hardcoded paths**: Use `$HOME`, library functions, and `detect_*` helpers.
6. **Error handling**: Use `set -euo pipefail` after sourcing `bootstrap.sh`.
7. **Metascript boilerplate**: The first 22 lines of every installer are identical — always copy them verbatim.
8. **`main "$@"`**: Always end with this pattern to pass through CLI arguments.
