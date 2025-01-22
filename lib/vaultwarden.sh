#!/bin/bash

# Vaultwarden installation and configuration script

install_vaultwarden() {
    log_info "Installing Vaultwarden..."

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        echo "Unsupported OS"
        exit 1
    fi

    case $OS in
        ubuntu|debian)
            sudo apt update
            sudo apt install -y docker.io docker-compose
            ;;
        fedora)
            sudo dnf install -y docker docker-compose
            ;;
        arch)
            sudo pacman -Syu --noconfirm docker docker-compose
            ;;
        opensuse)
            sudo zypper install -y docker docker-compose
            ;;
        *)
            echo "Unsupported OS"
            exit 1
            ;;
    esac

    sudo systemctl start docker
    sudo systemctl enable docker

    mkdir -p ~/vaultwarden
    cd ~/vaultwarden

    cat <<EOF > docker-compose.yml
version: '3'
services:
  vaultwarden:
    image: vaultwarden/server:latest
    container_name: vaultwarden
    restart: unless-stopped
    volumes:
      - ./vw-data:/data
    ports:
      - 80:80
EOF

    # Pull the Vaultwarden image
    handle_error sudo docker pull vaultwarden/server:latest

    # Create the Vaultwarden container
    handle_error sudo docker run -d --name vaultwarden -v /vw-data/:/data/ -p 80:80 --restart always vaultwarden/server:latest

    log_info "Vaultwarden installation completed."
}

install_vaultwarden