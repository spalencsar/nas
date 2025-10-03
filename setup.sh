#!/bin/bash

# NAS Setup Script - Version 2.1.1
#
# This script automates the setup of a NAS system with various services.
# It is designed to run on multiple Linux distributions, including:
# - Ubuntu 24.04+
# - Debian 12+
# - Fedora 41+
# - Arch Linux
# - openSUSE Leap 15.6+
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
source "${SCRIPT_DIR}/lib/detection.sh"
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
source "${SCRIPT_DIR}/lib/webmin.sh"
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

# Detect Linux distribution with comprehensive fallback methods
detect_distro() {
    local detected_distro=""
    local detected_version=""
    local detected_codename=""
    local detection_method=""

    log_debug "Starting distribution detection..."

    # Method 1: /etc/os-release (primary method for modern systems)
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release 2>/dev/null || true
        detected_distro=${ID,,}  # Convert to lowercase
        detected_version=$VERSION_ID
        detected_codename=${VERSION_CODENAME:-${UBUNTU_CODENAME:-""}}
        detection_method="/etc/os-release"
        log_debug "Detected via /etc/os-release: $PRETTY_NAME"
    fi

    # Method 2: /etc/redhat-release (fallback for RHEL/CentOS/Fedora)
    if [[ -z "$detected_distro" ]] && [[ -f /etc/redhat-release ]]; then
        local redhat_info=$(cat /etc/redhat-release)
        if [[ $redhat_info =~ ^(CentOS|Red Hat Enterprise|Fedora) ]]; then
            detected_distro="fedora"
            detected_version=$(echo "$redhat_info" | grep -oP '\d+\.\d+' | head -1)
            detection_method="/etc/redhat-release"
            log_debug "Detected via /etc/redhat-release: $redhat_info"
        fi
    fi

    # Method 3: /etc/debian_version (fallback for Debian/Ubuntu)
    if [[ -z "$detected_distro" ]] && [[ -f /etc/debian_version ]]; then
        local debian_version=$(cat /etc/debian_version)
        if [[ -f /etc/lsb-release ]]; then
            source /etc/lsb-release 2>/dev/null || true
            detected_distro=${DISTRIB_ID,,}
            detected_version=$DISTRIB_RELEASE
            detected_codename=${DISTRIB_CODENAME:-""}
            detection_method="/etc/lsb-release"
        else
            # Pure Debian system
            detected_distro="debian"
            detected_version=$debian_version
            detection_method="/etc/debian_version"
        fi
        log_debug "Detected via Debian method: $detected_distro $detected_version"
    fi

    # Method 4: lsb_release command (fallback)
    if [[ -z "$detected_distro" ]] && command -v lsb_release >/dev/null 2>&1; then
        detected_distro=$(lsb_release -si 2>/dev/null | tr '[:upper:]' '[:lower:]')
        detected_version=$(lsb_release -sr 2>/dev/null)
        detected_codename=$(lsb_release -sc 2>/dev/null)
        detection_method="lsb_release command"
        log_debug "Detected via lsb_release command: $detected_distro $detected_version"
    fi

    # Method 5: uname and manual detection (last resort)
    if [[ -z "$detected_distro" ]]; then
        if [[ -f /etc/arch-release ]]; then
            detected_distro="arch"
            detected_version="rolling"
            detection_method="/etc/arch-release"
        elif [[ -f /etc/gentoo-release ]]; then
            detected_distro="gentoo"
            detected_version=$(cat /etc/gentoo-release | grep -oP '\d+\.\d+' | head -1)
            detection_method="/etc/gentoo-release"
        elif uname -a | grep -qi "opensuse"; then
            detected_distro="opensuse"
            detected_version="unknown"
            detection_method="uname opensuse"
        fi
        log_debug "Detected via fallback method: $detected_distro"
    fi

    # Validate detection
    if [[ -z "$detected_distro" ]]; then
        log_error "Failed to detect Linux distribution using all available methods"
        log_error "Please check your system and ensure it's a supported Linux distribution"
        log_error "Supported: ${SUPPORTED_DISTROS[*]}"
        exit 1
    fi

    # Normalize distribution names
    case $detected_distro in
        ubuntu|debian|fedora|arch|opensuse)
            DISTRO=$detected_distro
            ;;
        "red hat enterprise linux server"|"rhel")
            DISTRO="fedora"  # Treat RHEL as Fedora for package management
            ;;
        "centos linux"|"centos")
            DISTRO="fedora"  # CentOS uses same package manager as Fedora
            ;;
        *)
            # Check if it's a known variant
            if [[ " ${SUPPORTED_DISTROS[*]} " =~ " ${detected_distro} " ]]; then
                DISTRO=$detected_distro
            else
                log_error "Detected distribution '$detected_distro' is not in supported list"
                log_error "Supported distributions: ${SUPPORTED_DISTROS[*]}"
                log_error "Detection method: $detection_method"
                exit 1
            fi
            ;;
    esac

    # Parse and normalize version
    DISTRO_VERSION=$(normalize_version "$detected_version")
    DISTRO_CODENAME=$detected_codename

    log_info "Distribution detected: $DISTRO $DISTRO_VERSION ($detection_method)"
    if [[ -n "$DISTRO_CODENAME" ]]; then
        log_debug "Codename: $DISTRO_CODENAME"
    fi

    # Validate supported distribution
    if [[ ! " ${SUPPORTED_DISTROS[*]} " =~ " ${DISTRO} " ]]; then
        log_error "Unsupported Linux distribution: $DISTRO"
        log_info "Supported distributions: ${SUPPORTED_DISTROS[*]}"
        log_info "Detection method: $detection_method"
        exit 1
    fi

    # Check minimum versions with improved parsing
    validate_minimum_version "$DISTRO" "$DISTRO_VERSION"

    # Check for container environments
    detect_container_environment

    # Cache the results for performance
    export DISTRO DETECTED_DISTRO=$DISTRO
    export DISTRO_VERSION DETECTED_VERSION=$DISTRO_VERSION
    export DISTRO_CODENAME DETECTED_CODENAME=$DISTRO_CODENAME
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
    
    # Temporarily force new configuration for debugging
    # Remove any existing config file to ensure clean state
    rm -f "${CONFIG_FILE}"
    log_info "Creating new configuration..."
    create_interactive_config
    load_config  # Load the new configuration
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
    local install_docker=$(ask_yes_no "Install Docker?" "y" && echo "true" || echo "false")
    save_config "INSTALL_DOCKER" "$install_docker"
    save_config "INSTALL_NFS" "$(ask_yes_no "Install NFS?" "n" && echo "true" || echo "false")"
    save_config "INSTALL_NETDATA" "$(ask_yes_no "Install Netdata monitoring?" "y" && echo "true" || echo "false")"
    
    # Docker-dependent services
    if [[ "$install_docker" == "true" ]]; then
        save_config "INSTALL_VAULTWARDEN" "$(ask_yes_no "Install Vaultwarden password manager?" "n" && echo "true" || echo "false")"
        save_config "INSTALL_JELLYFIN" "$(ask_yes_no "Install Jellyfin media server?" "n" && echo "true" || echo "false")"
        save_config "INSTALL_PORTAINER" "$(ask_yes_no "Install Portainer Docker management?" "n" && echo "true" || echo "false")"
    else
        log_warning "Docker not selected - skipping Docker-dependent services (Vaultwarden, Jellyfin, Portainer)"
        save_config "INSTALL_VAULTWARDEN" "false"
        save_config "INSTALL_JELLYFIN" "false"
        save_config "INSTALL_PORTAINER" "false"
    fi
    
    save_config "INSTALL_WEBMIN" "$(ask_yes_no "Install Webmin web interface?" "n" && echo "true" || echo "false")"
    
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
    local total_steps=13
    local current_step=0
    
    log_info "Starting NAS installation process..."
    
    # Core system setup
    ((current_step++)); log_debug "run_installation: about to install dependencies (step $current_step/$total_steps)"; show_progress $current_step $total_steps "Installing dependencies"
    install_dependencies
    
    ((current_step++)); log_debug "run_installation: about to configure network (step $current_step/$total_steps)"; show_progress $current_step $total_steps "Configuring network"
    if [[ "${CONFIGURE_STATIC_IP:-false}" == "true" ]]; then
        configure_network
    fi
    
    ((current_step++)); log_debug "run_installation: about to configure SSH (step $current_step/$total_steps)"; show_progress $current_step $total_steps "Configuring SSH"
    configure_ssh
    
    ((current_step++)); log_debug "run_installation: about to setup Samba (step $current_step/$total_steps)"; show_progress $current_step $total_steps "Setting up Samba"
    setup_samba
    
    ((current_step++)); log_debug "run_installation: about to configure firewall (step $current_step/$total_steps)"; show_progress $current_step $total_steps "Configuring firewall"
    configure_firewall
    
    # Security setup
    ((current_step++)); log_debug "run_installation: about to implement security measures (step $current_step/$total_steps)"; show_progress $current_step $total_steps "Implementing security measures"
    secure_shared_memory
    install_fail2ban
    configure_automatic_updates
    
    # Optional services
    if [[ "${INSTALL_DOCKER:-false}" == "true" ]]; then
        ((current_step++)); log_debug "run_installation: about to install Docker (step $current_step/$total_steps)"; show_progress $current_step $total_steps "Installing Docker"
        install_docker
    else
        ((current_step++))
    fi
    
    if [[ "${INSTALL_NFS:-false}" == "true" ]]; then
        ((current_step++)); log_debug "run_installation: about to install NFS (step $current_step/$total_steps)"; show_progress $current_step $total_steps "Installing NFS"
        install_nfs
    else
        ((current_step++))
    fi
    
    if [[ "${INSTALL_NETDATA:-false}" == "true" ]]; then
        ((current_step++)); log_debug "run_installation: about to install Netdata (step $current_step/$total_steps)"; show_progress $current_step $total_steps "Installing Netdata"
        install_netdata
    else
        ((current_step++))
    fi
    
    if [[ "${INSTALL_VAULTWARDEN:-false}" == "true" ]]; then
        ((current_step++)); log_debug "run_installation: about to install Vaultwarden (step $current_step/$total_steps)"; show_progress $current_step $total_steps "Installing Vaultwarden"
        install_vaultwarden
    else
        ((current_step++))
    fi
    
    if [[ "${INSTALL_JELLYFIN:-false}" == "true" ]]; then
        ((current_step++)); log_debug "run_installation: about to install Jellyfin (step $current_step/$total_steps)"; show_progress $current_step $total_steps "Installing Jellyfin"
        install_jellyfin
    else
        ((current_step++))
    fi
    
    if [[ "${INSTALL_PORTAINER:-false}" == "true" ]]; then
        ((current_step++)); log_debug "run_installation: about to install Portainer (step $current_step/$total_steps)"; show_progress $current_step $total_steps "Installing Portainer"
        install_portainer
    else
        ((current_step++))
    fi
    
    if [[ "${INSTALL_WEBMIN:-false}" == "true" ]]; then
        ((current_step++)); log_debug "run_installation: about to install Webmin (step $current_step/$total_steps)"; show_progress $current_step $total_steps "Installing Webmin"
        install_webmin
        configure_webmin
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
    if [[ "${INSTALL_WEBMIN:-false}" == "true" ]]; then
        echo "  ✓ Webmin web interface: https://$(hostname -I | awk '{print $1}'):10000"
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
    
    # Unset any existing config variables to ensure clean state
    unset INSTALL_DOCKER INSTALL_NFS INSTALL_NETDATA INSTALL_VAULTWARDEN INSTALL_JELLYFIN INSTALL_PORTAINER INSTALL_WEBMIN CONFIGURE_STATIC_IP SSH_PORT ADMIN_USER
    
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
