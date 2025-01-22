#!/bin/bash

configure_network() {
    log_info "Configuring network..."
    
    local interface=$(ip route | awk '/default/ {print $5}')
    local current_ip=$(ip addr show $interface | awk '/inet / {print $2}' | cut -d/ -f1)
    
    read -p "Enter static IP address [$current_ip]: " static_ip
    static_ip=${static_ip:-$current_ip}
    
    read -p "Enter gateway IP: " gateway_ip
    read -p "Enter DNS server IP: " dns_ip
    
    backup_config "/etc/netplan/01-netcfg.yaml"
    
    case $DISTRO in
        ubuntu|debian)
            cat <<EOL | sudo tee /etc/netplan/01-netcfg.yaml > /dev/null
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
        addresses: [$dns_ip]
EOL
            sudo netplan apply
            ;;
        fedora|arch|opensuse)
            cat <<EOL | sudo tee /etc/sysconfig/network-scripts/ifcfg-$interface > /dev/null
DEVICE=$interface
BOOTPROTO=none
ONBOOT=yes
IPADDR=$static_ip
PREFIX=24
GATEWAY=$gateway_ip
DNS1=$dns_ip
EOL
            sudo systemctl restart NetworkManager
            ;;
        *)
            log_error "Unsupported Linux distribution: $DISTRO"
            exit 1
            ;;
    esac
    
    log_info "Network configuration applied."
}

# ...existing code...
