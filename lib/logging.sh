#!/bin/bash

log_info() {
    echo -e "${GREEN}[INFO] $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

log_error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

backup_config() {
    local config_file=$1
    if [ -f "$config_file" ]; then
        local backup_file="${config_file}.$(date +%F-%T).bak"
        handle_error sudo cp "$config_file" "$backup_file"
        log_info "Backup of $config_file created at $backup_file"
    fi
}
