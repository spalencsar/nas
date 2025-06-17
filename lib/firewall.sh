#!/bin/bash

# Enhanced firewall configuration with comprehensive rules and intrusion detection

# UFW configuration function
configure_ufw() {
    log_info "Configuring UFW (Uncomplicated Firewall)..."
    
    # Install UFW if not present
    case $DISTRO in
        ubuntu|debian)
            sudo apt-get install -y ufw
            ;;
        arch)
            sudo pacman -S --noconfirm ufw
            ;;
        fedora|opensuse)
            log_warning "UFW not available on $DISTRO, using firewalld instead"
            return 1
            ;;
    esac
    
    # Reset UFW to defaults
    sudo ufw --force reset
    
    # Set default policies
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw default deny forward
    
    # Configure logging
    sudo ufw logging medium
    
    return 0
}

# Firewalld configuration function  
configure_firewalld() {
    log_info "Configuring firewalld..."
    
    # Install firewalld if not present
    case $DISTRO in
        fedora)
            sudo dnf install -y firewalld
            ;;
        opensuse)
            sudo zypper install -y firewalld
            ;;
        *)
            log_error "Firewalld not supported on $DISTRO"
            return 1
            ;;
    esac
    
    # Enable and start firewalld
    sudo systemctl enable firewalld
    sudo systemctl start firewalld
    
    # Set default zone
    sudo firewall-cmd --set-default-zone=public
    
    return 0
}

# Add UFW rules
add_ufw_rules() {
    local ssh_port="${SSH_PORT:-$DEFAULT_SSH_PORT}"
    
    log_info "Adding UFW firewall rules..."
    
    # SSH access
    sudo ufw allow "$ssh_port/tcp" comment "SSH"
    
    # Samba file sharing
    sudo ufw allow from any to any port 137,138 proto udp comment "Samba NetBIOS"
    sudo ufw allow from any to any port 139,445 proto tcp comment "Samba SMB"
    
    # NFS (if enabled)
    if [[ "${INSTALL_NFS:-false}" == "true" ]]; then
        sudo ufw allow 2049/tcp comment "NFS"
        sudo ufw allow 111/tcp comment "NFS Portmapper"
        sudo ufw allow 111/udp comment "NFS Portmapper"
    fi
    
    # Docker (if enabled)
    if [[ "${INSTALL_DOCKER:-false}" == "true" ]]; then
        sudo ufw allow 2375/tcp comment "Docker API"
        sudo ufw allow 2376/tcp comment "Docker API TLS"
    fi
    
    # Netdata monitoring (if enabled)
    if [[ "${INSTALL_NETDATA:-false}" == "true" ]]; then
        sudo ufw allow "$NETDATA_PORT/tcp" comment "Netdata"
    fi
    
    # Jellyfin media server (if enabled)
    if [[ "${INSTALL_JELLYFIN:-false}" == "true" ]]; then
        sudo ufw allow 8096/tcp comment "Jellyfin HTTP"
        sudo ufw allow 8920/tcp comment "Jellyfin HTTPS"
        sudo ufw allow 1900/udp comment "Jellyfin DLNA"
        sudo ufw allow 7359/udp comment "Jellyfin Discovery"
    fi
    
    # Portainer (if enabled)
    if [[ "${INSTALL_PORTAINER:-false}" == "true" ]]; then
        sudo ufw allow 9000/tcp comment "Portainer"
    fi
    
    # Vaultwarden (if enabled)
    if [[ "${INSTALL_VAULTWARDEN:-false}" == "true" ]]; then
        sudo ufw allow 8080/tcp comment "Vaultwarden"
    fi
    
    # Basic network services
    sudo ufw allow out 53 comment "DNS"
    sudo ufw allow out 80/tcp comment "HTTP"
    sudo ufw allow out 443/tcp comment "HTTPS"
    sudo ufw allow out 123/udp comment "NTP"
    
    # Local network communication
    local local_networks=("192.168.0.0/16" "10.0.0.0/8" "172.16.0.0/12")
    for network in "${local_networks[@]}"; do
        sudo ufw allow from "$network" comment "Local network"
    done
    
    log_success "UFW rules configured successfully"
}

# Add firewalld rules
add_firewalld_rules() {
    local ssh_port="${SSH_PORT:-$DEFAULT_SSH_PORT}"
    
    log_info "Adding firewalld rules..."
    
    # SSH access
    sudo firewall-cmd --permanent --add-port="$ssh_port/tcp"
    
    # Remove default SSH if using custom port
    if [[ "$ssh_port" != "22" ]]; then
        sudo firewall-cmd --permanent --remove-service=ssh
    fi
    
    # Samba file sharing
    sudo firewall-cmd --permanent --add-service=samba
    
    # NFS (if enabled)
    if [[ "${INSTALL_NFS:-false}" == "true" ]]; then
        sudo firewall-cmd --permanent --add-service=nfs
        sudo firewall-cmd --permanent --add-service=rpc-bind
        sudo firewall-cmd --permanent --add-service=mountd
    fi
    
    # HTTP services for web interfaces
    sudo firewall-cmd --permanent --add-service=http
    sudo firewall-cmd --permanent --add-service=https
    
    # Netdata monitoring (if enabled)
    if [[ "${INSTALL_NETDATA:-false}" == "true" ]]; then
        sudo firewall-cmd --permanent --add-port="$NETDATA_PORT/tcp"
    fi
    
    # Jellyfin media server (if enabled)
    if [[ "${INSTALL_JELLYFIN:-false}" == "true" ]]; then
        sudo firewall-cmd --permanent --add-port=8096/tcp
        sudo firewall-cmd --permanent --add-port=8920/tcp
        sudo firewall-cmd --permanent --add-port=1900/udp
        sudo firewall-cmd --permanent --add-port=7359/udp
    fi
    
    # Portainer (if enabled)
    if [[ "${INSTALL_PORTAINER:-false}" == "true" ]]; then
        sudo firewall-cmd --permanent --add-port=9000/tcp
    fi
    
    # Vaultwarden (if enabled)
    if [[ "${INSTALL_VAULTWARDEN:-false}" == "true" ]]; then
        sudo firewall-cmd --permanent --add-port=8080/tcp
    fi
    
    # Reload firewalld
    sudo firewall-cmd --reload
    
    log_success "Firewalld rules configured successfully"
}

# Rate limiting configuration
configure_rate_limiting() {
    log_info "Configuring rate limiting..."
    
    case $DISTRO in
        ubuntu|debian|arch)
            # UFW rate limiting
            local ssh_port="${SSH_PORT:-$DEFAULT_SSH_PORT}"
            sudo ufw limit "$ssh_port/tcp" comment "SSH rate limit"
            
            # Additional rate limiting for web services
            if [[ "${INSTALL_NETDATA:-false}" == "true" ]]; then
                sudo ufw limit "$NETDATA_PORT/tcp" comment "Netdata rate limit"
            fi
            ;;
        fedora|opensuse)
            # Firewalld rate limiting using rich rules
            local ssh_port="${SSH_PORT:-$DEFAULT_SSH_PORT}"
            sudo firewall-cmd --permanent --add-rich-rule="rule service name=\"ssh\" limit value=\"10/m\" accept"
            sudo firewall-cmd --reload
            ;;
    esac
    
    log_success "Rate limiting configured"
}

# IP blocking and intrusion detection
configure_ip_blocking() {
    log_info "Configuring IP blocking capabilities..."
    
    # Create script for manual IP blocking
    sudo tee /usr/local/bin/block-ip > /dev/null <<'EOF'
#!/bin/bash
# Script to block IP addresses

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <IP_ADDRESS>"
    exit 1
fi

IP="$1"

# Validate IP address
if [[ ! $IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    echo "Error: Invalid IP address format"
    exit 1
fi

# Block IP based on firewall type
if command -v ufw &>/dev/null; then
    ufw deny from "$IP"
    echo "IP $IP blocked via UFW"
elif command -v firewall-cmd &>/dev/null; then
    firewall-cmd --permanent --add-rich-rule="rule family='ipv4' source address='$IP' reject"
    firewall-cmd --reload
    echo "IP $IP blocked via firewalld"
else
    echo "Error: No compatible firewall found"
    exit 1
fi

# Log the action
logger "IP $IP manually blocked by $(whoami)"
EOF

    sudo chmod +x /usr/local/bin/block-ip
    
    # Create script for unblocking IP addresses
    sudo tee /usr/local/bin/unblock-ip > /dev/null <<'EOF'
#!/bin/bash
# Script to unblock IP addresses

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <IP_ADDRESS>"
    exit 1
fi

IP="$1"

# Validate IP address
if [[ ! $IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    echo "Error: Invalid IP address format"
    exit 1
fi

# Unblock IP based on firewall type
if command -v ufw &>/dev/null; then
    ufw delete deny from "$IP"
    echo "IP $IP unblocked via UFW"
elif command -v firewall-cmd &>/dev/null; then
    firewall-cmd --permanent --remove-rich-rule="rule family='ipv4' source address='$IP' reject"
    firewall-cmd --reload
    echo "IP $IP unblocked via firewalld"
else
    echo "Error: No compatible firewall found"
    exit 1
fi

# Log the action
logger "IP $IP manually unblocked by $(whoami)"
EOF

    sudo chmod +x /usr/local/bin/unblock-ip
    
    log_success "IP blocking scripts created: /usr/local/bin/block-ip and /usr/local/bin/unblock-ip"
}

# Firewall monitoring and alerting
setup_firewall_monitoring() {
    log_info "Setting up firewall monitoring..."
    
    # Create log monitoring script
    sudo tee /usr/local/bin/firewall-monitor > /dev/null <<'EOF'
#!/bin/bash
# Firewall monitoring script

LOG_FILE="/var/log/firewall-monitor.log"
ALERT_THRESHOLD=10
CHECK_INTERVAL=300  # 5 minutes

monitor_ufw() {
    local denied_count=$(grep "UFW BLOCK" /var/log/ufw.log | grep "$(date '+%b %d')" | wc -l)
    
    if [[ $denied_count -gt $ALERT_THRESHOLD ]]; then
        echo "$(date): High number of blocked connections detected: $denied_count" >> "$LOG_FILE"
        logger "UFW: High number of blocked connections: $denied_count"
    fi
}

monitor_firewalld() {
    local denied_count=$(journalctl -u firewalld --since "5 minutes ago" | grep -c "REJECT")
    
    if [[ $denied_count -gt $ALERT_THRESHOLD ]]; then
        echo "$(date): High number of blocked connections detected: $denied_count" >> "$LOG_FILE"
        logger "Firewalld: High number of blocked connections: $denied_count"
    fi
}

# Main monitoring loop
while true; do
    if command -v ufw &>/dev/null && ufw status | grep -q "Status: active"; then
        monitor_ufw
    elif command -v firewall-cmd &>/dev/null && firewall-cmd --state &>/dev/null; then
        monitor_firewalld
    fi
    
    sleep $CHECK_INTERVAL
done
EOF

    sudo chmod +x /usr/local/bin/firewall-monitor
    
    # Create systemd service for firewall monitoring
    sudo tee /etc/systemd/system/firewall-monitor.service > /dev/null <<EOF
[Unit]
Description=Firewall Monitoring Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/firewall-monitor
Restart=always
RestartSec=10
User=root

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable firewall-monitor.service
    sudo systemctl start firewall-monitor.service
    
    log_success "Firewall monitoring service configured and started"
}

# Backup and restore firewall configuration
backup_firewall_config() {
    local backup_dir="/etc/firewall-backup"
    sudo mkdir -p "$backup_dir"
    
    log_info "Backing up firewall configuration..."
    
    case $DISTRO in
        ubuntu|debian|arch)
            if command -v ufw &>/dev/null; then
                sudo cp -r /etc/ufw "$backup_dir/ufw-$(date +%Y%m%d-%H%M%S)"
            fi
            ;;
        fedora|opensuse)
            if command -v firewall-cmd &>/dev/null; then
                sudo cp -r /etc/firewalld "$backup_dir/firewalld-$(date +%Y%m%d-%H%M%S)"
            fi
            ;;
    esac
    
    log_success "Firewall configuration backed up to $backup_dir"
}

# Main firewall configuration function
configure_firewall() {
    log_info "=== Firewall Configuration ==="
    
    # Backup existing configuration
    backup_firewall_config
    
    # Configure appropriate firewall based on distribution
    case $DISTRO in
        ubuntu|debian|arch)
            if configure_ufw; then
                add_ufw_rules
                configure_rate_limiting
                
                # Enable UFW
                sudo ufw --force enable
                log_success "UFW firewall enabled and configured"
                
                add_rollback_action "sudo ufw --force disable"
            else
                log_error "Failed to configure UFW"
                return 1
            fi
            ;;
        fedora|opensuse)
            if configure_firewalld; then
                add_firewalld_rules
                configure_rate_limiting
                
                log_success "Firewalld configured successfully"
                add_rollback_action "sudo systemctl stop firewalld && sudo systemctl disable firewalld"
            else
                log_error "Failed to configure firewalld"
                return 1
            fi
            ;;
        *)
            log_error "Unsupported distribution for firewall configuration: $DISTRO"
            return 1
            ;;
    esac
    
    # Additional security features
    configure_ip_blocking
    setup_firewall_monitoring
    
    # Show firewall status
    echo
    log_info "Firewall Status:"
    case $DISTRO in
        ubuntu|debian|arch)
            sudo ufw status verbose
            ;;
        fedora|opensuse)
            sudo firewall-cmd --list-all
            ;;
    esac
    
    log_success "Firewall configuration completed successfully"
}