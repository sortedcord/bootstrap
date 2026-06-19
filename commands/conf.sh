# Command: conf
# Edits configurations in ~/.config/

config_name="${1:-}"
if [ -z "$config_name" ]; then
    log_error "Usage: b conf <config_name> [files...]"
    exit 1
fi
shift

config_dir=""
if [ -d "$HOME/.config/$config_name" ]; then
    config_dir="$HOME/.config/$config_name"
else
    # Find matching directory case-insensitively using pure Bash
    for d in "$HOME/.config"/*; do
        if [ -d "$d" ]; then
            basename="${d##*/}"
            if [[ "${basename,,}" == *"${config_name,,}"* ]]; then
                config_dir="$d"
                break
            fi
        fi
    done
fi

if [ -n "$config_dir" ] && [ -d "$config_dir" ]; then
    editor="${EDITOR:-nvim}"
    log_info "Opening editor in $config_dir"
    
    # Run editor in a subshell so parent working directory is unchanged
    (
        cd "$config_dir" || exit 1
        if [ $# -gt 0 ]; then
            "$editor" "$@"
        else
            "$editor" .
        fi
    )
else
    log_error "Could not find config directory matching: $config_name"
    exit 1
fi
