#!/bin/bash

# Provide a safe default for SUDO in case the environment or caller
# expects a SUDO variable. Some systems or callers may unset this and
# scripts using `${SUDO}` should not fail with unbound variable under
# `set -u`.
SUDO=${SUDO:-sudo}

# Ensure DOCKER_DATA_DIR has a sensible default to avoid unbound variable
# errors when running under `set -u` and when no custom value is provided
# by the configuration file. Use DEFAULT_DOCKER_DATA_DIR from defaults.sh.
DOCKER_DATA_DIR=${DOCKER_DATA_DIR:-${DEFAULT_DOCKER_DATA_DIR:-/var/lib/docker}}

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

    # Determine which user to add to the docker group.
    # Prefer ADMIN_USER if configured, then NEW_USER. If neither exists,
    # try to auto-detect a suitable non-root sudo-capable user. Only create
    # a new user if CREATE_NEW_USER_IF_MISSING=true.
    TARGET_USER=""

    if [[ -n "${ADMIN_USER:-}" ]] && id -u "${ADMIN_USER}" >/dev/null 2>&1; then
        TARGET_USER="${ADMIN_USER}"
        log_debug "Using ADMIN_USER='$TARGET_USER' for docker group"
    elif [[ -n "${NEW_USER:-}" ]] && id -u "${NEW_USER}" >/dev/null 2>&1; then
        TARGET_USER="${NEW_USER}"
        log_debug "Using NEW_USER='$TARGET_USER' for docker group"
    else
        # Gather human non-system users (UID >= 1000) with a normal shell
        mapfile -t _candidates < <(awk -F: '($3>=1000 && $7!="/usr/sbin/nologin" && $7!="/bin/false"){print $1}' /etc/passwd | sort)

        if [[ ${#_candidates[@]} -eq 1 ]]; then
            TARGET_USER="${_candidates[0]}"
            log_info "Auto-detected user '$TARGET_USER' to add to docker group"
        elif [[ ${#_candidates[@]} -gt 1 ]]; then
            log_info "Multiple candidate user accounts found. Please choose which to add to the docker group:"
            local i=0
            for u in "${_candidates[@]}"; do
                i=$((i+1))
                if id -nG "$u" 2>/dev/null | grep -qw sudo; then
                    echo "  $i) $u (sudo)"
                else
                    echo "  $i) $u"
                fi
            done
            echo "  0) None / create new user"

            # Ask until valid selection
            local sel
            while true; do
                sel=$(ask_input "Select user number to add to docker group (0 to skip)" "1" )
                if [[ "$sel" =~ ^[0-9]+$ ]] && [[ "$sel" -ge 0 ]] && [[ "$sel" -le ${#_candidates[@]} ]]; then
                    break
                fi
                log_warning "Please enter a number between 0 and ${#_candidates[@]}"
            done

            if [[ "$sel" -eq 0 ]]; then
                TARGET_USER=""
            else
                TARGET_USER="${_candidates[$((sel-1))]}"
            fi
        else
            TARGET_USER=""
        fi
    fi

    if [[ -n "$TARGET_USER" ]]; then
        handle_error sudo usermod -aG docker "$TARGET_USER"
    else
        log_warning "No suitable non-root user found to add to docker group."
        if [[ "${CREATE_NEW_USER_IF_MISSING:-false}" == "true" ]]; then
            local create_user
            create_user="${NEW_USER:-nasadmin}"
            log_info "Creating user '$create_user' and adding to docker group..."
            handle_error sudo useradd -m -s /bin/bash "$create_user"
            handle_error sudo usermod -aG docker "$create_user"
        fi
    fi

    handle_error sudo systemctl enable docker
    handle_error sudo systemctl start docker

    # Configure Docker data directory and optimization
    if [[ "$DOCKER_DATA_DIR" != "$DEFAULT_DOCKER_DATA_DIR" ]]; then
        log_info "Configuring Docker data directory to $DOCKER_DATA_DIR..."
        handle_error sudo mkdir -p "$DOCKER_DATA_DIR"
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
    
    sudo mkdir -p /etc/docker
    
        # Create optimized daemon.json with optional data-root
        local _data_root_line=""
        if [[ "$DOCKER_DATA_DIR" != "${DEFAULT_DOCKER_DATA_DIR}" ]]; then
                _data_root_line="  \"data-root\": \"${DOCKER_DATA_DIR}\","
                log_debug "Including data-root in daemon.json: ${DOCKER_DATA_DIR}"
        fi

        sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
${_data_root_line}
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
            "Name": "nofile",
            "Soft": 64000,
            "Hard": 64000
        }
    }
}
EOF
    
    # Restart Docker to apply configuration
    handle_error sudo systemctl restart docker
    
    log_success "Docker daemon optimized"
}
