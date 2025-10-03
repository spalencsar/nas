#!/bin/bash

install_nfs() {
    log_info "Installing and configuring NFS..."
    
    case $DISTRO in
        ubuntu|debian)
            handle_error sudo apt-get install -y nfs-kernel-server
            ;;
        fedora)
            handle_error sudo dnf install -y nfs-utils
            ;;
        arch)
            handle_error sudo pacman -S --noconfirm nfs-utils
            ;;
        opensuse)
            handle_error sudo zypper install -y nfs-kernel-server
            ;;
        *)
            log_error "Unsupported Linux distribution: $DISTRO"
            exit 1
            ;;
    esac
    
    # Create NFS export directory
    local export_dir="${NFS_EXPORT_DIR:-/srv/nfs}"
    sudo mkdir -p "$export_dir"
    sudo chown nobody:nogroup "$export_dir"
    sudo chmod 755 "$export_dir"
    
    # Configure NFS exports (clean existing entries for this directory first)
    local exports_file="/etc/exports"
    backup_config "$exports_file"
    
    local export_line="$export_dir *(rw,sync,no_subtree_check,no_root_squash)"
    
    # Remove any existing entries for this export directory to avoid duplicates
    if grep -q "^$export_dir " "$exports_file" 2>/dev/null; then
        sudo sed -i "\#^$export_dir #d" "$exports_file"
        log_debug "Removed existing NFS export entries for $export_dir"
    fi
    
    # Add the new export entry
    echo "$export_line" | sudo tee -a "$exports_file" > /dev/null
    log_debug "Added NFS export: $export_line"
    
    # Export NFS shares
    handle_error sudo exportfs -a
    
    # Start and enable NFS services
    case $DISTRO in
        ubuntu|debian|opensuse)
            handle_error sudo systemctl enable nfs-kernel-server
            handle_error sudo systemctl start nfs-kernel-server
            ;;
        fedora|arch)
            handle_error sudo systemctl enable nfs-server
            handle_error sudo systemctl start nfs-server
            ;;
    esac
    
    # Open firewall for NFS
    if command -v ufw &>/dev/null; then
        sudo ufw allow 2049/tcp comment "NFS"
        sudo ufw allow 111/tcp comment "NFS Portmapper"
        sudo ufw allow 111/udp comment "NFS Portmapper"
    elif command -v firewall-cmd &>/dev/null; then
        sudo firewall-cmd --permanent --add-service=nfs
        sudo firewall-cmd --permanent --add-service=rpc-bind
        sudo firewall-cmd --permanent --add-service=mountd
        sudo firewall-cmd --reload
    fi
    
    log_info "NFS installation and configuration completed. Export directory: $export_dir"
}
