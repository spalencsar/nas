# Distribution Detection Functions
# This file contains functions for detecting Linux distributions and versions

# Normalize version strings for consistent comparison
normalize_version() {
    local version="$1"

    # Handle common version formats - keep original format but ensure x.y.z structure
    if [[ $version =~ ^([0-9]+)(\.([0-9]+))?(\.([0-9]+))?.* ]]; then
        # Standard x.y.z format - ensure all parts exist
        local major="${BASH_REMATCH[1]}"
        local minor="${BASH_REMATCH[3]:-0}"
        local patch="${BASH_REMATCH[5]:-0}"
        echo "${major}.${minor}.${patch}"
    elif [[ $version =~ ^([0-9]+)\.([0-9]+)[[:space:]]*\((.*)\)$ ]]; then
        # Debian style: "12 (bookworm)" -> "12.0.0"
        echo "${BASH_REMATCH[1]}.0.0"
    elif [[ $version == "rolling" ]] || [[ $version == "unstable" ]]; then
        # Rolling releases
        echo "9999.0.0"  # High version number for rolling releases
    else
        # Fallback: try to extract first number
        local num_version=$(echo "$version" | grep -oP '\d+(\.\d+)*' | head -1)
        if [[ -n "$num_version" ]]; then
            echo "$num_version"
        else
            echo "0.0.0"
        fi
    fi
}

# Version comparison function using bc for reliability
version_compare() {
    local version1="$1"
    local operator="$2"
    local version2="$3"

    # Convert versions to comparable format
    local v1_num=$(echo "$version1" | tr '.' ' ' | awk '{printf "%d%02d%02d", $1, $2, $3}')
    local v2_num=$(echo "$version2" | tr '.' ' ' | awk '{printf "%d%02d%02d", $1, $2, $3}')

    case $operator in
        ">=") [[ $v1_num -ge $v2_num ]] ;;
        ">")  [[ $v1_num -gt $v2_num ]] ;;
        "<=") [[ $v1_num -le $v2_num ]] ;;
        "<")  [[ $v1_num -lt $v2_num ]] ;;
        "="|"==") [[ $v1_num -eq $v2_num ]] ;;
        "!=") [[ $v1_num -ne $v2_num ]] ;;
        *) return 1 ;;
    esac
}

# Validate minimum version requirements
validate_minimum_version() {
    local distro="$1"
    local version="$2"

    case $distro in
        ubuntu)
            if ! version_compare "$version" ">=" "24.04.0"; then
                log_warning "Ubuntu version $version is below minimum requirement (24.04)"
                log_warning "Some features may not work correctly"
            fi
            ;;
        debian)
            if ! version_compare "$version" ">=" "12.0.0"; then
                log_warning "Debian version $version is below minimum requirement (12)"
                log_warning "Some features may not work correctly"
            fi
            ;;
        fedora)
            if ! version_compare "$version" ">=" "41.0.0"; then
                log_warning "Fedora version $version is below minimum requirement (41)"
                log_warning "Some features may not work correctly"
            fi
            ;;
        opensuse)
            if ! version_compare "$version" ">=" "15.6.0"; then
                log_warning "openSUSE version $version is below minimum requirement (15.6)"
                log_warning "Some features may not work correctly"
            fi
            ;;
        arch)
            # Arch is rolling, always considered compatible
            log_debug "Arch Linux rolling release detected - fully supported"
            ;;
    esac
}

# Detect container environments that might affect behavior
detect_container_environment() {
    local container_type=""

    # Docker container detection
    if [[ -f /.dockerenv ]] || grep -q docker /proc/1/cgroup 2>/dev/null; then
        container_type="docker"
        log_debug "Running inside Docker container"
    fi

    # Podman container detection
    if [[ -f /.podmanenv ]] || grep -q podman /proc/1/cgroup 2>/dev/null; then
        container_type="podman"
        log_debug "Running inside Podman container"
    fi

    # LXC/LXD detection
    if [[ -f /proc/1/environ ]] && grep -q lxc /proc/1/environ 2>/dev/null; then
        container_type="lxc"
        log_debug "Running inside LXC container"
    fi

    # WSL detection
    if grep -q Microsoft /proc/version 2>/dev/null || [[ -f /proc/version ]] && grep -q WSL /proc/version; then
        container_type="wsl"
        log_debug "Running inside Windows Subsystem for Linux (WSL)"
    fi

    if [[ -n "$container_type" ]]; then
        log_info "Container environment detected: $container_type"
        export CONTAINER_TYPE="$container_type"

        # Adjust behavior for containers
        case $container_type in
            docker|podman|lxc)
                log_warning "Running in container - some system-level features may be limited"
                ;;
            wsl)
                log_warning "Running in WSL - Windows integration features may be limited"
                ;;
        esac
    fi
}