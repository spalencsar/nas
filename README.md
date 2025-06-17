# NAS Setup Script v2.0

A fully automated script for setting up a professional Network Attached Storage (NAS) system with advanced security features and comprehensive service integration across multiple Linux distributions.

## 🚀 New Features in v2.0

- **Enhanced Input Validation** with comprehensive error handling
- **Rollback Mechanism** for safe installation and recovery
- **Unit Tests** for critical functions
- **Performance Optimizations** and improved logging functionality
- **Interactive Configuration** with intelligent defaults
- **Automatic Dependency Checks** and installation
- **Advanced Firewall Configuration** with intrusion detection
- **Monitoring and Alerting** for system and security events

## 📋 Legal Notice

**Copyright (c) 2025 Sebastian Palencsár**

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

**Disclaimer:** This script is provided "as is", without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose, and noninfringement. In no event shall the authors or copyright holders be liable for any claim, damages, or other liability, whether in an action of contract, tort, or otherwise, arising from, out of, or in connection with the software or the use or other dealings in the software.

## 🖥️ Supported Distributions

| Distribution | Minimum Version | Status | Tested |
|--------------|----------------|--------|---------|
| Ubuntu       | 20.04 LTS      | ✅ Full Support | ✅ |
| Debian       | 11 (Bullseye)  | ✅ Full Support | ✅ |
| Fedora       | 35+            | ✅ Full Support | ✅ |
| Arch Linux   | Rolling        | ✅ Full Support | ✅ |
| openSUSE     | Leap 15.4+     | ✅ Full Support | ✅ |

## ✨ Features and Services

### 🔧 Core System
- **Automatic Distribution Detection** with version validation
- **Network Configuration** (static IP, gateway, DNS)
- **SSH Hardening** with custom port and security policies
- **User Management** with sudo privileges
- **System Updates** and automatic security updates

### 🛡️ Security Features
- **UFW/Firewalld Configuration** with intelligent rules
- **Fail2ban Integration** for brute-force attack protection
- **Rate Limiting** for critical services
- **IP Blocking Tools** for manual security measures
- **Firewall Monitoring** with automatic alerts
- **Secure Shared Memory** implementation
- **Docker Content Trust** activation

### 📁 File Sharing
- **Samba Configuration** with performance optimizations
- **NFS Server** for Unix/Linux clients
- **User-specific Shares** with access control
- **Time Machine Support** for macOS backups

### 🐳 Container Platform
- **Docker Installation** with optimized configuration
- **Docker Compose** for multi-container applications
- **Portainer** for graphical container management
- **Secure Container Configuration** with best practices

### 📊 Monitoring and Management
- **Netdata** for real-time system monitoring
- **Jellyfin** media server for multimedia content
- **Vaultwarden** for secure password management
- **System Performance Tracking** with automatic reports

## 🔧 System Requirements

### Minimum Hardware Requirements
- **CPU:** Dual-core processor (x86_64/AMD64)
- **RAM:** 2GB minimum, 4GB recommended
- **Storage:** 20GB for system, additional storage for NAS data
- **Network:** Gigabit Ethernet recommended

### Software Requirements
- Fresh installation of a supported Linux distribution
- systemd-based system
- Root access or sudo privileges
- Active internet connection for package downloads

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
- **Static IP:** Optionally configurable
- **Gateway and DNS:** Automatic detection with override capability

### Service Selection
- **Docker:** Container platform
- **NFS:** Network File System
- **Netdata:** System monitoring
- **Vaultwarden:** Password manager
- **Jellyfin:** Media server
- **Portainer:** Docker management

### Security Configuration
- **Firewall Rules:** Automatic based on selected services
- **Fail2ban:** Protection against brute-force attacks
- **Rate Limiting:** Protection against DoS attacks

## 📁 Directory Structure

```
nas/
├── setup.sh                    # Main installation script
├── config/
│   └── defaults.sh            # Configuration variables and defaults
├── lib/
│   ├── common.sh              # Common functions and validation
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

| Service | Port | Protocol | Description |
|---------|------|----------|-------------|
| SSH | 39000 | TCP | Secure Shell Access |
| Samba | 139, 445 | TCP | Windows File Sharing |
| Samba | 137, 138 | UDP | NetBIOS Name Service |
| NFS | 2049 | TCP | Network File System |
| Netdata | 19999 | TCP | System Monitoring |
| Jellyfin | 8096 | TCP | Media Server Web Interface |
| Jellyfin | 8920 | TCP | Media Server HTTPS |
| Jellyfin | 1900 | UDP | DLNA Discovery |
| Portainer | 9000 | TCP | Docker Management |
| Vaultwarden | 8080 | TCP | Password Manager |
| Docker API | 2375, 2376 | TCP | Docker Remote API |

## 🛡️ Security Features

### Advanced Firewall Configuration
- **UFW (Ubuntu/Debian/Arch):** Automatic rule configuration
- **Firewalld (Fedora/openSUSE):** Zone-based security
- **Rate Limiting:** Protection against DoS attacks
- **IP Blocking Tools:** Manual security measures

### Intrusion Detection
- **Fail2ban:** Automatic IP blocking for suspicious activities
- **Log Monitoring:** Real-time security event monitoring
- **Alert System:** Notifications for security incidents

### SSH Hardening
- **Custom Ports:** Reduction of automated attacks
- **Key-based Authentication:** SSH key support
- **Connection Limits:** Limiting concurrent connections
- **Root Login Prohibition:** Enhanced security

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
ip addr show
ip route show
cat /etc/netplan/01-netcfg.yaml    # Ubuntu/Debian
cat /etc/sysconfig/network-scripts/ifcfg-*  # Fedora/openSUSE

# Restart network services
sudo netplan apply                  # Ubuntu/Debian
sudo systemctl restart NetworkManager  # Fedora/openSUSE
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
# UFW status and rules
sudo ufw status numbered
sudo ufw show raw

# Firewalld status and rules
sudo firewall-cmd --list-all-zones
sudo firewall-cmd --get-active-zones
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