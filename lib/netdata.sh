#!/bin/bash

# Netdata installation and configuration script

install_netdata() {
    log_info "Installing Netdata..."

    case $DISTRO in
        ubuntu|debian)
            # Install dependencies
            handle_error sudo apt-get update
            handle_error sudo apt-get install -y curl git
            ;;
        fedora)
            # Install dependencies
            handle_error sudo dnf install -y curl git
            ;;
        arch)
            # Install dependencies
            handle_error sudo pacman -S --noconfirm curl git
            ;;
        opensuse)
            # Install dependencies
            handle_error sudo zypper install -y curl git
            ;;
        *)
            log_error "Unsupported Linux distribution: $DISTRO"
            exit 1
            ;;
    esac

    # Install Netdata from GitHub (works across distributions)
    handle_error bash <(curl -Ss https://my-netdata.io/kickstart.sh) --stable-channel --disable-telemetry

    handle_error sudo systemctl enable netdata
    handle_error sudo systemctl start netdata

    log_info "Netdata installation completed."
}
