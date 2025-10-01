#!/bin/bash

check_internet_connection() {
    log_info "Checking internet connection (IPv4 and IPv6)..."
    
    local ipv4_hosts=("8.8.8.8" "1.1.1.1" "google.com")
    local ipv6_hosts=("2001:4860:4860::8888" "2606:4700:4700::1111" "google.com")
    local success=false
    
    # Test IPv4
    for host in "${ipv4_hosts[@]}"; do
        if ping -c 1 -W 5 "$host" &>/dev/null; then
            log_success "IPv4 internet connectivity confirmed (via $host)"
            success=true
            break
        fi
    done
    
    # Test IPv6 if IPv4 failed or to confirm dual-stack
    if [[ "$success" == false ]] || true; then  # Always test IPv6 for completeness
        for host in "${ipv6_hosts[@]}"; do
            if ping6 -c 1 -W 5 "$host" &>/dev/null; then
                log_success "IPv6 internet connectivity confirmed (via $host)"
                success=true
                break
            fi
        done
    fi
    
    if [[ "$success" == false ]]; then
        log_error "No internet connection detected (IPv4 or IPv6). Please check your network settings."
        exit 1
    fi
    
    log_info "Internet connection check completed."
}
