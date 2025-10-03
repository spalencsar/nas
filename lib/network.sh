#!/bin/bash

# Enhanced network configuration with validation and rollback support

# Network interface detection
detect_network_interface() {
    local interface
    
    # Try to detect active interface
    interface=$(ip route show default | awk 'NR==1 {print $5}')
    
    if [[ -z "$interface" ]]; then
        # Fallback to first available interface
        interface=$(ip link show | awk -F: '$0 !~ "lo|vir|docker|br-"{print $2; exit}' | tr -d ' ')
    fi
    
    if [[ -z "$interface" ]]; then
        log_error "No network interface detected"
        return 1
    fi
    
    echo "$interface"
    return 0
}

# Get current network configuration
get_current_network_config() {
    local interface="$1"
    local current_ip gateway_ip dns_servers
    
    # Get current IP
    current_ip=$(ip addr show "$interface" | awk '/inet / {print $2}' | cut -d/ -f1 | head -n1)
    
    # Get current gateway
    gateway_ip=$(ip route show default | awk 'NR==1 {print $3}')
    
    # Get DNS servers
    if [[ -f /etc/resolv.conf ]]; then
        dns_servers=$(awk '/^nameserver/ {print $2}' /etc/resolv.conf | head -n2 | tr '\n' ',' | sed 's/,$//')
    fi
    
    echo "Current IP: ${current_ip:-"Not set"}"
    echo "Current Gateway: ${gateway_ip:-"Not set"}"
    echo "Current DNS: ${dns_servers:-"Not set"}"
}

# Configure static IP for Ubuntu/Debian (netplan)
configure_netplan() {
    local interface="$1"
    local static_ip="$2"
    local gateway_ip="$3"
    local dns_ip="$4"
    local netplan_file="/etc/netplan/01-netcfg.yaml"
    
    log_info "Configuring network via netplan..."
    
    # Backup existing configuration
    if ! backup_config "$netplan_file"; then
        return 1
    fi
    
    # Create new netplan configuration (IPv4 and IPv6)
    cat <<EOF | sudo tee "$netplan_file" > /dev/null
network:
  version: 2
  renderer: networkd
  ethernets:
    $interface:
      addresses: [$static_ip/24]
      routes:
        - to: default
          via: $gateway_ip
      nameservers:
        addresses: [$dns_ip, 8.8.8.8, 2001:4860:4860::8888]
      dhcp4: false
      dhcp6: false
EOF

    # Validate netplan configuration
    if ! sudo netplan generate 2>/dev/null; then
        log_error "Invalid netplan configuration generated"
        return 1
    fi
    
    # Apply configuration
    if sudo netplan apply; then
        log_success "Netplan configuration applied successfully"
        add_rollback_action "sudo cp ${netplan_file}.bak ${netplan_file} && sudo netplan apply"
        return 0
    else
        log_error "Failed to apply netplan configuration"
        return 1
    fi
}

# Configure static IP for RedHat-based systems
configure_networkmanager() {
    local interface="$1"
    local static_ip="$2"
    local gateway_ip="$3"
    local dns_ip="$4"
    local ifcfg_file="/etc/sysconfig/network-scripts/ifcfg-$interface"
    
    log_info "Configuring network via NetworkManager..."
    
    # Backup existing configuration
    if [[ -f "$ifcfg_file" ]]; then
        backup_config "$ifcfg_file"
    fi
    
    # Create new interface configuration
    cat <<EOF | sudo tee "$ifcfg_file" > /dev/null
DEVICE=$interface
BOOTPROTO=none
ONBOOT=yes
IPADDR=$static_ip
PREFIX=24
GATEWAY=$gateway_ip
DNS1=$dns_ip
DNS2=8.8.8.8
DEFROUTE=yes
EOF

    # Restart NetworkManager
    if sudo systemctl restart NetworkManager; then
        log_success "NetworkManager configuration applied successfully"
        add_rollback_action "sudo systemctl restart NetworkManager"
        return 0
    else
        log_error "Failed to restart NetworkManager"
        return 1
    fi
}

# Configure static IP for Arch Linux
configure_systemd_networkd() {
    local interface="$1"
    local static_ip="$2"
    local gateway_ip="$3"
    local dns_ip="$4"
    local network_file="/etc/systemd/network/20-$interface.network"
    
    log_info "Configuring network via systemd-networkd..."
    
    # Create network configuration
    cat <<EOF | sudo tee "$network_file" > /dev/null
[Match]
Name=$interface

[Network]
Address=$static_ip/24
Gateway=$gateway_ip
DNS=$dns_ip
DNS=8.8.8.8
EOF

    # Enable and restart systemd-networkd
    sudo systemctl enable systemd-networkd
    if sudo systemctl restart systemd-networkd; then
        log_success "systemd-networkd configuration applied successfully"
        add_rollback_action "sudo rm -f $network_file && sudo systemctl restart systemd-networkd"
        return 0
    else
        log_error "Failed to restart systemd-networkd"
        return 1
    fi
}

# Test network connectivity after configuration
test_network_connectivity() {
    local test_ip="$1"
    local timeout=30
    local count=0
    
    log_info "Testing network connectivity..."
    
    while [[ $count -lt $timeout ]]; do
        if ping -c 1 -W 3 "$test_ip" &>/dev/null; then
            log_success "Network connectivity test passed"
            return 0
        fi
        
        ((count++))
        echo -n "."
        sleep 1
    done
    
    echo
    log_error "Network connectivity test failed after ${timeout} seconds"
    return 1
}

# Configure SSH with enhanced security
configure_ssh() {
    local ssh_config="/etc/ssh/sshd_config"
    local ssh_port="${SSH_PORT:-$DEFAULT_SSH_PORT}"
    
    log_info "Configuring SSH server..."
    
    # Backup SSH configuration
    if ! backup_config "$ssh_config"; then
        return 1
    fi
    
    # Create new user if not exists
    if ! id "${ADMIN_USER:-$NEW_USER}" &>/dev/null; then
        log_info "Creating user ${ADMIN_USER:-$NEW_USER}..."
        sudo useradd -m -s /bin/bash "${ADMIN_USER:-$NEW_USER}"
        sudo usermod -aG sudo "${ADMIN_USER:-$NEW_USER}"
        
        # Set password
        local password=$(ask_password "Set password for user ${ADMIN_USER:-$NEW_USER}")
        echo "${ADMIN_USER:-$NEW_USER}:$password" | sudo chpasswd
        
        add_rollback_action "sudo userdel -r ${ADMIN_USER:-$NEW_USER}"
    fi
    
    # Configure SSH hardening
    sudo tee -a "$ssh_config" > /dev/null <<EOF

# NAS Setup Script Configuration
Port $ssh_port
PermitRootLogin no
PasswordAuthentication yes
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
ClientAliveInterval 300
ClientAliveCountMax 2
MaxAuthTries 3
LoginGraceTime 60
AllowUsers ${ADMIN_USER:-$NEW_USER}
Protocol 2
EOF

    # Test SSH configuration
    if sudo sshd -t; then
        log_success "SSH configuration is valid"
    else
        log_error "SSH configuration is invalid"
        return 1
    fi
    
    # Restart SSH service using helper (handles sshd vs ssh service names)
    if restart_ssh_service; then
        add_rollback_action "sudo cp ${ssh_config}.bak ${ssh_config} && restart_ssh_service"
        return 0
    else
        log_error "Failed to restart SSH service"
        return 1
    fi
}

# Setup Samba with enhanced configuration
setup_samba() {
    log_info "Setting up Samba file sharing..."
    
    # Install Samba
    case $DISTRO in
        ubuntu|debian)
            sudo apt-get install -y samba samba-common-bin
            ;;
        fedora)
            sudo dnf install -y samba samba-common
            ;;
        arch)
            sudo pacman -S --noconfirm samba
            ;;
        opensuse)
            sudo zypper install -y samba
            ;;
    esac
    
    # Backup Samba configuration
    backup_config "$SAMBA_CONFIG"
    
    # Create shared directory
    local share_dir="/srv/samba/shared"
    sudo mkdir -p "$share_dir"
    sudo chown "${ADMIN_USER:-$NEW_USER}:${ADMIN_USER:-$NEW_USER}" "$share_dir"
    sudo chmod 755 "$share_dir"
    
    # Configure Samba
    sudo tee "$SAMBA_CONFIG" > /dev/null <<EOF
[global]
    workgroup = WORKGROUP
    server string = NAS Server
    security = user
    map to guest = bad user
    dns proxy = no
    log file = /var/log/samba/log.%m
    max log size = 1000
    
    # Performance tuning
    socket options = TCP_NODELAY IPTOS_LOWDELAY SO_RCVBUF=131072 SO_SNDBUF=131072
    read raw = yes
    write raw = yes
    oplocks = yes
    max xmit = 65535
    dead time = 15
    getwd cache = yes

[shared]
    path = $share_dir
    browseable = yes
    writable = yes
    guest ok = no
    valid users = ${ADMIN_USER:-$NEW_USER}
    create mask = 0644
    directory mask = 0755
EOF

    # Add Samba user
    local samba_password=$(ask_password "Set Samba password for user ${ADMIN_USER:-$NEW_USER}")
    echo -e "$samba_password\n$samba_password" | sudo smbpasswd -a "${ADMIN_USER:-$NEW_USER}"
    sudo smbpasswd -e "${ADMIN_USER:-$NEW_USER}"
    
    # Start and enable Samba services
    sudo systemctl enable smbd nmbd
    if sudo systemctl restart smbd nmbd; then
        log_success "Samba configured and started successfully"
        log_info "Shared folder created at: $share_dir"
        add_rollback_action "sudo systemctl stop smbd nmbd && sudo systemctl disable smbd nmbd"
        return 0
    else
        log_error "Failed to start Samba services"
        return 1
    fi
}

# Main network configuration function
configure_network() {
    if [[ "${CONFIGURE_STATIC_IP:-false}" != "true" ]]; then
        log_info "Static IP configuration skipped"
        return 0
    fi
    
    log_info "=== Network Configuration ==="
    
    # Detect network interface
    local interface
    if ! interface=$(detect_network_interface); then
        log_error "Failed to detect network interface"
        return 1
    fi
    
    log_info "Detected network interface: $interface"
    
    # Show current configuration
    log_info "Current network configuration:"
    get_current_network_config "$interface"
    echo
    
    # Get network configuration from user
    local current_ip=$(ip addr show "$interface" | awk '/inet / {print $2}' | cut -d/ -f1 | head -n1)
    local current_gateway=$(ip route show default | awk 'NR==1 {print $3}')
    
    local static_ip=$(ask_input "Static IP address" "$current_ip" "validate_ip")
    local gateway_ip=$(ask_input "Gateway IP address" "$current_gateway" "validate_ip")
    local dns_ip=$(ask_input "Primary DNS server" "8.8.8.8" "validate_ip")
    
    # Confirm configuration
    echo
    log_info "Network configuration summary:"
    echo "  Interface: $interface"
    echo "  Static IP: $static_ip"
    echo "  Gateway: $gateway_ip"
    echo "  DNS: $dns_ip"
    echo
    
    if ! ask_yes_no "Apply this network configuration?" "y"; then
        log_info "Network configuration cancelled"
        return 0
    fi
    
    # Apply configuration based on distribution
    case $DISTRO in
        ubuntu|debian)
            configure_netplan "$interface" "$static_ip" "$gateway_ip" "$dns_ip"
            ;;
        fedora|opensuse)
            configure_networkmanager "$interface" "$static_ip" "$gateway_ip" "$dns_ip"
            ;;
        arch)
            configure_systemd_networkd "$interface" "$static_ip" "$gateway_ip" "$dns_ip"
            ;;
        *)
            log_error "Unsupported distribution for network configuration: $DISTRO"
            return 1
            ;;
    esac
    
    # Test connectivity
    log_info "Waiting for network to stabilize..."
    sleep 5
    
    if test_network_connectivity "$gateway_ip"; then
        log_success "Network configuration completed successfully"
        return 0
    else
        log_error "Network configuration failed connectivity test"
        return 1
    fi
}
