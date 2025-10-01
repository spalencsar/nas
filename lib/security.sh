#!/bin/bash

# Security configuration script (2025-enhanced)

secure_shared_memory() {
    log_info "Securing shared memory..."
    handle_error sudo cp /etc/fstab /etc/fstab.bak
    echo "tmpfs /run/shm tmpfs defaults,noexec,nosuid 0 0" | sudo tee -a /etc/fstab
    handle_error sudo mount -o remount /run/shm
    log_success "Shared memory secured."
}

install_fail2ban() {
    log_info "Installing and configuring Fail2Ban..."
    case $DISTRO in
        ubuntu|debian)
            handle_error sudo apt-get update
            handle_error sudo apt-get install -y fail2ban
            ;;
        fedora)
            handle_error sudo dnf install -y fail2ban
            ;;
        arch)
            handle_error sudo pacman -S --noconfirm fail2ban
            ;;
        opensuse)
            handle_error sudo zypper install -y fail2ban
            ;;
        *)
            log_error "Unsupported Linux distribution: $DISTRO"
            exit 1
            ;;
    esac
    
    # Backup default config
    backup_config /etc/fail2ban/jail.local
    
    # Configure Fail2Ban for SSH and other services
    sudo tee /etc/fail2ban/jail.local > /dev/null <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = ${DEFAULT_SSH_PORT:-22}
logpath = %(sshd_log)s

[dropbear]
enabled = false

[selinux-ssh]
enabled = false

[nginx-http-auth]
enabled = false

[nginx-noscript]
enabled = false

[nginx-badbots]
enabled = false

[nginx-noproxy]
enabled = false

[nginx-req-limit]
enabled = false

[nginx-botsearch]
enabled = false

[phpmyadmin-syslog]
enabled = false

[roundcube-auth]
enabled = false

[openhab-auth]
enabled = false

[squid]
enabled = false

[nginx-ddos]
enabled = false

[recidive]
enabled = true
EOF

    handle_error sudo systemctl enable fail2ban
    handle_error sudo systemctl start fail2ban
    log_success "Fail2Ban installation and configuration completed."
}

# Harden SSH configuration
harden_ssh() {
    log_info "Hardening SSH configuration..."
    
    local ssh_config="/etc/ssh/sshd_config"
    backup_config "$ssh_config"
    
    # Apply security hardening
    sudo sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' "$ssh_config"
    sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' "$ssh_config"
    sudo sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' "$ssh_config"
    sudo sed -i 's/#AuthorizedKeysFile/AuthorizedKeysFile/' "$ssh_config"
    sudo sed -i 's/#PermitEmptyPasswords no/PermitEmptyPasswords no/' "$ssh_config"
    sudo sed -i 's/#ChallengeResponseAuthentication no/ChallengeResponseAuthentication no/' "$ssh_config"
    sudo sed -i 's/#UsePAM yes/UsePAM yes/' "$ssh_config"
    sudo sed -i 's/#X11Forwarding yes/X11Forwarding no/' "$ssh_config"
    sudo sed -i 's/#ClientAliveInterval 0/ClientAliveInterval 300/' "$ssh_config"
    sudo sed -i 's/#ClientAliveCountMax 3/ClientAliveCountMax 2/' "$ssh_config"
    sudo sed -i 's/#MaxAuthTries 6/MaxAuthTries 3/' "$ssh_config"
    sudo sed -i 's/#LoginGraceTime 2m/LoginGraceTime 60/' "$ssh_config"
    sudo sed -i 's/#Protocol 2/Protocol 2/' "$ssh_config"
    
    # Test SSH config
    if sudo sshd -t; then
        sudo systemctl restart sshd
        log_success "SSH hardened successfully."
    else
        log_error "SSH configuration invalid. Restoring backup."
        sudo cp "${ssh_config}.bak" "$ssh_config"
        sudo systemctl restart sshd
    fi
}

# Configure AppArmor/SELinux
configure_mandatory_access_control() {
    log_info "Configuring Mandatory Access Control..."
    
    case $DISTRO in
        ubuntu|debian)
            # AppArmor
            if command -v apparmor_status &>/dev/null; then
                sudo systemctl enable apparmor
                sudo systemctl start apparmor
                log_success "AppArmor enabled."
            else
                log_warning "AppArmor not available."
            fi
            ;;
        fedora|opensuse)
            # SELinux
            if command -v setenforce &>/dev/null; then
                sudo setenforce 1
                sudo sed -i 's/SELINUX=permissive/SELINUX=enforcing/' /etc/selinux/config
                log_success "SELinux enabled in enforcing mode."
            else
                log_warning "SELinux not available."
            fi
            ;;
        arch)
            # AppArmor on Arch (optional)
            if pacman -Q apparmor &>/dev/null; then
                sudo systemctl enable apparmor
                sudo systemctl start apparmor
                log_success "AppArmor enabled on Arch."
            else
                log_info "AppArmor not installed on Arch. Consider installing for better security."
            fi
            ;;
        *)
            log_warning "Mandatory Access Control not configured for $DISTRO."
            ;;
    esac
}

# Install and configure auditd
install_auditd() {
    log_info "Installing and configuring auditd..."
    
    case $DISTRO in
        ubuntu|debian)
            handle_error sudo apt-get install -y auditd audispd-plugins
            ;;
        fedora)
            handle_error sudo dnf install -y audit audit-libs
            ;;
        arch)
            handle_error sudo pacman -S --noconfirm audit
            ;;
        opensuse)
            handle_error sudo zypper install -y audit
            ;;
        *)
            log_error "auditd not supported on $DISTRO"
            return 1
            ;;
    esac
    
    # Configure audit rules
    sudo tee -a /etc/audit/rules.d/audit.rules > /dev/null <<EOF
# NAS Security Audit Rules
-w /etc/passwd -p wa -k passwd_changes
-w /etc/shadow -p wa -k shadow_changes
-w /etc/group -p wa -k group_changes
-w /etc/sudoers -p wa -k sudoers_changes
-w /var/log/auth.log -p wa -k auth_logs
-w /var/log/sudo.log -p wa -k sudo_logs
-a always,exit -F arch=b64 -S execve -F key=executed_commands
EOF

    handle_error sudo systemctl enable auditd
    handle_error sudo systemctl start auditd
    log_success "auditd installed and configured."
}

# Disable unnecessary services
disable_unnecessary_services() {
    log_info "Disabling unnecessary services..."
    
    local services_to_disable=("cups" "bluetooth" "avahi-daemon" "ModemManager")
    
    for service in "${services_to_disable[@]}"; do
        if systemctl list-unit-files --type=service | grep -q "^${service}.service"; then
            sudo systemctl disable "$service" 2>/dev/null || true
            sudo systemctl stop "$service" 2>/dev/null || true
            log_info "Disabled service: $service"
        fi
    done
    
    log_success "Unnecessary services disabled."
}

# Configure automatic security updates
configure_security_updates() {
    log_info "Configuring automatic security updates..."
    
    case $DISTRO in
        ubuntu|debian)
            handle_error sudo apt-get install -y unattended-upgrades
            sudo dpkg-reconfigure -plow unattended-upgrades
            ;;
        fedora)
            handle_error sudo dnf install -y dnf-automatic
            sudo systemctl enable --now dnf-automatic-install.timer
            ;;
        arch)
            log_info "Arch Linux: Security updates via pacman -Syu recommended"
            ;;
        opensuse)
            handle_error sudo zypper install -y yast2-online-update-configuration
            ;;
    esac
    
    log_success "Automatic security updates configured."
}

# Generate SSH keys for admin user
generate_ssh_keys() {
    local user="${ADMIN_USER:-$NEW_USER}"
    local ssh_dir="/home/$user/.ssh"
    
    if [[ -z "$user" ]]; then
        log_warning "No admin user defined, skipping SSH key generation."
        return 0
    fi
    
    log_info "Generating SSH keys for user $user..."
    
    sudo mkdir -p "$ssh_dir"
    sudo chown "$user:$user" "$ssh_dir"
    sudo chmod 700 "$ssh_dir"
    
    # Generate Ed25519 key (more secure than RSA)
    sudo -u "$user" ssh-keygen -t ed25519 -f "$ssh_dir/id_ed25519" -N "" -C "NAS-$user-$(date +%Y%m%d)"
    
    log_success "SSH keys generated. Public key: $ssh_dir/id_ed25519.pub"
    log_info "Add the public key to authorized_keys for passwordless login."
}

# Main security configuration function
configure_security() {
    log_info "=== Security Configuration ==="
    
    secure_shared_memory
    install_fail2ban
    harden_ssh
    configure_mandatory_access_control
    install_auditd
    disable_unnecessary_services
    configure_security_updates
    generate_ssh_keys
    
    log_success "Security configuration completed."
}
