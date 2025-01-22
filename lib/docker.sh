#!/bin/bash

install_docker() {
    log_info "Installing Docker..."

    # Update package index and install prerequisites
    handle_error sudo apt-get update
    handle_error sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common

    # Add Docker's official GPG key
    handle_error curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

    # Add Docker's official APT repository
    handle_error sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

    # Update package index again
    handle_error sudo apt-get update

    # Install Docker CE
    handle_error sudo apt-get install -y docker-ce

    # Add user to the docker group
    handle_error sudo usermod -aG docker "$NEW_USER"

    case $DISTRO in
        ubuntu|debian)
            handle_error sudo apt-get install -y docker.io
            ;;
        fedora)
            handle_error sudo dnf install -y docker
            ;;
        arch)
            handle_error sudo pacman -S --noconfirm docker
            ;;
        opensuse)
            handle_error sudo zypper install -y docker
            ;;
        *)
            log_error "Unsupported Linux distribution: $DISTRO"
            exit 1
            ;;
    esac
    handle_error sudo systemctl enable docker
    handle_error sudo systemctl start docker

    # Configure Docker data directory
    if [[ "$DOCKER_DATA_DIR" != "$DEFAULT_DOCKER_DATA_DIR" ]]; then
        log_info "Configuring Docker data directory to $DOCKER_DATA_DIR..."
        handle_error sudo mkdir -p "$DOCKER_DATA_DIR"
        echo "{\"data-root\": \"$DOCKER_DATA_DIR\"}" | sudo tee /etc/docker/daemon.json > /dev/null
        handle_error sudo systemctl restart docker
    fi

    export DOCKER_CONTENT_TRUST=1

    log_info "Docker installed successfully."
    log_info "Instructions for installing Docker in rootless mode:"
    echo "1. Ensure required packages are installed: uidmap"
    echo "2. Run Docker rootless installation script: curl -fsSL https://get.docker.com/rootless | sh"
    echo "3. Set the following environment variables in your shell profile (e.g., ~/.bashrc):"
    echo "   export PATH=/usr/bin:\$PATH"
    echo "   export DOCKER_HOST=unix:///run/user/\$(id -u)/docker.sock"
    echo "4. Start and enable Docker service in user mode:"
    echo "   systemctl --user start docker"
    echo "   systemctl --user enable docker"
    echo "5. Enable linger for the user:"
    echo "   sudo loginctl enable-linger \$(whoami)"
}
