# NAS Setup Script v2.1.1

A fully automated script for setting up a professional Network Attached Storage (NAS) system with advanced security features and comprehensive service integration across multiple Linux distributions.

## 🚀 New Features in v2.1.1 - Distribution Detection Enhancement Release

- **Webmin Integration** for web-based system administration
- **Advanced Memory Optimization** with vm.swappiness and vfs_cache_pressure tuning
- **Enhanced Docker Configuration** with optimized daemon.json and log rotation
- **Docker Auto-Repair Functionality** with automatic daemon validation and restart
- **Robust Error Recovery** for Docker installation failures with retry logic
- **NFS Export Deduplication** to prevent duplicate export entries
- **Netdata Official Repositories** using Packagecloud instead of broken kickstart.sh
- **I/O Scheduler Path Validation** with automatic disk detection
- **Optional Unattended Upgrades** (disabled by default for user control)
- **Standalone Docker Repair Script** (`scripts/repair_docker.sh`) for troubleshooting

### Previous v2.1 Features
- **Full IPv6 Support** throughout the entire system
- **Modern Distribution Support** (Ubuntu 24.04+, Fedora 41+, openSUSE 15.6+)
- **Enhanced Security** with Ed25519 SSH keys, auditd logging, and MAC
- **Docker Compose Plugin** for modern container management
- **Dual-Stack Networking** with IPv4/IPv6 connectivity tests
- **Official Repository Sources** for all distributions
- **Performance Optimizations** for modern hardware
- **Enterprise-Grade Security** with comprehensive hardening

## 📋 Legal Notice

**Copyright (c) 2025 Sebastian Palencsár**

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

**Disclaimer:** This script is provided "as is", without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose, and noninfringement. In no event shall the authors or copyright holders be liable for any claim, damages, or other liability, whether in an action of contract, tort, or otherwise, arising from, out of, or in connection with the software or the use or other dealings in the software.

## 🖥️ Supported Distributions

| Distribution | Minimum Version | Status | Tested | IPv6 Support |
|--------------|----------------|--------|---------|--------------|
| Ubuntu       | 24.04 LTS      | ✅ Full Support | ✅ | ✅ Full |
| Debian       | 12 (Bookworm)  | ✅ Full Support | ✅ | ✅ Full |
| Fedora       | 41+            | ✅ Full Support | ✅ | ✅ Full |
| Arch Linux   | Rolling        | ✅ Full Support | ✅ | ✅ Full |
| openSUSE     | Leap 15.6+     | ✅ Full Support | ✅ | ✅ Full |

## ✨ Features and Services

### 🔧 Core System
- **Robust Distribution Detection** with 5-method fallback system and container environment detection
- **Advanced Version Validation** with regex parsing and bc calculator for precise comparisons
- **Dual-Stack Network Configuration** (IPv4/IPv6 static IP, gateway, DNS)
- **SSH Hardening** with Ed25519 keys and custom port
- **User Management** with sudo privileges
- **System Updates** and automatic security updates

### 🛡️ Security Features
- **UFW/Firewalld Configuration** with IPv6 support and intelligent rules
- **Fail2ban Integration** for brute-force attack protection
- **Rate Limiting** for critical services (IPv4/IPv6)
- **IP Blocking Tools** for manual security measures
- **Firewall Monitoring** with automatic alerts
- **Secure Shared Memory** implementation
- **Docker Content Trust** activation
- **Audit Logging** with comprehensive system monitoring
- **Mandatory Access Control** (AppArmor/SELinux integration)

### 📁 File Sharing
- **Samba Configuration** with performance optimizations
- **NFS Server** for Unix/Linux clients
- **User-specific Shares** with access control
- **Time Machine Support** for macOS backups

### 🐳 Container Platform
- **Docker Installation** from official repositories with optimized configuration
- **Docker Compose Plugin** (v2.30.0+) for modern container orchestration
- **Portainer** for graphical container management with HTTPS
- **Secure Container Configuration** with best practices and IPv6 support

### 📊 Monitoring and Management
- **Netdata** for real-time system monitoring
- **Jellyfin** media server for multimedia content
- **Vaultwarden** for secure password management
- **Webmin** web-based system administration interface
- **System Performance Tracking** with automatic reports
- **Comprehensive Unit Testing** framework with extensive test coverage

## 🔧 System Requirements

### Minimum Hardware Requirements
- **CPU:** Dual-core processor (x86_64/AMD64)
- **RAM:** 4GB minimum, 8GB recommended for Docker workloads
- **Storage:** 30GB for system, additional storage for NAS data
- **Network:** Gigabit Ethernet with IPv4/IPv6 support recommended

### Software Requirements
- Fresh installation of a supported Linux distribution
- systemd-based system
- Root access or sudo privileges
- Active IPv4/IPv6 internet connection for package downloads

### Optional Requirements
- **ARM64 Support:** Partially available (experimental)
- **UEFI/BIOS:** Both supported
- **Hardware RAID:** Compatible with software RAID

## 🚀 Installation

### 1. Clone Repository
```bash
git clone https://github.com/spalencsar/nas.git
cd nas
```

### 2. Make Script Executable
```bash
chmod +x setup.sh
```

### 3. Run Installation
```bash
sudo ./setup.sh
```

### 4. Run Unit Tests (Optional)
```bash
chmod +x tests/unit_tests.sh
./tests/unit_tests.sh
```

## ⚙️ Configuration

The script guides you through an interactive configuration:

### Network Settings
- **SSH Port:** Default 39000 (customizable)
- **Dual-Stack IP:** IPv4/IPv6 static IP configuration
- **Gateway and DNS:** IPv4/IPv6 automatic detection with override capability

### Service Selection
- **Docker:** Container platform with Compose plugin and auto-repair functionality (required for Vaultwarden, Jellyfin, Portainer)
- **NFS:** Network File System with IPv6 support and export deduplication
- **Netdata:** System monitoring via official Packagecloud repositories
- **Vaultwarden:** Password manager with security hardening (requires Docker, optional)
- **Jellyfin:** Media server with modern GPG keys (requires Docker, optional)
- **Portainer:** Docker management with HTTPS (requires Docker, optional)
- **Webmin:** Web-based system administration interface (optional)
- **Unattended Upgrades:** Automatic security updates (optional, disabled by default)

### Security Configuration
- **Firewall Rules:** IPv4/IPv6 automatic based on selected services
- **Fail2ban:** Protection against brute-force attacks
- **Rate Limiting:** IPv4/IPv6 protection against DoS attacks
- **SSH Keys:** Ed25519 key generation for enhanced security

## 📁 Directory Structure

```
nas/
├── setup.sh                    # Main installation script
├── scripts/
│   └── repair_docker.sh        # Docker repair and troubleshooting script
├── config/
│   └── defaults.sh            # Configuration variables and defaults
├── lib/
│   ├── common.sh              # Common functions and validation
│   ├── detection.sh           # Distribution and container detection
│   ├── logging.sh             # Enhanced logging functionality
│   ├── network.sh             # Network and SSH configuration
│   ├── firewall.sh            # Firewall and security configuration
│   ├── docker.sh              # Docker installation and configuration
│   ├── security.sh            # Security measures and Fail2ban
│   ├── internet.sh            # Internet connectivity checks
│   ├── nfs.sh                 # NFS server installation
│   ├── netdata.sh             # Netdata monitoring installation
│   ├── vaultwarden.sh         # Vaultwarden password manager
│   ├── jellyfin.sh            # Jellyfin media server
│   ├── portainer.sh           # Portainer Docker management
│   ├── webmin.sh              # Webmin web interface
│   ├── unattended-upgrades.sh # Automatic system updates
│   └── performance.sh         # Performance optimization
├── tests/
│   └── unit_tests.sh          # Unit tests for critical functions
├── README.md                  # This documentation
├── LICENSE                    # MIT License
├── CHANGELOG.md               # Change log
└── CONTRIBUTING.md            # Contribution guidelines
```

## 🔗 Default Ports and Services

| Service | Port | Protocol | Description | IPv6 Support |
|---------|------|----------|-------------|--------------|
| SSH | 39000 | TCP | Secure Shell Access | ✅ |
| Samba | 139, 445 | TCP | Windows File Sharing | ✅ |
| Samba | 137, 138 | UDP | NetBIOS Name Service | ✅ |
| NFS | 2049 | TCP | Network File System | ✅ |
| Netdata | 19999 | TCP | System Monitoring | ✅ |
| Jellyfin | 8096 | TCP | Media Server Web Interface | ✅ |
| Jellyfin | 8920 | TCP | Media Server HTTPS | ✅ |
| Jellyfin | 1900 | UDP | DLNA Discovery | ✅ |
| Portainer | 9000 | TCP | Docker Management (HTTPS) | ✅ |
| Vaultwarden | 8080 | TCP | Password Manager | ✅ |
| Webmin | 10000 | TCP | Web Administration Interface | ✅ |
| Docker API | 2375, 2376 | TCP | Docker Remote API | ✅ |

## 🛡️ Security Features

### Advanced Firewall Configuration
- **UFW (Ubuntu/Debian/Arch):** IPv4/IPv6 rule configuration with local network rules
- **Firewalld (Fedora/openSUSE):** Zone-based security with IPv6 rich rules
- **Rate Limiting:** IPv4/IPv6 protection against DoS attacks
- **IP Blocking Tools:** Manual security measures for both protocols

### Intrusion Detection & Audit
- **Fail2ban:** Automatic IP blocking for suspicious activities
- **Auditd:** Comprehensive system auditing and logging
- **Log Monitoring:** Real-time security event monitoring
- **Alert System:** Notifications for security incidents

### SSH Hardening & Access Control
- **Ed25519 Keys:** Modern cryptographic key generation
- **Custom Ports:** Reduction of automated attacks
- **Key-based Authentication:** Enhanced security over passwords
- **Connection Limits:** Limiting concurrent connections
- **Root Login Prohibition:** Enhanced security posture
- **Mandatory Access Control:** AppArmor/SELinux integration

## 📊 Monitoring and Maintenance

### System Monitoring
```bash
# Netdata Dashboard
http://YOUR_NAS_IP:19999

# Check system status
sudo systemctl status nas-*

# Firewall status
sudo ufw status verbose           # Ubuntu/Debian/Arch
sudo firewall-cmd --list-all      # Fedora/openSUSE

# Check logs
sudo tail -f /var/log/nas_setup.log
sudo journalctl -f -u netdata
```

### Maintenance Commands
```bash
# Block IP address
sudo /usr/local/bin/block-ip 192.168.1.100

# Unblock IP address
sudo /usr/local/bin/unblock-ip 192.168.1.100

# Firewall monitoring
sudo systemctl status firewall-monitor

# System updates
sudo apt update && sudo apt upgrade   # Ubuntu/Debian
sudo dnf update                       # Fedora
sudo pacman -Syu                      # Arch
sudo zypper update                    # openSUSE
```

## 🔄 Backup and Recovery

### Automatic Backups
- **Configuration Backups:** Automatically created before changes
- **Firewall Configuration:** Backed up in `/etc/firewall-backup/`
- **Service Configurations:** Timestamped backups

### Rollback Functionality
The script offers automatic rollback on errors:
```bash
# Rollback is automatically offered on errors
# Manual rollback execution possible via log files
```

### Data Backup Strategy
```bash
# Important directories for backup:
/etc/nas_setup.conf              # Configuration
/var/log/nas_setup.log          # Installation logs
/srv/samba/                     # Samba shares
/opt/vaultwarden/               # Vaultwarden data
/var/lib/jellyfin/              # Jellyfin data
/opt/portainer/                 # Portainer data
```

## 🐛 Troubleshooting

### Common Issues and Solutions

#### Network Issues
```bash
# Check network configuration
ip addr show                    # IPv4/IPv6 addresses
ip route show                   # Routing table
cat /etc/netplan/01-netcfg.yaml # Ubuntu/Debian network config

# IPv6 specific checks
ip -6 addr show                 # IPv6 addresses only
ip -6 route show               # IPv6 routing
ping6 google.com               # IPv6 connectivity test

# Restart network services
sudo netplan apply                  # Ubuntu/Debian
sudo systemctl restart NetworkManager  # Fedora/openSUSE
```

#### Docker Issues
```bash
# Check Docker status
sudo systemctl status docker
sudo docker version

# View Docker logs
sudo journalctl -u docker -f

# Repair Docker configuration (new in v2.1.1)
sudo ./scripts/repair_docker.sh

# Check daemon.json syntax
sudo docker daemon --validate-config

# Restart Docker with validation
sudo systemctl restart docker
```

#### Service Issues
```bash
# Check service status
sudo systemctl status docker
sudo systemctl status samba
sudo systemctl status nfs-server
sudo systemctl status netdata

# View service logs
sudo journalctl -u docker -f
sudo journalctl -u samba -f
```

#### Firewall Issues
```bash
# UFW status and rules (IPv4/IPv6)
sudo ufw status numbered
sudo ufw show raw

# Firewalld status and rules (IPv4/IPv6)
sudo firewall-cmd --list-all-zones
sudo firewall-cmd --get-active-zones

# IPv6 specific firewall checks
sudo ip6tables -L -n          # Direct IPv6 rules
sudo firewall-cmd --list-all --zone=public  # Firewalld IPv6
```

#### Permission Issues
```bash
# Samba user status
sudo pdbedit -L
sudo smbpasswd -a username

# Fix file permissions
sudo chown -R username:username /srv/samba/shared/
sudo chmod -R 755 /srv/samba/shared/
```

## 🤝 Contributing

We welcome contributions to improve this project! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details.

### Development Workflow
1. Fork the repository
2. Create feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit changes (`git commit -m 'Add some AmazingFeature'`)
4. Push branch (`git push origin feature/AmazingFeature`)
5. Open Pull Request

### Code Standards
- **Bash Scripting:** Strict error handling (`set -euo pipefail`)
- **Documentation:** Comprehensive commenting
- **Testing:** Unit tests for new functions
- **Security:** Security review for all changes

## 📞 Support

### Community Support
1. [Browse Wiki](https://github.com/spalencsar/nas/wiki)
2. [Search existing issues](https://github.com/spalencsar/nas/issues)
3. Create new issue if needed

### Security Issues
Please see our [Security Policy](SECURITY.md) for reporting security vulnerabilities.

### Professional Support
For commercial support and custom solutions, contact the author.

## 🏆 Acknowledgments

- Thanks to all contributors of the open source project
- Inspired by best practices in NAS setup and administration
- Built with and for the open source community
- Special thanks to the maintainers of the packages and services used

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👨‍💻 Author

**Sebastian Palencsár**
- GitHub: [@spalencsar](https://github.com/spalencsar)
- Project Repository: [NAS Script](https://github.com/spalencsar/nas)

---

*Developed with ❤️ for the NAS community*