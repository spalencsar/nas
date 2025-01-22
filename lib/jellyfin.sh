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
            handle_error sudo apt-get install -y apt-transport-https software-properties-common
            handle_error wget -O - https://repo.jellyfin.org/jellyfin_team.gpg.key | sudo apt-key add -
            handle_error sudo add-apt-repository "deb [arch=$(dpkg --print-architecture)] https://repo.jellyfin.org/$(lsb_release -cs) main"
            handle_error sudo apt-get update
            handle_error sudo apt-get install -y jellyfin
            ;;
        fedora)
            handle_error sudo dnf install -y https://repo.jellyfin.org/releases/server/fedora/releases/jellyfin-server.rpm
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

# Detect the distribution and call the appropriate function
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
    install_jellyfin
else
    log_error "Cannot detect the operating system."
    exit 1
fi