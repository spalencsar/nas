#!/bin/bash

# Common functions and input validation

# Input validation functions
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        IFS='.' read -ra ADDR <<< "$ip"
        for i in "${ADDR[@]}"; do
            if [[ $i -gt 255 ]]; then
                return 1
            fi
        done
        return 0
    else
        return 1
    fi
}

validate_port() {
    local port=$1
    if [[ $port =~ ^[0-9]+$ ]] && [[ $port -ge 1 ]] && [[ $port -le 65535 ]]; then
        return 0
    else
        return 1
    fi
}

validate_username() {
    local username=$1
    if [[ $username =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
        return 0
    else
        return 1
    fi
}

validate_path() {
    local path=$1
    if [[ $path =~ ^/[a-zA-Z0-9_/.-]*$ ]]; then
        return 0
    else
        return 1
    fi
}

# Enhanced user input functions
ask_yes_no() {
    local prompt="$1"
    local default="${2:-n}"
    local response
    
    while true; do
        if [[ $default == "y" ]]; then
            read -p "$prompt [Y/n]: " response
            response=${response:-y}
        else
            read -p "$prompt [y/N]: " response
            response=${response:-n}
        fi
        
        case "${response,,}" in
            y|yes) return 0 ;;
            n|no) return 1 ;;
            *) log_warning "Please answer yes (y) or no (n)." ;;
        esac
    done
}

ask_input() {
    local prompt="$1"
    local default="$2"
    local validator="$3"
    local response
    
    while true; do
        if [[ -n "$default" ]]; then
            read -p "$prompt [$default]: " response
            response=${response:-$default}
        else
            read -p "$prompt: " response
        fi
        
        if [[ -z "$response" && -z "$default" ]]; then
            log_warning "Input cannot be empty."
            continue
        fi
        
        if [[ -n "$validator" ]]; then
            if $validator "$response"; then
                echo "$response"
                return 0
            else
                log_warning "Invalid input. Please try again."
                continue
            fi
        else
            echo "$response"
            return 0
        fi
    done
}

ask_password() {
    local prompt="$1"
    local password
    local password_confirm
    
    while true; do
        read -s -p "$prompt: " password
        echo
        
        if [[ ${#password} -lt 8 ]]; then
            log_warning "Password must be at least 8 characters long."
            continue
        fi
        
        read -s -p "Confirm password: " password_confirm
        echo
        
        if [[ "$password" == "$password_confirm" ]]; then
            echo "$password"
            return 0
        else
            log_warning "Passwords do not match. Please try again."
        fi
    done
}

# System checks
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root or with sudo privileges."
        exit 1
    fi
}

check_disk_space() {
    local required_gb=${1:-20}
    local available_gb=$(df / | tail -1 | awk '{printf "%.0f", $4/1024/1024}')
    
    if [[ $available_gb -lt $required_gb ]]; then
        log_error "Insufficient disk space. Required: ${required_gb}GB, Available: ${available_gb}GB"
        return 1
    else
        log_info "Disk space check passed. Available: ${available_gb}GB"
        return 0
    fi
}

check_ram() {
    local required_mb=${1:-2048}
    local available_mb=$(free -m | awk 'NR==2{printf "%.0f", $2}')
    
    if [[ $available_mb -lt $required_mb ]]; then
        log_warning "Low RAM detected. Required: ${required_mb}MB, Available: ${available_mb}MB"
        if ! ask_yes_no "Continue anyway?" "n"; then
            exit 1
        fi
    else
        log_info "RAM check passed. Available: ${available_mb}MB"
    fi
}

check_internet_enhanced() {
    local test_hosts=("8.8.8.8" "1.1.1.1" "google.com")
    local success=false
    
    log_info "Testing internet connectivity..."
    
    for host in "${test_hosts[@]}"; do
        if ping -c 1 -W 5 "$host" &>/dev/null; then
            log_success "Internet connectivity confirmed (via $host)"
            success=true
            break
        fi
    done
    
    if [[ "$success" == false ]]; then
        log_error "No internet connection detected. Please check your network settings."
        return 1
    fi
    
    return 0
}

# Dependency checks
check_command() {
    local cmd="$1"
    if command -v "$cmd" &>/dev/null; then
        log_debug "Command '$cmd' is available"
        return 0
    else
        log_error "Required command '$cmd' is not available"
        return 1
    fi
}

install_dependencies() {
    local dependencies=("curl" "wget" "git" "ufw" "htop" "tree")
    local missing_deps=()
    
    log_info "Checking system dependencies..."
    
    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_info "Installing missing dependencies: ${missing_deps[*]}"
        case $DISTRO in
            ubuntu|debian)
                sudo apt-get update
                sudo apt-get install -y "${missing_deps[@]}"
                ;;
            fedora)
                sudo dnf install -y "${missing_deps[@]}"
                ;;
            arch)
                sudo pacman -S --noconfirm "${missing_deps[@]}"
                ;;
            opensuse)
                sudo zypper install -y "${missing_deps[@]}"
                ;;
        esac
    else
        log_success "All dependencies are already installed"
    fi
}

# Service management
service_exists() {
    local service="$1"
    systemctl list-unit-files --type=service | grep -q "^${service}.service"
}

is_service_running() {
    local service="$1"
    systemctl is-active --quiet "$service"
}

start_and_enable_service() {
    local service="$1"
    
    if service_exists "$service"; then
        if systemctl enable "$service" && systemctl start "$service"; then
            log_success "Service '$service' started and enabled"
            add_rollback_action "systemctl stop $service && systemctl disable $service"
            return 0
        else
            log_error "Failed to start service '$service'"
            return 1
        fi
    else
        log_error "Service '$service' does not exist"
        return 1
    fi
}

# Configuration management
save_config() {
    local key="$1"
    local value="$2"
    
    if [[ -f "${CONFIG_FILE}" ]]; then
        if grep -q "^${key}=" "${CONFIG_FILE}"; then
            sed -i "s/^${key}=.*/${key}=${value}/" "${CONFIG_FILE}"
        else
            echo "${key}=${value}" >> "${CONFIG_FILE}"
        fi
    else
        echo "${key}=${value}" > "${CONFIG_FILE}"
    fi
    
    log_debug "Saved config: ${key}=${value}"
}

load_config() {
    if [[ -f "${CONFIG_FILE}" ]]; then
        source "${CONFIG_FILE}"
        log_debug "Configuration loaded from ${CONFIG_FILE}"
        return 0
    else
        log_debug "No configuration file found at ${CONFIG_FILE}"
        return 1
    fi
}

# Cleanup function
cleanup() {
    log_info "Performing cleanup..."
    
    # Remove temporary files
    rm -f /tmp/nas_setup_*
    
    # Clear package cache based on distro
    case $DISTRO in
        ubuntu|debian)
            sudo apt-get autoremove -y
            sudo apt-get autoclean
            ;;
        fedora)
            sudo dnf autoremove -y
            sudo dnf clean all
            ;;
        arch)
            sudo pacman -Sc --noconfirm
            ;;
        opensuse)
            sudo zypper clean -a
            ;;
    esac
    
    log_success "Cleanup completed"
}

# Performance monitoring
get_system_info() {
    log_info "System Information:"
    echo "  OS: $(lsb_release -d | cut -f2)"
    echo "  Kernel: $(uname -r)"
    echo "  CPU: $(lscpu | grep 'Model name' | cut -d: -f2 | xargs)"
    echo "  RAM: $(free -h | awk 'NR==2{printf "%s/%s", $3,$2}')"
    echo "  Disk: $(df -h / | awk 'NR==2{printf "%s/%s (%s used)", $3,$2,$5}')"
    echo "  Uptime: $(uptime -p)"
}

# Version and compatibility checks
check_ubuntu_version() {
    if [[ "$DISTRO" == "ubuntu" ]]; then
        local version_major=$(echo "$DISTRO_VERSION" | cut -d'.' -f1)
        if [[ $version_major -lt 20 ]]; then
            log_warning "Ubuntu version $DISTRO_VERSION is not officially supported. Minimum: 20.04"
            if ! ask_yes_no "Continue anyway?" "n"; then
                exit 1
            fi
        else
            log_success "Ubuntu version $DISTRO_VERSION is supported"
        fi
    fi
}

# Configure automatic updates
configure_automatic_updates() {
    log_info "Configuring automatic security updates..."
    
    case $DISTRO in
        ubuntu|debian)
            sudo apt-get install -y unattended-upgrades
            sudo dpkg-reconfigure -plow unattended-upgrades
            
            # Configure unattended-upgrades
            sudo tee /etc/apt/apt.conf.d/50unattended-upgrades > /dev/null <<EOF
Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}-security";
    "\${distro_id}ESMApps:\${distro_codename}-apps-security";
    "\${distro_id}ESM:\${distro_codename}-infra-security";
};

Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF
            ;;
        fedora)
            sudo dnf install -y dnf-automatic
            sudo systemctl enable --now dnf-automatic-install.timer
            ;;
        arch)
            log_info "Arch Linux uses rolling releases - manual updates recommended"
            ;;
        opensuse)
            sudo zypper install -y yast2-online-update-configuration
            ;;
    esac
    
    log_success "Automatic updates configured"
}

# Setup basic monitoring tools
setup_basic_monitoring() {
    log_info "Installing basic monitoring tools..."
    
    case $DISTRO in
        ubuntu|debian)
            sudo apt-get install -y htop iotop ncdu tree
            ;;
        fedora)
            sudo dnf install -y htop iotop ncdu tree
            ;;
        arch)
            sudo pacman -S --noconfirm htop iotop ncdu tree
            ;;
        opensuse)
            sudo zypper install -y htop iotop ncdu tree
            ;;
    esac
    
    log_success "Basic monitoring tools installed"
}

# Install additional components
install_additional_components() {
    log_info "Installing additional useful components..."
    
    local packages=("curl" "wget" "git" "vim" "nano" "screen" "tmux" "rsync" "zip" "unzip")
    
    case $DISTRO in
        ubuntu|debian)
            sudo apt-get install -y "${packages[@]}"
            ;;
        fedora)
            sudo dnf install -y "${packages[@]}"
            ;;
        arch)
            sudo pacman -S --noconfirm "${packages[@]}"
            ;;
        opensuse)
            sudo zypper install -y "${packages[@]}"
            ;;
    esac
    
    log_success "Additional components installed"
}
