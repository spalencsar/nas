#!/bin/bash

# unattended-upgrades.sh
# This script sets up unattended upgrades for various Linux distributions

set -e

DISTRO=$(lsb_release -is)

case "$DISTRO" in
    Ubuntu|Debian)
        echo "Setting up unattended upgrades for $DISTRO..."
        sudo apt-get update
        sudo apt-get install -y unattended-upgrades
        sudo dpkg-reconfigure --priority=low unattended-upgrades
        ;;
    Fedora)
        echo "Setting up unattended upgrades for Fedora..."
        sudo dnf install -y dnf-automatic
        sudo systemctl enable --now dnf-automatic-install.timer
        ;;
    "Arch Linux")
        echo "Setting up unattended upgrades for Arch Linux..."
        sudo pacman -Syu --noconfirm
        sudo systemctl enable --now paccache.timer
        ;;
    openSUSE)
        echo "Setting up unattended upgrades for openSUSE..."
        sudo zypper install -y yast2-online-update-configuration
        sudo yast2 online_update_configuration
        ;;
    *)
        echo "Unsupported distribution: $DISTRO"
        exit 1
        ;;
esac

echo "Unattended upgrades setup complete."