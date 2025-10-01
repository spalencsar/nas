#!/bin/bash

# Vaultwarden installation and configuration script (2025-enhanced)

install_vaultwarden() {
    log_info "Installing Vaultwarden..."
    
    # Docker muss installiert sein
    if ! command -v docker &>/dev/null; then
        log_error "Docker ist nicht installiert. Bitte Docker zuerst installieren."
        exit 1
    fi
    
    # Erstelle Verzeichnis für Vaultwarden
    local vault_dir="${VAULTWARDEN_DATA_DIR:-/opt/vaultwarden}"
    sudo mkdir -p "$vault_dir"
    sudo chown "$USER:$USER" "$vault_dir"
    
    # Erstelle docker-compose.yml
    cat <<EOF | sudo tee "$vault_dir/docker-compose.yml" > /dev/null
version: '3.8'
services:
  vaultwarden:
    image: vaultwarden/server:latest
    container_name: vaultwarden
    restart: unless-stopped
    volumes:
      - ./vw-data:/data
    ports:
      - "8080:80"  # HTTP on 8080
    environment:
      - WEBSOCKET_ENABLED=true
      - SIGNUPS_ALLOWED=false  # Disable signups by default for security
      - ADMIN_TOKEN=  # Set admin token later
EOF

    cd "$vault_dir"
    
    # Pull the latest image
    handle_error sudo docker pull vaultwarden/server:latest
    
    # Start Vaultwarden
    handle_error sudo docker-compose up -d
    
    # Warte kurz und prüfe Status
    sleep 5
    if sudo docker ps | grep -q vaultwarden; then
        log_success "Vaultwarden wurde erfolgreich installiert und läuft auf Port 8080."
        log_info "Um Admin-Zugang zu aktivieren, setze ADMIN_TOKEN in der docker-compose.yml und starte neu."
        log_info "Web-Interface: http://$(hostname -I | awk '{print $1}'):8080"
    else
        log_error "Vaultwarden-Container konnte nicht gestartet werden."
        return 1
    fi
}

# Logging functions if not available
if ! command -v log_info &>/dev/null; then
    log_info() { echo "[INFO] $1"; }
    log_success() { echo "[SUCCESS] $1"; }
    log_error() { echo "[ERROR] $1" >&2; }
fi

# Main execution
install_vaultwarden