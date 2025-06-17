#!/bin/bash

# NAS Setup Script - Version 2.0.0
#
# This script automates the setup of a NAS system with various services.
# It is designed to run on multiple Linux distributions, including:
# - Ubuntu 20.04+
# - Debian 11+
# - Fedora 35+
# - Arch Linux
# - openSUSE Leap 15.4+
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

set -euo pipefail  # Strict error handling

# Script directory and imports
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Import configuration and functions
source "${SCRIPT_DIR}/config/defaults.sh"
source "${SCRIPT_DIR}/lib/logging.sh"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/network.sh"
source "${SCRIPT_DIR}/lib/docker.sh"
source "${SCRIPT_DIR}/lib/security.sh"
source "${SCRIPT_DIR}/lib/internet.sh"
source "${SCRIPT_DIR}/lib/nfs.sh"
source "${SCRIPT_DIR}/lib/netdata.sh"
source "${SCRIPT_DIR}/lib/firewall.sh"
source "${SCRIPT_DIR}/lib/unattended-upgrades.sh"
source "${SCRIPT_DIR}/lib/vaultwarden.sh"
source "${SCRIPT_DIR}/lib/jellyfin.sh"
source "${SCRIPT_DIR}/lib/portainer.sh"
source "${SCRIPT_DIR}/lib/performance.sh"

# Initialize logging
mkdir -p "$(dirname "${LOG_FILE}")"
mkdir -p "${TEMP_DIR}"

# Setup logging with rotation
exec > >(tee -a "${LOG_FILE}") 2>&1

# Enhanced error handling with rollback
handle_error() {
    local exit_code=$?
    local line_number=$1
    local command="$2"
    
    log_error "Script failed at line ${line_number}: ${command} (exit code: ${exit_code})"
    
    if ask_yes_no "An error occurred. Would you like to rollback changes?" "y"; then
        execute_rollback
    fi
    
    cleanup
    exit $exit_code
}

# Set error trap
trap 'handle_error ${LINENO} "$BASH_COMMAND"' ERR

# Signal handlers
cleanup_on_exit() {
    log_info "Script interrupted. Performing cleanup..."
    cleanup
    exit 130
}

trap cleanup_on_exit SIGINT SIGTERM

# Detect Linux distribution with version check
detect_distro() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        DISTRO=$ID
        DISTRO_VERSION=$VERSION_ID
        DISTRO_CODENAME=${VERSION_CODENAME:-""}
        
        log_info "Detected distribution: $PRETTY_NAME"
        
        # Validate supported distribution
        if [[ ! " ${SUPPORTED_DISTROS[*]} " =~ " ${DISTRO} " ]]; then
            log_error "Unsupported Linux distribution: $DISTRO"
            log_info "Supported distributions: ${SUPPORTED_DISTROS[*]}"
            exit 1
        fi
        
        # Check minimum versions
        case $DISTRO in
            ubuntu)
                if [[ $(echo "$DISTRO_VERSION >= 20.04" | bc -l) -eq 0 ]]; then
                    log_warning "Ubuntu version $DISTRO_VERSION is not officially supported. Minimum: 20.04"
                fi
                ;;
            debian)
                if [[ ${DISTRO_VERSION%%.*} -lt 11 ]]; then
                    log_warning "Debian version $DISTRO_VERSION is not officially supported. Minimum: 11"
                fi
                ;;
        esac
    else
        log_error "Cannot detect Linux distribution. /etc/os-release not found."
        exit 1
    fi
}

# System requirements check
check_system_requirements() {
    log_info "Checking system requirements..."
    
    local requirements_met=true
    
    # Check disk space
    if ! check_disk_space $MIN_DISK_SPACE_GB; then
        requirements_met=false
    fi
    
    # Check RAM
    check_ram $MIN_RAM_MB
    
    # Check if running as root
    check_root
    
    # Check internet connectivity
    if ! check_internet_enhanced; then
        requirements_met=false
    fi
    
    # Check architecture
    local arch=$(uname -m)
    case $arch in
        x86_64|amd64)
            log_info "Architecture check passed: $arch"
            ;;
        aarch64|arm64)
            log_warning "ARM64 architecture detected. Some packages may not be available."
            ;;
        *)
            log_error "Unsupported architecture: $arch"
            requirements_met=false
            ;;
    esac
    
    if [[ "$requirements_met" == false ]]; then
        log_error "System requirements not met. Exiting."
        exit 1
    fi
    
    log_success "All system requirements met"
}

# Configuration management
load_or_create_config() {
    log_info "Loading configuration..."
    
    if load_config; then
        log_info "Configuration loaded from ${CONFIG_FILE}"
        if ! validate_config; then
            log_error "Configuration validation failed"
            exit 1
        fi
    else
        log_info "Creating new configuration..."
        create_interactive_config
    fi
}

create_interactive_config() {
    log_info "Interactive configuration setup"
    echo
    
    # SSH configuration
    local ssh_port=$(ask_input "SSH port" "$DEFAULT_SSH_PORT" "validate_port")
    save_config "SSH_PORT" "$ssh_port"
    
    # User configuration
    local username=$(ask_input "Admin username" "$NEW_USER" "validate_username")
    save_config "ADMIN_USER" "$username"
    
    # Network configuration
    if ask_yes_no "Configure static IP?" "n"; then
        save_config "CONFIGURE_STATIC_IP" "true"
    else
        save_config "CONFIGURE_STATIC_IP" "false"
    fi
    
    # Service selection
    save_config "INSTALL_DOCKER" "$(ask_yes_no "Install Docker?" "y" && echo "true" || echo "false")"
    save_config "INSTALL_NFS" "$(ask_yes_no "Install NFS?" "n" && echo "true" || echo "false")"
    save_config "INSTALL_NETDATA" "$(ask_yes_no "Install Netdata monitoring?" "y" && echo "true" || echo "false")"
    save_config "INSTALL_VAULTWARDEN" "$(ask_yes_no "Install Vaultwarden password manager?" "n" && echo "true" || echo "false")"
    save_config "INSTALL_JELLYFIN" "$(ask_yes_no "Install Jellyfin media server?" "n" && echo "true" || echo "false")"
    save_config "INSTALL_PORTAINER" "$(ask_yes_no "Install Portainer Docker management?" "n" && echo "true" || echo "false")"
    
    log_success "Configuration created and saved to ${CONFIG_FILE}"
}

# System update with progress
update_system() {
    log_info "Updating system packages..."
    show_progress 1 10 "System Update"
    
    case $DISTRO in
        ubuntu|debian)
            sudo apt-get update -qq
            show_progress 5 10 "System Update"
            sudo apt-get upgrade -y -qq
            ;;
        fedora)
            sudo dnf update -y -q
            ;;
        arch)
            sudo pacman -Syu --noconfirm --quiet
            ;;
        opensuse)
            sudo zypper refresh -q
            sudo zypper update -y -q
            ;;
    esac
    
    show_progress 10 10 "System Update"
    add_rollback_action "# System packages updated - no rollback needed"
}

# Main installation orchestrator
run_installation() {
    local total_steps=12
    local current_step=0
    
    log_info "Starting NAS installation process..."
    
    # Core system setup
    ((current_step++)); show_progress $current_step $total_steps "Installing dependencies"
    install_dependencies
    
    ((current_step++)); show_progress $current_step $total_steps "Configuring network"
    if [[ "${CONFIGURE_STATIC_IP:-false}" == "true" ]]; then
        configure_network
    fi
    
    ((current_step++)); show_progress $current_step $total_steps "Configuring SSH"
    configure_ssh
    
    ((current_step++)); show_progress $current_step $total_steps "Setting up Samba"
    setup_samba
    
    ((current_step++)); show_progress $current_step $total_steps "Configuring firewall"
    configure_firewall
    
    # Security setup
    ((current_step++)); show_progress $current_step $total_steps "Implementing security measures"
    secure_shared_memory
    install_fail2ban
    configure_automatic_updates
    
    # Optional services
    if [[ "${INSTALL_DOCKER:-false}" == "true" ]]; then
        ((current_step++)); show_progress $current_step $total_steps "Installing Docker"
        install_docker
    else
        ((current_step++))
    fi
    
    if [[ "${INSTALL_NFS:-false}" == "true" ]]; then
        ((current_step++)); show_progress $current_step $total_steps "Installing NFS"
        install_nfs
    else
        ((current_step++))
    fi
    
    if [[ "${INSTALL_NETDATA:-false}" == "true" ]]; then
        ((current_step++)); show_progress $current_step $total_steps "Installing Netdata"
        install_netdata
    else
        ((current_step++))
    fi
    
    if [[ "${INSTALL_VAULTWARDEN:-false}" == "true" ]]; then
        ((current_step++)); show_progress $current_step $total_steps "Installing Vaultwarden"
        install_vaultwarden
    else
        ((current_step++))
    fi
    
    if [[ "${INSTALL_JELLYFIN:-false}" == "true" ]]; then
        ((current_step++)); show_progress $current_step $total_steps "Installing Jellyfin"
        install_jellyfin
    else
        ((current_step++))
    fi
    
    if [[ "${INSTALL_PORTAINER:-false}" == "true" ]]; then
        ((current_step++)); show_progress $current_step $total_steps "Installing Portainer"
        install_portainer
    else
        ((current_step++))
    fi
}

# Installation summary
show_installation_summary() {
    echo
    log_success "=== NAS Setup Completed Successfully ==="
    echo
    log_info "Installation Summary:"
    echo "  ✓ System updated and secured"
    echo "  ✓ User '${ADMIN_USER:-$NEW_USER}' created with sudo access"
    echo "  ✓ SSH configured on port ${SSH_PORT:-$DEFAULT_SSH_PORT}"
    echo "  ✓ Samba file sharing configured"
    echo "  ✓ Firewall configured and enabled"
    echo "  ✓ Fail2ban installed and configured"
    echo "  ✓ Automatic updates enabled"
    
    # Service summary
    if [[ "${INSTALL_DOCKER:-false}" == "true" ]]; then
        echo "  ✓ Docker installed and configured"
    fi
    if [[ "${INSTALL_NFS:-false}" == "true" ]]; then
        echo "  ✓ NFS server installed"
    fi
    if [[ "${INSTALL_NETDATA:-false}" == "true" ]]; then
        echo "  ✓ Netdata monitoring: http://$(hostname -I | awk '{print $1}'):${NETDATA_PORT}"
    fi
    if [[ "${INSTALL_JELLYFIN:-false}" == "true" ]]; then
        echo "  ✓ Jellyfin media server: http://$(hostname -I | awk '{print $1}'):8096"
    fi
    if [[ "${INSTALL_PORTAINER:-false}" == "true" ]]; then
        echo "  ✓ Portainer Docker management: http://$(hostname -I | awk '{print $1}'):9000"
    fi
    
    echo
    log_info "Next steps:"
    echo "  1. Reboot the system to ensure all changes take effect"
    echo "  2. Access your NAS via SSH on port ${SSH_PORT:-$DEFAULT_SSH_PORT}"
    echo "  3. Configure file shares through Samba"
    echo "  4. Review firewall rules with: sudo ufw status"
    echo
    log_warning "Important: Please save the following information:"
    echo "  - SSH Port: ${SSH_PORT:-$DEFAULT_SSH_PORT}"
    echo "  - Admin User: ${ADMIN_USER:-$NEW_USER}"
    echo "  - Configuration saved in: ${CONFIG_FILE}"
    echo "  - Installation log: ${LOG_FILE}"
}

# Main script execution
main() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║               ${SCRIPT_NAME} v${SCRIPT_VERSION}                        ║"
    echo "║                                                              ║"
    echo "║         Automated NAS Setup for Multiple Linux Distros      ║"
    echo "║                                                              ║"
    echo "║                    by ${SCRIPT_AUTHOR}              ║"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo
    
    log_info "${SCRIPT_NAME} v${SCRIPT_VERSION} started"
    log_info "Running on: $(uname -a)"
    
    # Pre-flight checks
    detect_distro
    check_system_requirements
    get_system_info
    
    # Configuration
    load_or_create_config
    
    # Confirmation
    echo
    if ! ask_yes_no "Ready to start installation?" "y"; then
        log_info "Installation cancelled by user"
        exit 0
    fi
    
    # Main installation
    log_info "Starting installation process..."
    update_system
    run_installation
    
    # Cleanup and summary
    cleanup
    optimize_nas_performance
    perform_health_check
    show_installation_summary
    
    # Reboot prompt
    echo
    if ask_yes_no "Reboot system now to complete setup?" "y"; then
        log_info "System will reboot in 5 seconds..."
        sleep 5
        sudo reboot
    else
        log_warning "Please reboot the system manually to complete the setup"
    fi
}

# Run main function
main "$@"
