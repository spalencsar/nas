#!/bin/bash

# Netdata installation and configuration script

install_netdata() {
    log_info "Installing Netdata..."

    # Install dependencies
    handle_error sudo apt-get update
    handle_error sudo apt-get install -y curl git

    # Install Netdata from GitHub
    handle_error bash <(curl -Ss https://my-netdata.io/kickstart.sh) --stable-channel --disable-telemetry

    handle_error sudo systemctl enable netdata
    handle_error sudo systemctl start netdata

    log_info "Netdata installation completed."
}
