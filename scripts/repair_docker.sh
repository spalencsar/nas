#!/usr/bin/env bash
set -euo pipefail

# Repair helper for Docker daemon config and service
# - Validates /etc/docker/daemon.json (using jq or python3)
# - Backs up invalid config and writes a minimal valid config
# - Restarts docker and collects logs
# - Attempts to run configure_docker_daemon from the repo if available

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOGFILE="/tmp/repair_docker_$(date +%s).log"

echo "Repair started at $(date)" > "$LOGFILE"

# Load repo helpers if present
if [[ -f "$SCRIPT_DIR/config/defaults.sh" ]]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/config/defaults.sh" || true
fi
if [[ -f "$SCRIPT_DIR/lib/common.sh" ]]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/lib/common.sh" || true
fi
if [[ -f "$SCRIPT_DIR/lib/docker.sh" ]]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/lib/docker.sh" || true
fi

validate_json() {
    local file="$1"
    if command -v jq >/dev/null 2>&1; then
        jq empty "$file" >/dev/null 2>&1
        return $?
    elif command -v python3 >/dev/null 2>&1; then
        python3 -m json.tool "$file" >/dev/null 2>&1
        return $?
    else
        # conservative: try to detect a trailing EOF or obvious truncation
        if [[ -s "$file" ]]; then
            return 0
        else
            return 1
        fi
    fi
}

echo "Using repo at: $SCRIPT_DIR" >> "$LOGFILE"

if [[ -f /etc/docker/daemon.json ]]; then
    echo "/etc/docker/daemon.json exists - validating..." | tee -a "$LOGFILE"
    if validate_json /etc/docker/daemon.json; then
        echo "daemon.json is valid" | tee -a "$LOGFILE"
    else
        echo "daemon.json is INVALID - backing up and replacing with minimal config" | tee -a "$LOGFILE"
        sudo mkdir -p /tmp/docker-repair-backups
        sudo mv /etc/docker/daemon.json "/tmp/docker-repair-backups/daemon.json.broken.$(date +%s)"
        sudo tee /etc/docker/daemon.json > /dev/null <<'EOF'
{
  "storage-driver": "overlay2"
}
EOF
        echo "Wrote minimal /etc/docker/daemon.json" | tee -a "$LOGFILE"
    fi
else
    echo "/etc/docker/daemon.json does not exist - creating minimal config" | tee -a "$LOGFILE"
    sudo mkdir -p /etc/docker
    sudo tee /etc/docker/daemon.json > /dev/null <<'EOF'
{
  "storage-driver": "overlay2"
}
EOF
fi

echo "Reloading systemd daemon and restarting docker" | tee -a "$LOGFILE"
sudo systemctl daemon-reload || true
if sudo systemctl restart docker; then
    echo "Docker restarted successfully" | tee -a "$LOGFILE"
    sudo journalctl -u docker --no-pager -n 200 >> "$LOGFILE" 2>&1 || true
else
    echo "Docker failed to restart - collecting logs" | tee -a "$LOGFILE"
    sudo journalctl -u docker --no-pager -n 500 >> "$LOGFILE" 2>&1 || true

    # Try to run configure_docker_daemon from this repo if available
    if declare -F configure_docker_daemon >/dev/null 2>&1; then
        echo "Attempting to run configure_docker_daemon() from repo" | tee -a "$LOGFILE"
        if configure_docker_daemon >> "$LOGFILE" 2>&1; then
            echo "configure_docker_daemon executed - attempting docker restart" | tee -a "$LOGFILE"
            sudo systemctl restart docker >> "$LOGFILE" 2>&1 || true
            sudo journalctl -u docker --no-pager -n 200 >> "$LOGFILE" 2>&1 || true
        else
            echo "configure_docker_daemon failed" | tee -a "$LOGFILE"
        fi
    else
        echo "configure_docker_daemon function not available in sourced repo files" | tee -a "$LOGFILE"
    fi
fi

echo "Repair finished at $(date)" | tee -a "$LOGFILE"
echo "Logfile: $LOGFILE"

exit 0
