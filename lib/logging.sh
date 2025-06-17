#!/bin/bash

# Enhanced logging with timestamps and levels
log_with_timestamp() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local color_start=$3
    local color_end=${NC}
    
    echo -e "${color_start}[$timestamp] [$level] $message${color_end}"
    echo "[$timestamp] [$level] $message" >> "${LOG_FILE}" 2>/dev/null || true
}

log_info() {
    log_with_timestamp "INFO" "$1" "${GREEN}"
}

log_warning() {
    log_with_timestamp "WARNING" "$1" "${YELLOW}"
}

log_error() {
    log_with_timestamp "ERROR" "$1" "${RED}" >&2
}

log_debug() {
    if [[ "${DEBUG}" == "true" ]]; then
        log_with_timestamp "DEBUG" "$1" "${NC}"
    fi
}

log_success() {
    log_with_timestamp "SUCCESS" "$1" "${GREEN}"
}

# Progress tracking
show_progress() {
    local current=$1
    local total=$2
    local message=${3:-"Processing"}
    local percentage=$((current * 100 / total))
    local bar_length=50
    local filled_length=$((percentage * bar_length / 100))
    
    printf "\r${GREEN}[${message}] ["
    printf "%${filled_length}s" | tr ' ' '='
    printf "%$((bar_length - filled_length))s" | tr ' ' '-'
    printf "] %d%% (%d/%d)${NC}" $percentage $current $total
    
    if [[ $current -eq $total ]]; then
        echo ""
        log_success "$message completed"
    fi
}

backup_config() {
    local config_file=$1
    if [ -f "$config_file" ]; then
        local backup_file="${config_file}.$(date +%F-%T).bak"
        if sudo cp "$config_file" "$backup_file" 2>/dev/null; then
            log_info "Backup of $config_file created at $backup_file"
            return 0
        else
            log_error "Failed to create backup of $config_file"
            return 1
        fi
    else
        log_warning "Config file $config_file does not exist, skipping backup"
        return 0
    fi
}

# Rollback functionality
add_rollback_action() {
    local action="$1"
    echo "$action" >> "${ROLLBACK_FILE}"
    log_debug "Added rollback action: $action"
}

execute_rollback() {
    if [[ -f "${ROLLBACK_FILE}" ]]; then
        log_warning "Executing rollback actions..."
        while IFS= read -r action; do
            log_info "Rollback: $action"
            eval "$action" || log_error "Failed to execute rollback action: $action"
        done < <(tac "${ROLLBACK_FILE}")
        rm -f "${ROLLBACK_FILE}"
        log_info "Rollback completed"
    fi
}
