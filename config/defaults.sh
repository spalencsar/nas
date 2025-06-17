#!/bin/bash

# Default configuration values for NAS setup script

# Script metadata
SCRIPT_VERSION="2.0.0"
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
DOCKER_COMPOSE_VERSION="2.24.0"

# Application data directories
VAULTWARDEN_DATA_DIR="/opt/vaultwarden"
JELLYFIN_DATA_DIR="/var/lib/jellyfin"
PORTAINER_DATA_DIR="/opt/portainer"

# System requirements
MIN_DISK_SPACE_GB=20
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

# Package managers by distribution
declare -A PKG_MANAGERS=(
    ["ubuntu"]="apt-get"
    ["debian"]="apt-get"
    ["fedora"]="dnf"
    ["arch"]="pacman"
    ["opensuse"]="zypper"
)

# Update commands by distribution
declare -A UPDATE_COMMANDS=(
    ["ubuntu"]="apt-get update && apt-get upgrade -y"
    ["debian"]="apt-get update && apt-get upgrade -y"
    ["fedora"]="dnf update -y"
    ["arch"]="pacman -Syu --noconfirm"
    ["opensuse"]="zypper refresh && zypper update -y"
)

# Service ports
declare -A SERVICE_PORTS=(
    ["ssh"]="${DEFAULT_SSH_PORT}"
    ["samba"]="139,445"
    ["nfs"]="2049"
    ["netdata"]="${NETDATA_PORT}"
    ["vaultwarden"]="8080"
    ["jellyfin"]="8096"
    ["portainer"]="9000"
    ["docker"]="2375,2376"
)

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
    
    return $errors
}
