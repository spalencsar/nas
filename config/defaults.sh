#!/bin/bash

# Default configuration values for NAS setup script

# Log file location
LOG_FILE="/var/log/nas_setup.log"

# New user to be created
NEW_USER="nasadmin"

# Samba configuration
SAMBA_CONFIG="/etc/samba/smb.conf"

# Configuration variables
CONFIG_FILE="/etc/nas_setup.conf"
DEFAULT_SSH_PORT=39000
DEFAULT_USER="nas_user"
DEFAULT_DOCKER_DATA_DIR="/var/lib/docker"
DEBUG=${DEBUG:-false}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Network configuration
NETWORK_INTERFACE="eth0"

# Docker configuration
DOCKER_COMPOSE_VERSION="1.29.2"

# NFS configuration
NFS_EXPORT_DIR="/srv/nfs"

# Netdata configuration
NETDATA_PORT="19999"

# Vaultwarden configuration
VAULTWARDEN_DATA_DIR="/opt/vaultwarden"

# Jellyfin configuration
JELLYFIN_DATA_DIR="/var/lib/jellyfin"

# Portainer configuration
PORTAINER_DATA_DIR="/opt/portainer"
