# Raspberry Pi Travel VPN Router - Changelog

All notable changes to this project will be documented in this file.

## [1.0.0] - 2025-11-02

### Added
- Initial release of the Raspberry Pi Travel VPN Router
- Automated installation script with comprehensive logging
- Support for Netgear A7000 (Realtek 8812AU chipset)
- NordVPN integration with OpenVPN
- Network architecture with separate AP, client, and management interfaces
- Helper scripts for:
  - WiFi network switching (`connect-wifi.sh`)
  - VPN server changing (`change-vpn.sh`)
  - System status checking (`router-status.sh`)
- Comprehensive documentation:
  - Getting Started Guide
  - Manual Setup Guide
  - NordVPN Credentials Guide
  - Troubleshooting Guide
- Firewall configuration with iptables
- Persistent configuration across reboots
- Security features:
  - Isolated management interface
  - VPN killswitch via routing
  - WPA2 encryption for access point

### Features
- Dual WiFi operation (AP + Client simultaneously)
- Automatic VPN connection on boot
- DHCP server for connected clients
- DNS configuration through VPN
- Support for multiple saved WiFi networks
- Detailed installation logging
- Service status verification
- Color-coded terminal output

### Documentation
- Complete hardware requirements list
- Network architecture diagram
- Step-by-step setup instructions
- Troubleshooting for common issues
- Security recommendations
- Performance optimization tips

### Tested On
- Raspberry Pi 4 Model B (2GB, 4GB, 8GB)
- Raspberry Pi OS Lite (64-bit) - Bookworm
- Netgear A7000 USB WiFi Adapter
- NordVPN servers (US region)

### Known Limitations
- Requires external USB WiFi adapter
- VPN connection may take 30-60 seconds to establish
- Performance depends on VPN server selection
- Management access only via Ethernet for security

### Security Notes
- Default credentials should be changed immediately
- VPN credentials stored with 600 permissions
- Management interface isolated from client network
- Regular system updates recommended

---

## Future Considerations

### Potential Enhancements
- Web-based configuration interface
- Automatic VPN server selection based on speed
- Mobile app for WiFi switching
- Support for additional VPN providers
- Failover to non-VPN connection if VPN fails
- Traffic usage statistics
- QoS (Quality of Service) configuration
- Guest network support
- VPN protocol selection (OpenVPN vs WireGuard)

### Community Contributions Welcome
- Additional WiFi adapter support
- Alternative VPN provider configurations
- Performance optimizations
- Documentation improvements
- Translated documentation
