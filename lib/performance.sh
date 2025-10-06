#!/bin/bash

# Performance monitoring and optimization functions

# System performance optimization
optimize_system_performance() {
    log_info "Optimizing system performance..."
    
    # Memory optimization for NAS workloads
    configure_memory_optimization
    
    # Optimize kernel parameters
    sudo tee -a /etc/sysctl.conf > /dev/null <<EOF

# NAS Setup Script - Performance Optimizations
# Network performance
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.ipv4.tcp_congestion_control = bbr

# File system performance
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
vm.swappiness = 10

# Security improvements
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
EOF

    # Apply kernel parameters
    sudo sysctl -p
    
    # Optimize I/O scheduler for SSDs/HDDs
    local disk_type=$(lsblk -d -o name,rota | awk 'NR>1 {if($2==0) print "ssd"; else print "hdd"; exit}')
    local root_disk=$(lsblk -no pkname $(findmnt -n -o source /) | head -n1)
    
    if [[ -n "$root_disk" ]] && [[ -w "/sys/block/$root_disk/queue/scheduler" ]]; then
        if [[ "$disk_type" == "ssd" ]]; then
            echo "mq-deadline" | sudo tee "/sys/block/$root_disk/queue/scheduler" > /dev/null
            log_info "Optimized I/O scheduler for SSD"
        else
            echo "bfq" | sudo tee "/sys/block/$root_disk/queue/scheduler" > /dev/null
            log_info "Optimized I/O scheduler for HDD"
        fi
    else
        log_warning "Could not determine or access root disk scheduler. Skipping I/O optimization."
    fi
    
    # Create performance monitoring script
    create_performance_monitor
    
    log_success "System performance optimized"
}

# Memory optimization for NAS workloads
configure_memory_optimization() {
    log_info "Configuring memory optimization for NAS workloads..."
    
    cat << EOF | sudo tee /etc/sysctl.d/99-nas-optimization.conf
# NAS Memory Optimization for better file caching
vm.swappiness=10
vm.vfs_cache_pressure=50
EOF
    
    # Apply immediately
    sudo sysctl -p /etc/sysctl.d/99-nas-optimization.conf
    
    # Add to rollback
    add_rollback_action "sudo rm -f /etc/sysctl.d/99-nas-optimization.conf && sudo sysctl -p"
    
    log_success "Memory optimization configured"
}

# Create performance monitoring script
create_performance_monitor() {
    sudo tee /usr/local/bin/nas-performance > /dev/null <<'EOF'
#!/bin/bash
# NAS Performance Monitor

REPORT_FILE="/var/log/nas-performance.log"
THRESHOLD_CPU=80
THRESHOLD_MEMORY=85
THRESHOLD_DISK=90

check_performance() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # CPU Usage
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    
    # Memory Usage
    local mem_usage=$(free | awk '/^Mem:/{printf "%.1f", $3/$2 * 100}')
    
    # Disk Usage
    local disk_usage=$(df / | awk 'NR==2 {print $5}' | cut -d'%' -f1)
    
    # Network connections
    local connections=$(ss -tuln | wc -l)
    
    # Load average
    local load_avg=$(uptime | awk '{print $(NF-2)}' | cut -d',' -f1)
    
    # Log performance data
    echo "[$timestamp] CPU: ${cpu_usage}% | Memory: ${mem_usage}% | Disk: ${disk_usage}% | Connections: $connections | Load: $load_avg" >> "$REPORT_FILE"
    
    # Check thresholds and alert
    if (( $(echo "$cpu_usage > $THRESHOLD_CPU" | bc -l) )); then
        logger "NAS Performance Alert: High CPU usage: ${cpu_usage}%"
    fi
    
    if (( $(echo "$mem_usage > $THRESHOLD_MEMORY" | bc -l) )); then
        logger "NAS Performance Alert: High memory usage: ${mem_usage}%"
    fi
    
    if [[ $disk_usage -gt $THRESHOLD_DISK ]]; then
        logger "NAS Performance Alert: High disk usage: ${disk_usage}%"
    fi
}

# Main execution
case "${1:-monitor}" in
    monitor)
        check_performance
        ;;
    report)
        echo "=== NAS Performance Report ==="
        tail -20 "$REPORT_FILE"
        ;;
    realtime)
        watch -n 5 '/usr/local/bin/nas-performance monitor'
        ;;
    *)
        echo "Usage: $0 {monitor|report|realtime}"
        exit 1
        ;;
esac
EOF

    sudo chmod +x /usr/local/bin/nas-performance
    
    # Create cron job for regular monitoring
    echo "*/5 * * * * /usr/local/bin/nas-performance monitor" | sudo crontab -
    
    log_success "Performance monitoring configured"
}

# Optimize Docker performance
optimize_docker_performance() {
    if [[ "${INSTALL_DOCKER:-false}" != "true" ]]; then
        return 0
    fi
    
    log_info "Optimizing Docker performance..."
    
    # Create optimized Docker daemon configuration
    sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    },
    "storage-driver": "overlay2",
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
}
EOF

    # Restart Docker to apply changes
    sudo systemctl restart docker
    
    # Docker cleanup script
    sudo tee /usr/local/bin/docker-cleanup > /dev/null <<'EOF'
#!/bin/bash
# Docker cleanup script

echo "Starting Docker cleanup..."

# Remove stopped containers
docker container prune -f

# Remove unused networks
docker network prune -f

# Remove unused volumes
docker volume prune -f

# Remove unused images
docker image prune -a -f

# Remove build cache
docker builder prune -a -f

echo "Docker cleanup completed"
EOF

    sudo chmod +x /usr/local/bin/docker-cleanup
    
    # Schedule weekly Docker cleanup
    echo "0 2 * * 0 /usr/local/bin/docker-cleanup" | sudo crontab -
    
    log_success "Docker performance optimized"
}

# Optimize Samba performance
optimize_samba_performance() {
    log_info "Optimizing Samba performance..."
    
    # Backup current configuration
    backup_config "$SAMBA_CONFIG"
    
    # Add performance optimizations to Samba config
    sudo tee -a "$SAMBA_CONFIG" > /dev/null <<EOF

# Performance optimizations
socket options = TCP_NODELAY IPTOS_LOWDELAY SO_RCVBUF=131072 SO_SNDBUF=131072
read raw = yes
write raw = yes
max xmit = 65535
min receivefile size = 16384
use sendfile = yes
aio read size = 16384
aio write size = 16384
aio write behind = true

# Caching optimizations
getwd cache = yes
stat cache = yes
strict locking = no
EOF

    # Restart Samba services
    case $DISTRO in
        ubuntu|debian|fedora|arch)
            sudo systemctl restart smbd nmbd
            ;;
        opensuse)
            sudo systemctl restart smb nmb
            ;;
    esac
    
    log_success "Samba performance optimized"
}

# System health check
perform_health_check() {
    log_info "Performing system health check..."
    
    local health_report="/tmp/nas_health_check.txt"
    
    {
        echo "=== NAS System Health Check Report ==="
        echo "Generated: $(date)"
        echo
        
        echo "=== System Information ==="
        uname -a
        uptime
        echo
        
        echo "=== Disk Usage ==="
        df -h
        echo
        
        echo "=== Memory Usage ==="
        free -h
        echo
        
        echo "=== Network Status ==="
        ip addr show | grep inet
        echo
        
        echo "=== Service Status ==="
        # Check services based on what was configured/installed
        local services_to_check=("ssh" "sshd")
        
        # Samba services
        if [[ "${INSTALL_SAMBA:-true}" == "true" ]]; then
            case $DISTRO in
                opensuse)
                    services_to_check+=("smb" "nmb")
                    ;;
                *)
                    services_to_check+=("smbd" "nmbd")
                    ;;
            esac
        fi
        
        # Docker
        if [[ "${INSTALL_DOCKER:-false}" == "true" ]]; then
            services_to_check+=("docker")
        fi
        
        # Netdata
        if [[ "${INSTALL_NETDATA:-false}" == "true" ]]; then
            services_to_check+=("netdata")
        fi
        
        for service in "${services_to_check[@]}"; do
            if systemctl is-active --quiet "$service" 2>/dev/null; then
                echo "✅ $service: Active"
            else
                echo "❌ $service: Inactive"
            fi
        done
        echo
        
        echo "=== Firewall Status ==="
        if command -v ufw &>/dev/null && ufw status | grep -q "Status: active"; then
            echo "✅ UFW: Active"
            ufw status numbered
        elif command -v firewall-cmd &>/dev/null && firewall-cmd --state &>/dev/null; then
            echo "✅ Firewalld: Active"
            firewall-cmd --list-all
        else
            echo "❌ Firewall: Not active"
        fi
        echo
        
        echo "=== Security Status ==="
        # Check Fail2ban if SSH was configured (which includes Fail2ban)
        if [[ "${CONFIGURE_SSH:-true}" == "true" ]]; then
            if systemctl is-active --quiet fail2ban; then
                echo "✅ Fail2ban: Active"
            else
                echo "❌ Fail2ban: Inactive"
            fi
        else
            echo "ℹ️ Fail2ban: Not configured"
        fi
        echo
        
        echo "=== Docker Status ==="
        if command -v docker &>/dev/null; then
            echo "✅ Docker: Installed"
            docker version --format 'Version: {{.Server.Version}}'
            echo "Containers: $(docker ps -q | wc -l) running, $(docker ps -aq | wc -l) total"
        else
            echo "ℹ️ Docker: Not installed"
        fi
        echo
        
        echo "=== Log Summary ==="
        echo "Recent errors in system logs:"
        journalctl --since "1 hour ago" --priority err --no-pager | tail -5
        
    } > "$health_report"
    
    cat "$health_report"
    
    # Save to permanent location
    sudo cp "$health_report" "/var/log/nas_health_$(date +%Y%m%d_%H%M%S).log"
    
    log_success "Health check completed. Report saved to /var/log/"
}

# Create maintenance script
create_maintenance_script() {
    sudo tee /usr/local/bin/nas-maintenance > /dev/null <<'EOF'
#!/bin/bash
# NAS Maintenance Script

LOG_FILE="/var/log/nas_maintenance.log"

log_maintenance() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

case "${1:-help}" in
    update)
        log_maintenance "Starting system update..."
        
        # Detect distribution and update
        if command -v apt-get &>/dev/null; then
            apt-get update && apt-get upgrade -y
        elif command -v dnf &>/dev/null; then
            dnf update -y
        elif command -v pacman &>/dev/null; then
            pacman -Syu --noconfirm
        elif command -v zypper &>/dev/null; then
            zypper refresh && zypper update -y
        fi
        
        log_maintenance "System update completed"
        ;;
        
    cleanup)
        log_maintenance "Starting system cleanup..."
        
        # Clean package cache
        if command -v apt-get &>/dev/null; then
            apt-get autoremove -y && apt-get autoclean
        elif command -v dnf &>/dev/null; then
            dnf autoremove -y && dnf clean all
        elif command -v pacman &>/dev/null; then
            pacman -Sc --noconfirm
        elif command -v zypper &>/dev/null; then
            zypper clean -a
        fi
        
        # Clean logs older than 30 days
        find /var/log -name "*.log" -mtime +30 -delete 2>/dev/null
        
        # Clean temporary files
        find /tmp -type f -mtime +7 -delete 2>/dev/null
        
        # Docker cleanup if installed
        if command -v docker &>/dev/null; then
            docker system prune -f
        fi
        
        log_maintenance "System cleanup completed"
        ;;
        
    backup-config)
        log_maintenance "Starting configuration backup..."
        
        BACKUP_DIR="/var/backups/nas-config-$(date +%Y%m%d)"
        mkdir -p "$BACKUP_DIR"
        
        # Backup important configurations
        cp -r /etc/samba "$BACKUP_DIR/" 2>/dev/null
        cp /etc/nas_setup.conf "$BACKUP_DIR/" 2>/dev/null
        cp -r /etc/ufw "$BACKUP_DIR/" 2>/dev/null
        cp -r /etc/firewalld "$BACKUP_DIR/" 2>/dev/null
        cp /etc/ssh/sshd_config "$BACKUP_DIR/" 2>/dev/null
        
        tar -czf "$BACKUP_DIR.tar.gz" -C "$(dirname "$BACKUP_DIR")" "$(basename "$BACKUP_DIR")"
        rm -rf "$BACKUP_DIR"
        
        log_maintenance "Configuration backup created: $BACKUP_DIR.tar.gz"
        ;;
        
    health-check)
        /usr/local/bin/nas-performance report
        ;;
        
    restart-services)
        log_maintenance "Restarting NAS services..."
        
        # Samba services based on distribution
        if [[ "$DISTRO" == "opensuse" ]]; then
            samba_services="smb nmb"
        else
            samba_services="smbd nmbd"
        fi
        
        for service in $samba_services docker netdata; do
            if systemctl is-enabled "$service" &>/dev/null; then
                systemctl restart "$service"
                log_maintenance "Restarted $service"
            fi
        done
        
        log_maintenance "Service restart completed"
        ;;
        
    full)
        log_maintenance "Starting full maintenance routine..."
        "$0" update
        "$0" cleanup
        "$0" backup-config
        "$0" restart-services
        "$0" health-check
        log_maintenance "Full maintenance completed"
        ;;
        
    help|*)
        echo "NAS Maintenance Script"
        echo "Usage: $0 {update|cleanup|backup-config|health-check|restart-services|full|help}"
        echo
        echo "Commands:"
        echo "  update          Update system packages"
        echo "  cleanup         Clean temporary files and caches"
        echo "  backup-config   Backup configuration files"
        echo "  health-check    Display system health report"
        echo "  restart-services Restart NAS services"
        echo "  full            Run complete maintenance routine"
        echo "  help            Show this help message"
        ;;
esac
EOF

    sudo chmod +x /usr/local/bin/nas-maintenance
    
    # Schedule weekly maintenance
    echo "0 3 * * 1 /usr/local/bin/nas-maintenance full" | sudo crontab -
    
    log_success "Maintenance script created and scheduled"
}

# Main performance optimization function
optimize_nas_performance() {
    log_info "=== Performance Optimization ==="
    
    optimize_system_performance
    optimize_docker_performance
    optimize_samba_performance
    create_maintenance_script
    
    log_success "NAS performance optimization completed"
}
