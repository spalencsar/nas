#!/bin/bash

check_internet_connection() {
    log_info "Checking internet connection..."
    if ping -c 1 google.com &> /dev/null; then
        log_info "Internet connection is active."
    else
        log_error "No internet connection. Please check your network settings."
        exit 1
    fi
}
