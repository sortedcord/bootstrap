---
name: add_installer
description: Add a new installer script to the bootstrap CLI project. Use this skill whenever the user asks to create a new installer, add a new tool/package to bootstrap, or register a new `b <name>` command.
---

# Add a New Installer to Bootstrap CLI

This skill provides everything needed to add a new installer to the bootstrap project without reading the entire codebase.

## Project Overview

Bootstrap CLI (`b`) is a bash-based tool installer and system bootstrapper. Users run `b <name>` or `b ware <name>` to install or edit tools (e.g., `b nvim`, `b ware bat`). The project lives at the workspace root.

### Key Directories

```
bootstrap/
├── installers/          # Individual installer scripts (install_<name>.sh)
├── lib/                 # Shared libraries and router sourced by all installers
│   ├── common.sh        # Logging, confirm(), has_command(), make_temp_dir()
│   ├── platform.sh      # detect_distro(), detect_arch(), pkg_install(), pkg_check(), pkg_remove()
│   ├── rollback.sh      # Rollback tracking (track_file, track_dir, add_rollback_cmd)
│   ├── shell_config.sh  # write_env_snippet, write_alias_snippet, write_completion_snippet
│   ├── registry.sh      # Dynamically generated installer registry
│   └── routes.sh        # Central router script
├── commands/            # Non-installer commands (help, con, uninstall)
├── assets/              # Assets (logo art, etc.)
│   └── pixel_art.ansi
├── bootstrap.sh         # Metascript for environment setup + library loading
├── b.sh                 # The `b` shell function and autocompletion
└── VERSION
```

## Step-by-Step Checklist

When adding a new installer named `<name>`:

### Step 1: Analyze user request & gather details

When the user asks you to create an installer, they often provide either an official `curl` install script or a link to a `.tar.gz` release.
You MUST do the following before writing the script:

**If the user provides a `curl` command or link to an install script:**
- Execute the `curl` command (or use `read_url_content`) to fetch the script and analyze what it actually does under the hood.
- Do NOT simply execute the official script blindly in your installer.
- Re-write its functionality according to the conventions of the bootstrap installer.
- Strip away redundant code, OS checks for macOS/Windows (we only target Linux), and unnecessary shell configuration logic.
- Implement only the core, essential Linux installation logic inside the `install_<name>` function.

**If the user provides a link to a `.tar.gz` (or `.zip`):**
- First, download the archive to a temporary directory and extract it to inspect its contents.
- Analyze the extracted folder structure to decide what needs to be installed (e.g., binaries, man pages, completions) and what should be ignored/deleted.
- Write the `install_<name>` function to download, extract, and copy only those essential files. (Use `download_file` and temporary directories, see "Resumable Download and Extraction" below).

### Step 2: Create the installer script

### Step 3: Add metadata comments to the top of your installer script

At the top of your new installer script, right below `#!/usr/bin/env bash`, add the following three metadata headers:
```bash
# Tool: <name>
# DisplayName: <displayName>
# Description: <description>
```

The central router `lib/routes.sh` and autocomplete function in `b.sh` will dynamically parse this metadata from all `install_*.sh` scripts to register the installer and keys automatically! No manual edits to `lib/routes.sh` or `b.sh` are required.

### Step 4: Implement Rollback Tracking (Crucial)

To ensure the user can seamlessly use `b rb <name>`, all manual modifications must be tracked:
- When extracting binaries to `~/.local/bin/`, use `track_file "$HOME/.local/bin/binary"`.
- When creating directories like `~/.config/tool/`, use `track_dir "$HOME/.config/tool"`.
- When running manual apt/dnf/npm commands, log their inverses: `add_rollback_cmd "sudo npm uninstall -g package"`.
Note: `pkg_install`, `write_env_snippet`, `write_alias_snippet`, and `write_completion_snippet` will automatically track themselves.

### Step 5: Verify (optional)

Verify that the installer works and appears in the help output:
- Run `b all` to confirm it appears in the help list.
- Run `b ware <name> -y` to test direct installation.
- Run `b ware <name>` to test the interactive editing flow.

---

## Installer Script Template

Every installer follows this exact boilerplate structure. Copy this and fill in the tool-specific logic:

```bash
#!/usr/bin/env bash
# Tool: <name>
# DisplayName: <ToolName>
# Description: Short description of what it installs
#
# <ToolName> Installer Script
#

# Prevent standalone execution
if [ -z "${_LIB_COMMON_SOURCED:-}" ]; then
    echo "Error: This script must be run through the 'b' CLI." >&2
    exit 1
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
    # Use pkg_install for distro packages (it automatically handles rollback hooks!):
    #   pkg_install "arch:<pkg_a>|debian:<pkg_d>|fedora:<pkg_f>"
    
    # Or manual downloads (always use download_file for resumability!):
    #   local url="https://..."
    #   download_file "$url" "$TMP_DIR/binary"
    #   cp "$TMP_DIR/binary" "$HOME/.local/bin/binary"
    #   track_file "$HOME/.local/bin/binary"  # Important for rollback!
}

# ─── Shell Configuration (if needed) ─────────────────────────────────

configure_shell() {
    # Use drop-in snippets for shell configuration (they auto-rollback)
    # write_env_snippet "<name>" "export VAR_NAME=value\neval \"\$(<name> init bash)\""
    # write_alias_snippet "<name>" "alias <name>='<command>'"
    # write_completion_snippet "<name>" "source <(<command> completion bash)"
    :
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
| `download_file <url> <dest>` | Resumable and cached download of `<url>` to `<dest>`. Uses `~/.local/state/bootstrap/cache/`. |

### From `lib/platform.sh`

| Function | Description |
|---|---|
| `detect_distro` | Echoes `arch`, `debian`, `fedora`, or `unknown` |
| `detect_arch` | Echoes `x86_64` or `arm64` |
| `pkg_install <pkg>...` | Install packages. Supports distro mapping: `"arch:pkg_a\|debian:pkg_d\|fedora:pkg_f"`. Automatically integrates with rollback context and handles package reference counting. |
| `pkg_check <pkg>...` | Returns 0 if packages are installed. Supports identical mapping syntax. |

### From `lib/rollback.sh`

| Function | Description |
|---|---|
| `track_file <path>` | Registers a file for deletion during `b rb` rollback. |
| `track_dir <path>` | Registers a directory for recursive deletion during rollback. |
| `add_rollback_cmd <cmd>` | Adds a raw bash command to the uninstall manifest (e.g., `add_rollback_cmd "sudo npm uninstall -g <pkg>"`). |

### From `lib/shell_config.sh`

| Function | Description |
|---|---|
| `write_env_snippet <name> <content>` | Creates an isolated `env.d/` shell drop-in snippet and registers it for rollback. |
| `write_alias_snippet <name> <content>` | Creates an isolated `aliases.d/` shell drop-in snippet and registers it for rollback. |
| `write_completion_snippet <name> <content>` | Creates an isolated `completions.d/` bash completion snippet and registers it for rollback. |

---

## Common Patterns

### Temp directory with cleanup

```bash
TMP_DIR="$(make_temp_dir)"
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT
```

### Distro-specific mapping

```bash
pkg_install "arch:neovim|debian:nvim|fedora:neovim" "curl" "git"
```

### Fetching latest GitHub release tag

```bash
local latest_tag=""
if has_command curl; then
    latest_tag=$(curl -sL https://api.github.com/repos/<owner>/<repo>/releases/latest \
        | grep '"tag_name":' | head -n1 \
        | sed -E 's/.*"tag_name": "([^"]+)".*/\1/' || true)
fi

if [ -z "$latest_tag" ]; then
    latest_tag="v1.0.0"  # fallback
    log_warn "Failed to fetch latest version. Falling back to: $latest_tag"
fi
```

### Resumable Download and Extraction

```bash
local url="https://github.com/owner/repo/releases/download/${version}/archive.tar.gz"
local dest="$TMP_DIR/archive.tar.gz"

# Resumable, cached download
download_file "$url" "$dest"

# Extract and install
tar -xzf "$dest" -C "$TMP_DIR"
sudo cp "$TMP_DIR/binary" /usr/local/bin/binary
track_file "/usr/local/bin/binary"
```

---

## Rules & Conventions

1. **File naming**: Always `install_<name>.sh` in the `installers/` directory.
2. **Confirmation prompts**: Always ask before installing. Check if already installed first.
3. **Rollback Tracking**: NEVER omit rollback hooks. If you move a file to `~/.local/bin/`, you MUST call `track_file`. If you run `makepkg`, you MUST call `add_rollback_cmd` for `pacman -R`.
4. **Shell Drop-ins**: Always use `write_env_snippet`, `write_alias_snippet`, or `write_completion_snippet` instead of manually injecting code directly into `~/.bashrc`.
5. **No hardcoded paths**: Use `$HOME`, library functions, and `detect_*` helpers.
6. **Error handling**: Use `set -euo pipefail` after the guard block.
7. **CLI Enforcement Guard**: Always copy the standalone execution guard block verbatim to the top of your installer script to prevent direct execution.
8. **Clean Official Scripts**: When implementing official curl/install scripts provided in the prompt, strip them of bloat, macOS/Windows support, and redundant shell setups before writing the script.
9. **No manual shell re-sourcing**: Do NOT manually run `source ~/.bashrc` or print instructions asking the user to run it. Sourcing of the shell configuration is handled automatically by the central router and CLI at the end of the installation.
