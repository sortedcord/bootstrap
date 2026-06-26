#!/usr/bin/env bash
# Tool: docker
# DisplayName: Docker
# Description: Container runtime and orchestration platform
# Strategy: system
#
# Docker Installer Script
#

set -euo pipefail

# ─── Installation Logic ──────────────────────────────────────────────

install_docker() {
    if has_command docker; then
        if ! confirm "Docker is already installed. Reinstall/Upgrade?"; then
            log_info "Skipping Docker installation."
            return
        fi
    else
        if ! confirm "Install Docker?"; then
            log_info "Skipping Docker installation."
            return
        fi
    fi

    # Use pkg_install for distro packages (it automatically handles rollback hooks for the packages!)
    pkg_install "arch:docker|debian:docker.io|fedora:docker"

    # Ensure docker group exists (some distros might not create it immediately)
    if ! getent group docker >/dev/null 2>&1; then
        log_info "Creating docker group..."
        add_rollback_cmd "sudo groupdel docker || true"
        sudo groupadd docker
    fi

    # Configure user group
    if ! groups "$USER" | grep -q "\bdocker\b"; then
        log_info "Adding $USER to the docker group..."
        add_rollback_cmd "sudo gpasswd -d $USER docker || true"
        sudo usermod -aG docker "$USER"
        log_warn "You will need to log out and log back in, or run 'newgrp docker' for the group changes to take effect."
    fi

    # Enable and start systemd services
    if has_command systemctl; then
        log_info "Enabling and starting Docker services..."
        
        # Add rollback cmds for systemd
        add_rollback_cmd "sudo systemctl disable --now docker.service || true"
        add_rollback_cmd "sudo systemctl disable --now containerd.service || true"
        
        sudo systemctl enable --now docker.service || true
        sudo systemctl enable --now containerd.service || true
    fi
    register_tool "docker" "system" "" "os-package-manager"
}

# ─── Main ─────────────────────────────────────────────────────────────

main() {
    install_docker

    echo
    log_success "Docker installation and configuration complete."
}

main "$@"
