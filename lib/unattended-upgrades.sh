#!/bin/bash

# unattended-upgrades.sh - Configure automatic security updates (2025-enhanced)

configure_unattended_upgrades() {
    log_info "Configuring automatic security updates..."
    
    case $DISTRO in
        ubuntu|debian)
            # Preseed debconf to avoid interactive prompts and install non-interactively
            sudo debconf-set-selections <<DEBCONF
unattended-upgrades unattended-upgrades/enable_auto_updates boolean true
DEBCONF
            # Install non-interactively and avoid dpkg prompts by forcing noninteractive frontend
                # Use 'sudo env' to ensure environment vars are set for the root process
                handle_error sudo env DEBIAN_FRONTEND=noninteractive APT_LISTCHANGES_FRONTEND=none apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install -y unattended-upgrades apt-listchanges
            # Do not call dpkg-reconfigure interactively; we will write the config files directly
            
            # Configure unattended-upgrades for security only
            sudo tee /etc/apt/apt.conf.d/50unattended-upgrades > /dev/null <<EOF
Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}-security";
    "\${distro_id}ESMApps:\${distro_codename}-apps-security";
    "\${distro_id}ESM:\${distro_codename}-infra-security";
};

Unattended-Upgrade::Package-Blacklist {
};

Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";
EOF

            # Enable unattended-upgrades
            sudo tee /etc/apt/apt.conf.d/20auto-upgrades > /dev/null <<EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF
            ;;
        fedora)
            handle_error sudo dnf install -y dnf-automatic
            sudo systemctl enable --now dnf-automatic-install.timer
            
            # Configure for security updates only
            sudo sed -i 's/upgrade_type = default/upgrade_type = security/' /etc/dnf/automatic.conf
            sudo sed -i 's/apply_updates = no/apply_updates = yes/' /etc/dnf/automatic.conf
            ;;
        arch)
            log_info "Arch Linux: Automatic updates via pacman hooks recommended."
            # Create a systemd timer for security updates
            sudo tee /etc/systemd/system/pacman-security-update.service > /dev/null <<EOF
[Unit]
Description=Pacman Security Update

[Service]
Type=oneshot
ExecStart=/usr/bin/pacman -Syu --noconfirm
EOF

            sudo tee /etc/systemd/system/pacman-security-update.timer > /dev/null <<EOF
[Unit]
Description=Run security updates daily

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

            sudo systemctl enable pacman-security-update.timer
            ;;
        opensuse)
            handle_error sudo zypper install -y yast2-online-update-configuration
            # Configure for automatic security updates
            sudo sed -i 's/AUTOMATICALLY_UPDATE_PATCHES="no"/AUTOMATICALLY_UPDATE_PATCHES="yes"/' /etc/sysconfig/automatic_online_update
            sudo systemctl enable --now automatic-online-update.timer
            ;;
        *)
            log_error "Unsupported distribution: $DISTRO"
            exit 1
            ;;
    esac
    
    log_success "Automatic security updates configured."
}

# Logging functions if not available
if ! command -v log_info &>/dev/null; then
    log_info() { echo "[INFO] $1"; }
    log_success() { echo "[SUCCESS] $1"; }
    log_error() { echo "[ERROR] $1" >&2; }
fi