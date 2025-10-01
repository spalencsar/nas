#!/bin/bash

# Portainer installation and configuration script (2025-ready)

install_portainer() {
    log_info "Installing Portainer..."

    # Docker muss installiert und aktiv sein
    if ! command -v docker &>/dev/null; then
        log_error "Docker ist nicht installiert. Bitte Docker zuerst installieren."
        exit 1
    fi

    # Portainer-Volume anlegen
    sudo docker volume create portainer_data

    # Vorherigen Portainer-Container stoppen und entfernen, falls vorhanden
    if sudo docker ps -a --format '{{.Names}}' | grep -q '^portainer$'; then
        sudo docker stop portainer || true
        sudo docker rm portainer || true
    fi

    # Aktuelles Portainer-Image holen
    sudo docker pull portainer/portainer-ce:latest

    # Portainer starten (Web: Port 9000, Agent: 8000)
    sudo docker run -d \
        --name portainer \
        --restart=always \
        -p 9000:9000 \
        -p 9443:9443 \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v portainer_data:/data \
        portainer/portainer-ce:latest

    log_success "Portainer wurde erfolgreich installiert und läuft auf Port 9000 (HTTP) und 9443 (HTTPS)."
}

# Logging-Funktionen bereitstellen, falls nicht vorhanden
if ! command -v log_info &>/dev/null; then
    log_info() { echo "[INFO] $1"; }
    log_success() { echo "[SUCCESS] $1"; }
    log_error() { echo "[ERROR] $1" >&2; }
fi

# Hauptlogik
install_portainer