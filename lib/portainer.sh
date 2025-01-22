#!/bin/bash

# portainer.sh - Script to install Portainer on various Linux distributions

# Function to install Portainer on Ubuntu
install_portainer_ubuntu() {
    sudo apt-get update
    sudo apt-get install -y docker.io
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo docker volume create portainer_data
    sudo docker run -d -p 9000:9000 --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce
}

# Function to install Portainer on Debian
install_portainer_debian() {
    sudo apt-get update
    sudo apt-get install -y docker.io
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo docker volume create portainer_data
    sudo docker run -d -p 9000:9000 --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce
}

# Function to install Portainer on Fedora
install_portainer_fedora() {
    sudo dnf -y update
    sudo dnf -y install docker
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo docker volume create portainer_data
    sudo docker run -d -p 9000:9000 --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce
}

# Function to install Portainer on Arch Linux
install_portainer_arch() {
    sudo pacman -Syu --noconfirm
    sudo pacman -S --noconfirm docker
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo docker volume create portainer_data
    sudo docker run -d -p 9000:9000 --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce
}

# Function to install Portainer on openSUSE
install_portainer_opensuse() {
    sudo zypper refresh
    sudo zypper install -y docker
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo docker volume create portainer_data
    sudo docker run -d -p 9000:9000 --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce
}

# Main script logic to detect the distribution and call the appropriate function
if [ -f /etc/os-release ]; then
    . /etc/os-release
    case "$ID" in
        ubuntu)
            install_portainer_ubuntu
            ;;
        debian)
            install_portainer_debian
            ;;
        fedora)
            install_portainer_fedora
            ;;
        arch)
            install_portainer_arch
            ;;
        opensuse)
            install_portainer_opensuse
            ;;
        *)
            echo "Unsupported distribution: $ID"
            exit 1
            ;;
    esac
else
    echo "Cannot detect the operating system."
    exit 1
fi