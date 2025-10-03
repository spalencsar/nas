#!/bin/bash

# Default configuration values for NAS setup script

# Script metadata
SCRIPT_VERSION="2.1.1"
SCRIPT_NAME="NAS Setup Script"
SCRIPT_AUTHOR="Sebastian Palencsár"

# Directories and files
LOG_FILE="/var/log/nas_setup.log"
CONFIG_FILE="/etc/nas_setup.conf"
ROLLBACK_FILE="/tmp/nas_setup_rollback.sh"
TEMP_DIR="/tmp/nas_setup"

# User configuration
NEW_USER="nasadmin"
DEFAULT_USER="nas_user"

# Network configuration
NETWORK_INTERFACE="eth0"
DEFAULT_SSH_PORT=39000

# Service configurations
SAMBA_CONFIG="/etc/samba/smb.conf"
NFS_EXPORT_DIR="/srv/nfs"
NETDATA_PORT="19999"

# Docker configuration
DEFAULT_DOCKER_DATA_DIR="/var/lib/docker"
DOCKER_COMPOSE_VERSION="2.30.0"

# Application data directories
VAULTWARDEN_DATA_DIR="/opt/vaultwarden"
JELLYFIN_DATA_DIR="/var/lib/jellyfin"
PORTAINER_DATA_DIR="/opt/portainer"

# System requirements
MIN_DISK_SPACE_GB=30
MIN_RAM_MB=2048
RECOMMENDED_RAM_MB=4096

# Security settings
ENABLE_FAIL2BAN=true
ENABLE_UFW=true
ENABLE_AUTO_UPDATES=true
SECURE_SSH=true

# Debug and logging
DEBUG=${DEBUG:-false}
LOG_LEVEL=${LOG_LEVEL:-"INFO"}
ENABLE_PROGRESS_BAR=true

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Supported distributions
SUPPORTED_DISTROS=("ubuntu" "debian" "fedora" "arch" "opensuse")

# Get package manager for distribution
get_package_manager() {
    local distro="$1"
    case "$distro" in
        ubuntu|debian) echo "apt-get" ;;
        fedora) echo "dnf" ;;
        arch) echo "pacman" ;;
        opensuse) echo "zypper" ;;
        *) echo "unknown" ;;
    esac
}

# Get update command for distribution
get_update_command() {
    local distro="$1"
    case "$distro" in
        ubuntu|debian) echo "apt-get update && apt-get upgrade -y" ;;
        fedora) echo "dnf update -y" ;;
        arch) echo "pacman -Syu --noconfirm" ;;
        opensuse) echo "zypper refresh && zypper update -y" ;;
        *) echo "unknown" ;;
    esac
}

# Get service port for service
get_service_port() {
    local service="$1"
    case "$service" in
        ssh) echo "${DEFAULT_SSH_PORT}" ;;
        samba) echo "139,445" ;;
        nfs) echo "2049" ;;
        netdata) echo "${NETDATA_PORT}" ;;
        vaultwarden) echo "8080" ;;
        jellyfin) echo "8096" ;;
        portainer) echo "9000" ;;
        docker) echo "2375,2376" ;;
        *) echo "unknown" ;;
    esac
}

# Default firewall rules
FIREWALL_RULES=(
    "allow ${DEFAULT_SSH_PORT}/tcp comment 'SSH'"
    "allow from any to any port 139,138 proto udp comment 'Samba'"
    "allow from any to any port 139,445 proto tcp comment 'Samba'"
    "allow 2049/tcp comment 'NFS'"
    "allow ${NETDATA_PORT}/tcp comment 'Netdata'"
)

# Feature flags - can be overridden by user config
INSTALL_DOCKER=${INSTALL_DOCKER:-false}
INSTALL_NFS=${INSTALL_NFS:-false}
INSTALL_NETDATA=${INSTALL_NETDATA:-false}
INSTALL_VAULTWARDEN=${INSTALL_VAULTWARDEN:-false}
INSTALL_JELLYFIN=${INSTALL_JELLYFIN:-false}
INSTALL_PORTAINER=${INSTALL_PORTAINER:-false}
INSTALL_WEBMIN=${INSTALL_WEBMIN:-false}

# Configuration validation
validate_config() {
    local errors=0
    
    # Validate SSH port
    if ! validate_port "${DEFAULT_SSH_PORT}"; then
        log_error "Invalid SSH port: ${DEFAULT_SSH_PORT}"
        ((errors++))
    fi
    
    # Validate user names
    if ! validate_username "${NEW_USER}"; then
        log_error "Invalid username: ${NEW_USER}"
        ((errors++))
    fi
    
    # Validate directories
    for dir in "${VAULTWARDEN_DATA_DIR}" "${JELLYFIN_DATA_DIR}" "${PORTAINER_DATA_DIR}"; do
        if ! validate_path "${dir}"; then
            log_error "Invalid directory path: ${dir}"
            ((errors++))
        fi
    done
    
# Validate Docker dependencies
    if [[ "${INSTALL_DOCKER:-false}" != "true" ]]; then
        if [[ "${INSTALL_VAULTWARDEN:-false}" == "true" ]] || [[ "${INSTALL_JELLYFIN:-false}" == "true" ]] || [[ "${INSTALL_PORTAINER:-false}" == "true" ]]; then
            log_warning "Docker-abhängige Services sind aktiviert, aber Docker ist deaktiviert. Erzwinge neue Konfiguration."
            return 1  # Force create_interactive_config
        fi
    fi
    
    # Temporarily force new configuration for debugging
    log_warning "Erzwinge neue Konfiguration für Debugging-Zwecke."
    return 1
    
    return $errors
}
