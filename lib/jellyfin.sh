#!/bin/bash

# Jellyfin installation and configuration script

log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
}

handle_error() {
    "$@"
    local status=$?
    if [ $status -ne 0 ]; then
        log_error "Error with $1"
        exit 1
    fi
}

install_jellyfin() {
    log_info "Installing Jellyfin..."

    case $DISTRO in
        ubuntu|debian)
            handle_error sudo apt-get update
            handle_error sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
            handle_error curl -fsSL https://repo.jellyfin.org/jellyfin_team.gpg.key | sudo gpg --dearmor -o /usr/share/keyrings/jellyfin.gpg
            handle_error echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/jellyfin.gpg] https://repo.jellyfin.org/$(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/jellyfin.list > /dev/null
            handle_error sudo apt-get update
            handle_error sudo apt-get install -y jellyfin
            ;;
        fedora)
            handle_error sudo dnf config-manager --add-repo https://repo.jellyfin.org/releases/server/fedora/jellyfin.repo
            handle_error sudo dnf install -y jellyfin
            ;;
        arch)
            handle_error sudo pacman -S --noconfirm jellyfin
            ;;
        opensuse)
            handle_error sudo zypper addrepo https://repo.jellyfin.org/releases/server/opensuse/jellyfin.repo
            handle_error sudo zypper refresh
            handle_error sudo zypper install -y jellyfin
            ;;
        *)
            log_error "Unsupported Linux distribution: $DISTRO"
            exit 1
            ;;
    esac

    handle_error sudo systemctl enable jellyfin
    handle_error sudo systemctl start jellyfin

    log_info "Jellyfin installation completed."
}

# Logging-Funktionen bereitstellen, falls nicht vorhanden
if ! command -v log_info &>/dev/null; then
    log_info() { echo "[INFO] $1"; }
    log_error() { echo "[ERROR] $1" >&2; }
fi

# Nur ausführen, wenn diese Datei direkt ausgeführt wird (nicht beim `source` in setup.sh).
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Detect the distribution and call the appropriate function
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        install_jellyfin
    else
        log_error "Cannot detect the operating system."
        exit 1
    fi
fi