#!/bin/bash

# Webmin installation and configuration

install_webmin() {
    if [[ "${INSTALL_WEBMIN:-false}" != "true" ]]; then
        return 0
    fi

    log_info "Installing Webmin web interface..."

    case $DISTRO in
        ubuntu|debian)
            # Download and run Webmin setup script
            handle_error curl -o setup-repos.sh https://raw.githubusercontent.com/webmin/webmin/master/setup-repos.sh
            handle_error sudo bash setup-repos.sh

            # Install Webmin
            handle_error sudo apt update
            handle_error sudo apt install -y webmin

            # Clean up setup script
            rm -f setup-repos.sh
            ;;
        fedora)
            # Add Webmin repository
            handle_error sudo curl -o /etc/yum.repos.d/webmin.repo https://raw.githubusercontent.com/webmin/webmin/master/webmin.repo
            handle_error sudo dnf install -y webmin
            ;;
        opensuse)
            # Webmin is not available in official openSUSE Leap repositories
            # For openSUSE, Webmin needs to be installed manually or from third-party repos
            log_warning "Webmin is not available in official openSUSE Leap repositories"
            log_info "To install Webmin on openSUSE manually:"
            log_info "1. Download from https://www.webmin.com/download.html"
            log_info "2. Follow the manual installation instructions"
            log_info "3. Webmin will be available at https://your-server:10000"
            return 1
            ;;
        arch)
            # Webmin is available in AUR
            log_warning "Webmin installation on Arch Linux requires manual AUR installation"
            log_info "Please install Webmin manually from AUR: yay -S webmin"
            log_info "Then run: sudo systemctl enable webmin && sudo systemctl start webmin"
            return 0
            ;;
        *)
            log_error "Webmin installation not supported for $DISTRO"
            return 1
            ;;
    esac

    # Enable and start Webmin service
    handle_error sudo systemctl enable webmin
    handle_error sudo systemctl start webmin

    # Configure firewall for Webmin (port 10000)
    configure_webmin_firewall

    # Get IP address for access information
    local ip_address=$(hostname -I | awk '{print $1}')

    log_success "Webmin installed and configured"
    log_info "Webmin is available at: https://${ip_address}:10000"
    log_info "Default login: root / your root password"
    log_warning "Important: Change the default password after first login!"
    log_info "Note: Webmin uses self-signed SSL certificate - accept the security warning"

    # Add to rollback
    add_rollback_action "sudo systemctl disable webmin && sudo systemctl stop webmin && sudo apt remove -y webmin"
}

# Configure firewall for Webmin access
configure_webmin_firewall() {
    log_info "Configuring firewall for Webmin access..."

    case $DISTRO in
        ubuntu|debian|arch)
            # UFW firewall
            if command -v ufw &> /dev/null; then
                handle_error sudo ufw allow 10000/tcp
                log_info "UFW rule added: allow port 10000/tcp for Webmin"
            fi
            ;;
        fedora|opensuse)
            # Firewalld
            if command -v firewall-cmd &> /dev/null; then
                handle_error sudo firewall-cmd --permanent --add-port=10000/tcp
                handle_error sudo firewall-cmd --reload
                log_info "Firewalld rule added: allow port 10000/tcp for Webmin"
            fi
            ;;
    esac
}

# Webmin configuration optimization
configure_webmin() {
    if [[ "${INSTALL_WEBMIN:-false}" != "true" ]]; then
        return 0
    fi

    log_info "Configuring Webmin optimizations..."

    # Webmin configuration file
    local webmin_config="/etc/webmin/miniserv.conf"

    if [[ -f "$webmin_config" ]]; then
        # Increase session timeout
        sudo sed -i 's/^session_timeout=.*/session_timeout=3600/' "$webmin_config"

        # Configure SSL settings
        sudo sed -i 's/^ssl=.*/ssl=1/' "$webmin_config"
        sudo sed -i 's/^ssl_redirect=.*/ssl_redirect=1/' "$webmin_config"

        # Restart Webmin to apply changes
        handle_error sudo systemctl restart webmin

        log_success "Webmin configuration optimized"
    else
        log_warning "Webmin configuration file not found - skipping optimization"
    fi
}