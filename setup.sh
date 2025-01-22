#!/bin/bash

# NAS Setup Script - Version 3.4
#
# This script automates the setup of a NAS system with various services.
# It is designed to run on multiple Linux distributions, including:
# - Ubuntu
# - Debian
# - Fedora
# - Arch Linux
# - openSUSE
#
# Disclaimer:
# This script is provided "as is", without warranty of any kind, express or implied,
# including but not limited to the warranties of merchantability, fitness for a particular purpose,
# and noninfringement. In no event shall the authors or copyright holders be liable for any claim,
# damages, or other liability, whether in an action of contract, tort, or otherwise, arising from,
# out of, or in connection with the software or the use or other dealings in the software.
#
# Usage:
# Run this script with root privileges on a fresh installation of a supported Linux distribution.
# Ensure you have an active internet connection before starting the setup.
#
# Author: Sebastian Palencsár
# License: MIT License
# (c) 2025 Sebastian Palencsár

# Import configuration and functions
source "$(dirname "$0")/config/defaults.sh"
source "$(dirname "$0")/lib/logging.sh"
source "$(dirname "$0")/lib/network.sh"
source "$(dirname "$0")/lib/docker.sh"
source "$(dirname "$0")/lib/security.sh"
source "$(dirname "$0")/lib/internet.sh"
source "$(dirname "$0")/lib/nfs.sh"
source "$(dirname "$0")/lib/netdata.sh"
source "$(dirname "$0")/lib/firewall.sh"
source "$(dirname "$0")/lib/unattended-upgrades.sh"
source "$(dirname "$0")/lib/vaultwarden.sh"
source "$(dirname "$0")/lib/jellyfin.sh"
source "$(dirname "$0")/lib/portainer.sh"

# Logging configuration
exec > >(tee -a "${LOG_FILE}") 2>&1

# Improved error handling
handle_error() {
    "$@"
    local status=$?
    if [ $status -ne 0 ]; then
        log_error "Error executing $* (exit code: $status)"
        exit 1
    fi
}

# Detect Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
    else
        log_error "Unsupported Linux distribution."
        exit 1
    fi
}

# Main script execution
log_info "NAS Setup Script started."

detect_distro
check_internet_connection

case $DISTRO in
    ubuntu|debian)
        check_ubuntu_version
        ;;
    fedora|arch|opensuse)
        # Add specific checks here if needed
        ;;
    *)
        log_error "Unsupported Linux distribution: $DISTRO"
        exit 1
        ;;
esac

check_system_requirements

load_or_create_config

update_system

configure_network
configure_ssh
setup_samba
configure_firewall

secure_shared_memory
install_fail2ban
configure_automatic_updates
setup_basic_monitoring

if ask_yes_no "Do you want to install Docker?"; then
    install_docker
fi

if ask_yes_no "Do you want to install additional components?"; then
    install_additional_components
else
    log_info "Installation of additional components skipped."
fi

if ask_yes_no "Do you want to install NFS?"; then
    install_nfs
fi

if ask_yes_no "Do you want to install Netdata for advanced monitoring?"; then
    install_netdata
fi

if ask_yes_no "Do you want to install Vaultwarden?"; then
    install_vaultwarden
fi

if ask_yes_no "Do you want to install Jellyfin?"; then
    install_jellyfin
fi

if ask_yes_no "Do you want to install Portainer?"; then
    install_portainer
fi

cleanup

log_info "Setup completed. User $NEW_USER has been created with sudo and Samba access. Installation of optional components completed."
show_progress 100 100 "Setup completed"

log_info "Please reboot your system to ensure all changes take effect."
if ask_yes_no "Do you want to reboot now?"; then
    sudo reboot
fi
