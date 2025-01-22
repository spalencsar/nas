# NAS Setup Script

An automated script for setting up a Network Attached Storage (NAS) system with various services across multiple Linux distributions.

## Legal Notice

Copyright (c) 2025 Sebastian Palencsár

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

**Disclaimer:** This script is provided "as is", without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose, and noninfringement. In no event shall the authors or copyright holders be liable for any claim, damages, or other liability, whether in an action of contract, tort, or otherwise, arising from, out of, or in connection with the software or the use or other dealings in the software.

## Supported Distributions

- Ubuntu
- Debian
- Fedora
- Arch Linux
- openSUSE

## Features

- Automatic Linux distribution detection
- Network configuration (static IP)
- Security setup (Fail2ban, Firewall)
- Docker installation and configuration
- Various services:
  - Samba shares
  - NFS
  - Netdata (system monitoring)
  - Vaultwarden (password manager)
  - Jellyfin (media server)
  - Portainer (Docker management)

## Prerequisites

- Supported Linux distribution
- Root access or sudo rights
- Active internet connection
- Minimum 2GB RAM
- Minimum 20GB free disk space

## Installation

1. Clone repository:
```bash
git clone https://github.com/noordjonge/nasscript.git
cd nasscript
```

2. Make the script executable:
```bash
chmod +x src/setup.sh
```

3. Run the script:
```bash
sudo ./src/setup.sh
```

## Configuration

### Network
- Static IP address
- Gateway
- DNS server

### Security
- SSH port (default: 39000)
- Fail2ban
- Firewall rules

### Services
- Docker data directory
- Samba shares
- NFS exports
- Vaultwarden settings
- Jellyfin media paths
- Portainer configuration

## Directory Structure

```
nasscript/
├── LICENSE
├── README.md
└── src/
    ├── setup.sh
    ├── config/
    │   └── defaults.sh
    └── lib/
        ├── docker.sh
        ├── firewall.sh
        ├── internet.sh
        ├── jellyfin.sh
        ├── logging.sh
        ├── netdata.sh
        ├── network.sh
        ├── nfs.sh
        ├── portainer.sh
        ├── security.sh
        ├── unattended-upgrades.sh
        └── vaultwarden.sh
```

## Usage

1. Run the script with root privileges
2. Follow the on-screen instructions
3. Configure network settings
4. Choose the services to install
5. Wait for the installation to complete

## System Requirements

### Minimum Hardware Requirements
- CPU: Dual-core processor
- RAM: 2GB minimum, 4GB recommended
- Storage: 20GB for system, additional storage for NAS
- Network: Gigabit Ethernet recommended

### Software Requirements
- Clean installation of supported Linux distribution
- systemd-based system
- Internet connection for package downloads
- UEFI or BIOS boot system

## Default Ports
- SSH: 39000 (customizable)
- Samba: 139, 445
- NFS: 2049
- Netdata: 19999
- Vaultwarden: 80
- Jellyfin: 8096
- Portainer: 9000

## Security Features
- Automatic security updates
- Fail2ban integration
- UFW firewall configuration
- Docker content trust enabled
- Secure shared memory implementation
- SSH hardening

## Troubleshooting

Common issues and solutions:

1. Network Configuration
```bash
# Check network status
ip addr show
# Verify network configuration
cat /etc/netplan/01-netcfg.yaml
```

2. Service Status
```bash
# Check service status
systemctl status docker
systemctl status jellyfin
systemctl status vaultwarden
```

3. Firewall Rules
```bash
# View firewall status
sudo ufw status
# Check specific port
sudo ufw status | grep 80
```

## Backup Strategy
- Configuration files are automatically backed up before modifications
- Docker volumes should be backed up regularly
- User data requires separate backup strategy
- Recommended: Create periodic snapshots

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## Support

If you encounter any issues or have questions, please:

1. Check the [Wiki](https://github.com/noordjonge/nasscript/wiki)
2. Search [existing issues](https://github.com/noordjonge/nasscript/issues)
3. Create a new issue if needed

## Author

Sebastian Palencsár

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Thanks to all contributors
- Inspired by best practices in NAS setup and administration
- Built with and for the open source community
