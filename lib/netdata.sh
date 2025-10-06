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

    # Install Netdata using official repository for better reliability
    case $DISTRO in
        ubuntu|debian)
            # Add Netdata repository
            handle_error curl -fsSL https://packagecloud.io/netdata/netdata/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/netdata-archive-keyring.gpg
            handle_error echo "deb [signed-by=/usr/share/keyrings/netdata-archive-keyring.gpg] https://packagecloud.io/netdata/netdata/ubuntu/ noble main" | sudo tee /etc/apt/sources.list.d/netdata.list > /dev/null
            handle_error sudo apt-get update
            handle_error sudo apt-get install -y netdata
            ;;
        fedora)
            # Add Netdata repository
            handle_error curl -fsSL https://packagecloud.io/netdata/netdata/gpgkey | sudo rpm --import -
            handle_error curl -fsSL https://packagecloud.io/install/repositories/netdata/netdata/script.rpm.sh | sudo bash
            handle_error sudo dnf install -y netdata
            ;;
        arch)
            # Install from AUR or official repos if available
            handle_error sudo pacman -S --noconfirm netdata
            ;;
        opensuse)
            # Add Netdata repository (use generic Leap repo)
            handle_error sudo zypper addrepo -f https://packagecloud.io/netdata/netdata/opensuse/leap netdata
            handle_error sudo zypper --gpg-auto-import-keys refresh
            handle_error sudo zypper install -y netdata
            ;;
        *)
            log_error "Unsupported Linux distribution: $DISTRO"
            exit 1
            ;;
    esac

    handle_error sudo systemctl enable netdata
    handle_error sudo systemctl start netdata

    log_info "Netdata installation completed."
}
