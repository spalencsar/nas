# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.4.0] - 2025-01-01
### Added
- Support for multiple Linux distributions (Ubuntu, Debian, Fedora, Arch Linux, openSUSE)
- Installation of Docker, NFS, and Netdata
- Improved network configuration

### Changed
- Modularization of the script by moving functions to separate files

### Fixed
- Improved error handling and logging

## [3.0.0] - 2024-01-28
### Added
- Initial public release of the NAS Setup Script version 3.0
- Compatibility with Ubuntu 22.04 and later versions
- SSH configuration with custom port and user
- Samba file sharing setup
- Docker installation and configuration
- Basic security measures including:
  - Firewall setup (ufw)
  - fail2ban installation
  - Secure shared memory configuration
- Automatic system updates configuration (unattended-upgrades)
- Optional installation of additional components:
  - Vaultwarden
  - Jellyfin
  - Portainer
  - Netdata
- System requirements check (disk space, RAM)
- Network configuration with static IP option
- Time Machine backup support for macOS
- Comprehensive logging functionality
- Enhanced error handling and progress display
- Configuration file (config.sh) for easy customization
- Backup functionality for configuration files
- Basic system monitoring tools (htop, iotop)

### Changed
- Improved script structure and modularity
- Enhanced user interaction with more informative prompts

### Documentation
- Comprehensive README with usage instructions
- Contribution guidelines (CONTRIBUTING.md)
- MIT License
- This CHANGELOG file

[3.0.0]: https://github.com/noordjonge/nas-setup-script/releases/tag/v3.0.0
[3.4.0]: https://github.com/noordjonge/nas-setup-script/releases/tag/v3.4.0