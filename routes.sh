#!/usr/bin/env bash

# Central routing script for bootstrap installers.
# This file is updated automatically by the 'b' command.

if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: This script must be run using bash." >&2
    exit 1
fi

SCRIPT_NAME="${1:-}"
if [ -z "$SCRIPT_NAME" ]; then
    echo "Usage: b <script_name> [args...]" >&2
    exit 1
fi
shift

case "$SCRIPT_NAME" in
    nvim)
        echo "Launching Neovim installer..."
        curl -fsSL "https://git.adityagupta.dev/sortedcord/bootstrap/raw/branch/master/installers/install_nvim.sh" | bash -s -- "$@"
        ;;
    yazi)
        echo "Launching Yazi installer..."
        curl -fsSL "https://git.adityagupta.dev/sortedcord/bootstrap/raw/branch/master/installers/install_yazi.sh" | bash -s -- "$@"
        ;;
    *)
        echo "Error: Unknown script '$SCRIPT_NAME'." >&2
        echo "Available scripts: nvim, yazi" >&2
        exit 1
        ;;
esac
