#!/bin/bash

install_docker() {
    log_info "Installing Docker..."

    case $DISTRO in
        ubuntu|debian)
            # Update package index and install prerequisites
            handle_error sudo apt-get update
            handle_error sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common

            # Add Docker's official GPG key
            handle_error curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

            # Add Docker's official APT repository
            handle_error echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

            # Update package index again
            handle_error sudo apt-get update

            # Install Docker CE and Compose plugin
            handle_error sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            ;;
        fedora)
            # Add Docker repository
            handle_error sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo

            # Install Docker CE
            handle_error sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            ;;
        arch)
            # Install Docker from official Arch repos (usually up-to-date)
            handle_error sudo pacman -S --noconfirm docker docker-compose
            ;;
        opensuse)
            # Add Docker repository
            handle_error sudo zypper addrepo https://download.docker.com/linux/opensuse/docker-ce.repo
            handle_error sudo zypper refresh

            # Install Docker CE
            handle_error sudo zypper install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            ;;
        *)
            log_error "Unsupported Linux distribution: $DISTRO"
            exit 1
            ;;
    esac

    # Add user to the docker group
    handle_error $SUDO usermod -aG docker "$NEW_USER"

    handle_error $SUDO systemctl enable docker
    handle_error $SUDO systemctl start docker

    # Configure Docker data directory and optimization
    if [[ "$DOCKER_DATA_DIR" != "$DEFAULT_DOCKER_DATA_DIR" ]]; then
        log_info "Configuring Docker data directory to $DOCKER_DATA_DIR..."
        handle_error $SUDO mkdir -p "$DOCKER_DATA_DIR"
    fi
    
    # Create optimized Docker daemon configuration
    configure_docker_daemon
    
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

# Configure optimized Docker daemon
configure_docker_daemon() {
    log_info "Configuring optimized Docker daemon..."
    
    $SUDO mkdir -p /etc/docker
    
    # Create optimized daemon.json
    cat << EOF | $SUDO tee /etc/docker/daemon.json
{
  "storage-driver": "overlay2",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "exec-opts": ["native.cgroupdriver=systemd"],
  "live-restore": true,
  "userland-proxy": false,
  "experimental": false,
  "metrics-addr": "0.0.0.0:9323",
  "default-ulimits": {
    "nofile": {
      "Hard": 64000,
      "Name": "nofile",
      "Soft": 64000
    }
  }
EOF
    
    # Add data-root if custom directory is specified
    if [[ "$DOCKER_DATA_DIR" != "$DEFAULT_DOCKER_DATA_DIR" ]]; then
        # Modify the daemon.json to include data-root
        $SUDO sed -i "s|{|{\n  \"data-root\": \"$DOCKER_DATA_DIR\",|" /etc/docker/daemon.json
    fi
    
    # Restart Docker to apply configuration
    handle_error $SUDO systemctl restart docker
    
    log_success "Docker daemon optimized"
}
