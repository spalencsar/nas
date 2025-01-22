#!/bin/bash

# Security configuration script

secure_shared_memory() {
    log_info "Securing shared memory..."
    handle_error sudo cp /etc/fstab /etc/fstab.bak
    echo "tmpfs /run/shm tmpfs defaults,noexec,nosuid 0 0" | sudo tee -a /etc/fstab
    handle_error sudo mount -o remount /run/shm
    log_info "Shared memory secured."
}

install_fail2ban() {
    log_info "Installing Fail2Ban..."
    case $DISTRO in
        ubuntu|debian)
            handle_error sudo apt-get update
            handle_error sudo apt-get install -y fail2ban
            ;;
        fedora)
            handle_error sudo dnf install -y fail2ban
            ;;
        arch)
            handle_error sudo pacman -S --noconfirm fail2ban
            ;;
        opensuse)
            handle_error sudo zypper install -y fail2ban
            ;;
        *)
            log_error "Unsupported Linux distribution: $DISTRO"
            exit 1
            ;;
    esac
    handle_error sudo systemctl enable fail2ban
    handle_error sudo systemctl start fail2ban
    log_info "Fail2Ban installation completed."
}
