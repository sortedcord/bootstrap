#!/usr/bin/env bash

# This is a metascript called by parent scripts to verify the execution environment.
# It checks if the current shell is bash or not. If not, it terminates execution.

if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: This script must be run using bash." >&2
    exit 1
fi

# Detect if the script is sourced
is_sourced=false
if [ -n "${BASH_SOURCE[0]:-}" ] && [ "${BASH_SOURCE[0]}" != "$0" ]; then
    is_sourced=true
fi
# Detect eval from installers based on presence of specific variables
if [ -n "${METASCRIPT_URL:-}" ]; then
    is_sourced=true
fi

# Locate or download libraries so that sourced installers can use them
BOOTSTRAP_DIR="${BOOTSTRAP_DIR:-$HOME/.config/bootstrap}"
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null)" || _SCRIPT_DIR="$(pwd)"

if [ -f "$_SCRIPT_DIR/lib/common.sh" ]; then
    # Dev/local mode: source directly from repo
    BOOTSTRAP_SOURCE_DIR="$_SCRIPT_DIR"
elif [ -f "$BOOTSTRAP_DIR/lib/common.sh" ]; then
    # Installed mode: source from bootstrap dir
    BOOTSTRAP_SOURCE_DIR="$BOOTSTRAP_DIR"
else
    # Standalone/remote mode: download to a temp directory and source
    export BOOTSTRAP_TMP_DIR
    BOOTSTRAP_TMP_DIR="$(mktemp -d)"
    trap 'rm -rf "$BOOTSTRAP_TMP_DIR"' EXIT
    BOOTSTRAP_SOURCE_DIR="$BOOTSTRAP_TMP_DIR"
    
    _BASE_URL="https://git.adityagupta.dev/sortedcord/bootstrap/raw/branch/master"
    _LIBS=("lib/common.sh" "lib/rollback.sh" "lib/platform.sh" "lib/shell_config.sh" "lib/plugins.sh" "lib/registry_helpers.sh" "lib/github.sh")
    
    _curl_args=()
    for _lib in "${_LIBS[@]}"; do
        mkdir -p "$BOOTSTRAP_TMP_DIR/$(dirname "$_lib")"
        _curl_args+=("-o" "$BOOTSTRAP_TMP_DIR/$_lib" "$_BASE_URL/$_lib")
    done
    curl -fsSL "${_curl_args[@]}" 2>/dev/null
fi

if [ -f "$BOOTSTRAP_SOURCE_DIR/lib/common.sh" ]; then
    . "$BOOTSTRAP_SOURCE_DIR/lib/common.sh"
    . "$BOOTSTRAP_SOURCE_DIR/lib/rollback.sh"
    . "$BOOTSTRAP_SOURCE_DIR/lib/platform.sh"
    . "$BOOTSTRAP_SOURCE_DIR/lib/shell_config.sh"
    . "$BOOTSTRAP_SOURCE_DIR/lib/registry_helpers.sh"
    . "$BOOTSTRAP_SOURCE_DIR/lib/github.sh"
    init_rollback_system
else
    echo "Error: Failed to locate or download bootstrap libraries." >&2
    exit 1
fi

# Install/update the bootstrap loader and download all necessary files
install_bootstrap() {
    local target_files=()
    [ -f "$HOME/.bashrc" ] && target_files+=("$HOME/.bashrc")

    local routes_dir="$HOME/.config/bootstrap"
    mkdir -p "$routes_dir/env.d"
    mkdir -p "$routes_dir/aliases.d"
    mkdir -p "$routes_dir/completions.d"

    # Initialize XDG directories
    mkdir -p "$HOME/.local/share/bootstrap/bin"
    mkdir -p "$HOME/.local/share/bootstrap/opt"
    mkdir -p "$HOME/.local/share/bootstrap/runtimes"
    mkdir -p "$HOME/.local/state/bootstrap/logs"
    mkdir -p "$HOME/.local/state/bootstrap/rollback"
    mkdir -p "$HOME/.cache/bootstrap/downloads"
    mkdir -p "$HOME/.cache/bootstrap/tmp"

    # Create the universal binary PATH snippet
    cat << 'EOF' > "$routes_dir/env.d/bootstrap-bin.sh"
export BOOTSTRAP_BIN="$BOOTSTRAP_BIN"
case ":$PATH:" in
  *":$BOOTSTRAP_BIN:"*) ;;
  *) export PATH="$BOOTSTRAP_BIN:$PATH" ;;
esac
EOF

    # List of all files to download/copy
    local files=(
        "VERSION"
        "b.sh"
        "lib/routes.sh"
        "lib/registry.sh"
        "lib/common.sh"
        "lib/rollback.sh"
        "lib/platform.sh"
        "lib/shell_config.sh"
        "lib/registry_helpers.sh"
        "lib/github.sh"
        "lib/plugins.sh"
        "commands/help.sh"
        "commands/con.sh"
        "commands/uninstall.sh"
        "commands/up.sh"
    )

    if ! pkg_check jq >/dev/null 2>&1; then
        log_info "jq is missing. Installing jq..."
        pkg_install jq
    fi

    if [ -f "$_SCRIPT_DIR/b.sh" ] && [ -f "$_SCRIPT_DIR/lib/routes.sh" ]; then
        log_info "Using local files from repository..."
        for file in "${files[@]}"; do
            mkdir -p "$(dirname "$routes_dir/$file")"
            if [ -f "$_SCRIPT_DIR/$file" ]; then
                cp "$_SCRIPT_DIR/$file" "$routes_dir/$file"
            fi
        done
        
        # Also copy tools if they exist locally
        if [ -d "$_SCRIPT_DIR/tools" ]; then
            mkdir -p "$routes_dir/tools"
            cp -r "$_SCRIPT_DIR/tools/"* "$routes_dir/tools/"
        fi

        # Also copy plugins if they exist locally
        if [ -d "$_SCRIPT_DIR/plugins" ]; then
            mkdir -p "$routes_dir/plugins"
            cp -r "$_SCRIPT_DIR/plugins/"* "$routes_dir/plugins/"
        fi
    else
        log_info "Downloading bootstrap scripts..."
        local base_url="https://git.adityagupta.dev/sortedcord/bootstrap/raw/branch/master"
        
        local curl_args=()
        for file in "${files[@]}"; do
            mkdir -p "$(dirname "$routes_dir/$file")"
            curl_args+=("-o" "$routes_dir/$file" "$base_url/$file")
        done
        if ! curl -fsSL "${curl_args[@]}"; then
            log_error "Failed to download bootstrap scripts."
            exit 1
        fi
    fi

    # Create ~/.bash_aliases if it doesn't exist
    if [ ! -f "$HOME/.bash_aliases" ]; then
        log_info "Creating ~/.bash_aliases..."
        touch "$HOME/.bash_aliases"
    fi

    # Set up shell configuration files
    for config_file in "${target_files[@]}"; do
        # 1. Clean up old embedded function block if it exists (from previous setup)
        remove_block "$config_file" "bootstrap-cli b function"

        # 2. Clean up old loader block if it exists
        remove_block "$config_file" "bootstrap-cli setup"

        # 3. Append the new lightweight loader block that sources modular configs
        log_info "Adding bootstrap loader to $config_file..."
        cat << 'EOF' >> "$config_file"

# >>> bootstrap-cli setup >>>
export BOOTSTRAP_DIR="$HOME/.config/bootstrap"
export BOOTSTRAP_DATA_DIR="$HOME/.local/share/bootstrap"
export BOOTSTRAP_STATE_DIR="$HOME/.local/state/bootstrap"
export BOOTSTRAP_CACHE_DIR="$HOME/.cache/bootstrap"
export BOOTSTRAP_BIN="$BOOTSTRAP_DATA_DIR/bin"
export BOOTSTRAP_OPT="$BOOTSTRAP_DATA_DIR/opt"
export BOOTSTRAP_RUNTIMES="$BOOTSTRAP_DATA_DIR/runtimes"

[ -f "$BOOTSTRAP_DIR/b.sh" ] && . "$BOOTSTRAP_DIR/b.sh"
for f in "$BOOTSTRAP_DIR/env.d/"*.sh; do [ -r "$f" ] && . "$f"; done
for f in "$BOOTSTRAP_DIR/aliases.d/"*.sh; do [ -r "$f" ] && . "$f"; done
for f in "$BOOTSTRAP_DIR/completions.d/"*.sh; do [ -r "$f" ] && . "$f"; done
# <<< bootstrap-cli setup <<<
EOF

        # 4. Ensure ~/.bash_aliases is sourced in ~/.bashrc if not already
        if [ "$config_file" = "$HOME/.bashrc" ]; then
            if ! grep -q "bash_aliases" "$config_file" 2>/dev/null; then
                local alias_source_content
                alias_source_content=$(cat << 'EOF'
# Source aliases file if it exists
if [ -f "$HOME/.bash_aliases" ]; then
    . "$HOME/.bash_aliases"
fi
EOF
)
                inject_block "$config_file" "bootstrap-cli bash_aliases setup" "$alias_source_content"
            fi
        fi
    done

    # Initialize the last update timestamp to prevent immediate update on first execution (Fix 2)
    local last_update_file="$routes_dir/.last_b_update"
    date +%s 2>/dev/null > "$last_update_file" || date +%s > "$last_update_file"

    # Set up pre-commit hook if in a git repository locally
    if [ -d "$_SCRIPT_DIR/.git" ]; then
        log_info "Setting up git pre-commit hook..."
        mkdir -p "$_SCRIPT_DIR/.git/hooks"
        if [ -f "$_SCRIPT_DIR/scripts/pre-commit" ]; then
            cp "$_SCRIPT_DIR/scripts/pre-commit" "$_SCRIPT_DIR/.git/hooks/pre-commit"
            chmod +x "$_SCRIPT_DIR/.git/hooks/pre-commit"
            log_success "Pre-commit hook installed to .git/hooks/pre-commit"
        fi
    fi
}

# Only execute installation if not sourced (Fix 3)
if [ "$is_sourced" = false ]; then
    clear 2>/dev/null || true

    # Locate or download pixel_art.ansi and VERSION
    _art_file="$BOOTSTRAP_SOURCE_DIR/assets/pixel_art.ansi"
    _version_file="$BOOTSTRAP_SOURCE_DIR/VERSION"
    
    if [ ! -f "$_art_file" ] && [ -n "${BOOTSTRAP_TMP_DIR:-}" ]; then
        _base_url="${_BASE_URL:-https://git.adityagupta.dev/sortedcord/bootstrap/raw/branch/master}"
        mkdir -p "$(dirname "$_art_file")"
        curl -fsSL -o "$_art_file" "$_base_url/assets/pixel_art.ansi" 2>/dev/null || true
        curl -fsSL -o "$_version_file" "$_base_url/VERSION" 2>/dev/null || true
    fi

    if [ -f "$_art_file" ]; then
        # Calculate terminal width and center the logo
        _cols=""
        if command -v tput >/dev/null 2>&1; then
            _cols=$(tput cols 2>/dev/null)
        fi
        if [ -z "$_cols" ] || ! [ "$_cols" -gt 0 ] 2>/dev/null; then
            if command -v stty >/dev/null 2>&1; then
                _cols=$(stty size 2>/dev/null | cut -d' ' -f2)
            fi
        fi
        if [ -z "$_cols" ] || ! [ "$_cols" -gt 0 ] 2>/dev/null; then
            _cols="${COLUMNS:-0}"
        fi

        _logo_width=64
        if [ -n "$_cols" ] && [ "$_cols" -ge "$_logo_width" ] 2>/dev/null; then
            _padding_width=$(( (_cols - _logo_width) / 2 ))
            _padding=""
            if [ "$_padding_width" -gt 0 ]; then
                _padding=$(printf "%${_padding_width}s" "")
            fi
            sed "s/^/$_padding/" "$_art_file"
            echo
            cat << 'EOF' | sed "s/^/$_padding/"
▀█████████▄   ▄██████▄   ▄██████▄      ███                      
  ███    ███ ███    ███ ███    ███ ▀█████████▄                  
  ███    ███ ███    ███ ███    ███    ▀███▀▀██                  
 ▄███▄▄▄██▀  ███    ███ ███    ███     ███   ▀                  
▀▀███▀▀▀██▄  ███    ███ ███    ███     ███                      
  ███    ██▄ ███    ███ ███    ███     ███                      
  ███    ███ ███    ███ ███    ███     ███                      
▄█████████▀   ▀██████▀   ▀██████▀     ▄████▀                    
                                                                
   ▄████████     ███        ▄████████    ▄████████    ▄███████▄ 
  ███    ███ ▀█████████▄   ███    ███   ███    ███   ███    ███ 
  ███    █▀     ▀███▀▀██   ███    ███   ███    ███   ███    ███ 
  ███            ███   ▀  ▄███▄▄▄▄██▀   ███    ███   ███    ███ 
▀███████████     ███     ▀▀███▀▀▀▀▀   ▀███████████ ▀█████████▀  
         ███     ███     ▀███████████   ███    ███   ███        
   ▄█    ███     ███       ███    ███   ███    ███   ███        
 ▄████████▀     ▄████▀     ███    ███   ███    █▀   ▄████▀      
                           ███    ███                           
EOF
            echo
            
            # Display centered version of bootstrap in bold
            _version=""
            if [ -f "$_version_file" ]; then
                _version=$(tr -d '\r\n' < "$_version_file")
            fi
            if [ -z "$_version" ]; then
                _version="0.0.0" # Fallback if VERSION missing
            fi
            _version_str="v$_version"
            _version_len=${#_version_str}
            _version_padding_width=$(( (_cols - _version_len) / 2 ))
            _version_padding=""
            if [ "$_version_padding_width" -gt 0 ]; then
                _version_padding=$(printf "%${_version_padding_width}s" "")
            fi
            printf "%s\033[1m%s\033[0m\n" "$_version_padding" "$_version_str"
            echo
            
            # Display centered aqua blue progress bar (non-blocking)
            _bar_width=40
            _bar_padding_width=$(( (_cols - (_bar_width + 6)) / 2 ))
            _bar_padding=""
            if [ "$_bar_padding_width" -gt 0 ]; then
                _bar_padding=$(printf "%${_bar_padding_width}s" "")
            fi
            
            _filled_all="████████████████████████████████████████"
            _empty_all="░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░"
            
            # Hide cursor
            printf "\033[?25l"
            
            # Capture install output to a temp file so logs don't bleed into the bar
            _install_log=$(mktemp)
            
            # Launch progress bar in background
            (
                for i in $(seq 1 40); do
                    _filled_part="${_filled_all:0:i}"
                    _empty_part="${_empty_all:i}"
                    _pct=$(( i * 100 / 40 ))
                    printf "\r%s\033[38;2;0;210;255m%s\033[90m%s\033[0m %3d%%" "$_bar_padding" "$_filled_part" "$_empty_part" "$_pct"
                    sleep 0.05
                done
            ) &
            _bar_pid=$!
            
            # Run installation concurrently, silencing all output to the log file
            install_bootstrap >"$_install_log" 2>&1
            
            # Wait for the progress bar to finish
            wait "$_bar_pid" 2>/dev/null
            
            # Snap to 100% in case install finished before the bar
            printf "\r%s\033[38;2;0;210;255m%s\033[0m %3d%%" "$_bar_padding" "$_filled_all" 100
            
            # Restore cursor, clear screen, then replay captured install logs
            printf "\033[?25h\n"
            clear 2>/dev/null || true
            cat "$_install_log"
            rm -f "$_install_log"
            _bootstrap_installed=true
        fi
    fi
    if [ "${_bootstrap_installed:-false}" != true ]; then
        install_bootstrap
    fi

    # Load the b function immediately in the current subshell
    if [ -f "$HOME/.config/bootstrap/b.sh" ]; then
        # shellcheck source=/dev/null
        . "$HOME/.config/bootstrap/b.sh"
    fi

    # Handle sourcing the shell configuration file or printing instructions (Fix 1)
    echo
    log_success "Bootstrap CLI installed successfully!"
    log_info "To start using the 'b' command in this terminal session, run:"
    echo "  source ~/.bashrc"
else
    # Sourced mode (e.g., when sourced by installers or manually by user)
    # Load the b function in the current shell context
    if [ -f "$HOME/.config/bootstrap/b.sh" ]; then
        # shellcheck source=/dev/null
        . "$HOME/.config/bootstrap/b.sh"
    fi
fi

