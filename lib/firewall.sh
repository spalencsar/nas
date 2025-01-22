#!/bin/bash

# Function to set up firewall rules for Fedora
setup_firewall_fedora() {
    echo "Setting up firewall for Fedora..."
    sudo firewall-cmd --permanent --add-service=http
    sudo firewall-cmd --permanent --add-service=https
    sudo firewall-cmd --reload
    echo "Firewall setup complete for Fedora."
}

# Function to set up firewall rules for Arch Linux
setup_firewall_arch() {
    echo "Setting up firewall for Arch Linux..."
    sudo ufw allow http
    sudo ufw allow https
    sudo ufw enable
    echo "Firewall setup complete for Arch Linux."
}

# Function to set up firewall rules for openSUSE
setup_firewall_opensuse() {
    echo "Setting up firewall for openSUSE..."
    sudo firewall-cmd --permanent --add-service=http
    sudo firewall-cmd --permanent --add-service=https
    sudo firewall-cmd --reload
    echo "Firewall setup complete for openSUSE."
}

# Detect the operating system and call the appropriate function
if [ -f /etc/fedora-release ]; then
    setup_firewall_fedora
elif [ -f /etc/arch-release ]; then
    setup_firewall_arch
elif [ -f /etc/SuSE-release ]; then
    setup_firewall_opensuse
else
    echo "Unsupported operating system."
    exit 1
fi

configure_firewall() {
    log_info "Configuring firewall..."

    # Allow SSH
    ufw allow "${DEFAULT_SSH_PORT}/tcp"
    
    # Allow Samba
    ufw allow from any to any port 137,138 proto udp
    ufw allow from any to any port 139,445 proto tcp

    # Allow NFS
    ufw allow from any to any port 2049 proto tcp

    # Allow Netdata
    ufw allow "${NETDATA_PORT}/tcp"

    # Allow Docker
    ufw allow 2375/tcp
    ufw allow 2376/tcp

    # Enable UFW
    ufw --force enable

    log_info "Firewall configuration completed."
}