#!/bin/bash

install_nfs() {
    log_info "Installing NFS..."
    case $DISTRO in
        ubuntu|debian)
            handle_error sudo apt-get install -y nfs-kernel-server
            ;;
        fedora)
            handle_error sudo dnf install -y nfs-utils
            ;;
        arch)
            handle_error sudo pacman -S --noconfirm nfs-utils
            ;;
        opensuse)
            handle_error sudo zypper install -y nfs-kernel-server
            ;;
        *)
            log_error "Unsupported Linux distribution: $DISTRO"
            exit 1
            ;;
    esac
    log_info "NFS installation completed."
}
