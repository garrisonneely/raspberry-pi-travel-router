# Raspberry Pi Travel VPN Router

Transform your Raspberry Pi 4 into a portable VPN router that creates a secure WiFi hotspot, routing all traffic through NordVPN. Perfect for hotels, airports, coffee shops, and protecting all your devices with a single VPN connection.

## 🌟 Features

- **Secure WiFi Hotspot**: Creates a WPA2-protected access point for your devices
- **Automatic VPN Routing**: All traffic automatically routed through NordVPN
- **Dual WiFi Support**: One adapter for AP, another for connecting to external WiFi
- **Easy WiFi Switching**: Simple commands to connect to new networks while traveling
- **Persistent Configuration**: Survives reboots and maintains settings
- **Management Interface**: Dedicated Ethernet port for SSH access

## 📋 Hardware Requirements

| Component | Specification |
|-----------|--------------|
| **Raspberry Pi** | Raspberry Pi 4 Model B (2GB+ RAM recommended) |
| **USB WiFi Adapter** | Netgear A7000 (Realtek RTL8814AU chipset) |
| **MicroSD Card** | 32GB+ (Class 10 or better) |
| **Power Supply** | Official Raspberry Pi 4 power supply (5V/3A USB-C) |
| **Ethernet Cable** | For initial setup and management access |

### Why the Netgear A7000?
The A7000 uses the Realtek RTL8814AU chipset, which has excellent Linux driver support and can handle both 2.4GHz and 5GHz networks. It's stable, reliable, and widely available. The installation script auto-detects the chipset and installs the correct driver.

## 🏗️ Network Architecture

```
Internet (Hotel/Public WiFi)
         ↓
    [wlan1] ← WiFi Client Interface
         ↓
  Raspberry Pi 4
    VPN Tunnel (tun0) ← NordVPN Connection
         ↓
    [wlan0] ← Access Point Interface (192.168.4.1)
         ↓
  Your Devices (Laptop, Phone, Tablet)

    [eth0] ← Management Interface (192.168.100.2)
         ↓
  Direct SSH Access
```

### Network Interfaces

- **wlan0** (Built-in WiFi): Access Point broadcasting "GKTravelRouter" (192.168.4.1)
- **wlan1** (USB Adapter): WiFi Client connecting to hotel/external WiFi
- **eth0** (Ethernet): Management interface for SSH (192.168.100.2)
- **tun0** (Virtual): VPN tunnel interface routing all traffic through NordVPN

## 🚀 Quick Start

### Complete Setup Guide

📖 **[Read the Getting Started Guide](docs/GETTING_STARTED.md)** for detailed step-by-step instructions.

### Quick Steps

1. **Flash Raspberry Pi OS Lite** to microSD card using [Raspberry Pi Imager](https://www.raspberrypi.com/software/)
2. **Enable SSH** during imaging or create empty `ssh` file in boot partition
3. **Boot Pi** and connect via SSH
4. **Get NordVPN credentials** from [my.nordaccount.com](https://my.nordaccount.com/) ([detailed guide](docs/NORDVPN_CREDENTIALS.md))
5. **Transfer scripts** to Pi (via git clone or SCP)
5. **Run installation**:
   ```bash
   cd raspberry-pi-travel-router
   sudo bash scripts/install.sh
   ```
   **Note**: The installation requires one reboot after driver installation. After reboot, reconnect and re-run the script to continue.
6. **Connect devices** to your new secure WiFi network
8. **Verify VPN** is working at [whatismyip.com](https://www.whatismyip.com/)

**Installation time**: 30-60 minutes (mostly automated)

## 📦 What's Included

- `install.sh` - Main automated installation script
- `config/` - Configuration templates for all services
- `scripts/` - Helper utilities for network management
- `docs/` - Detailed documentation and troubleshooting

## 🔧 Manual Installation

If you prefer to understand each step or need to customize the setup, see [MANUAL_SETUP.md](MANUAL_SETUP.md) for the complete step-by-step guide.

## 📱 Usage After Setup

### Connecting Your Devices
1. Connect to WiFi network: **GKTravelRouter**
2. Password: **CABOFUN1**
3. All traffic automatically routes through VPN

### Connecting to New WiFi Networks
```bash
# SSH into the Pi (via Ethernet)
ssh travelvpn@192.168.100.2

# Edit WiFi configuration
## 📦 Repository Contents

```
raspberry-pi-travel-router/
├── scripts/
│   ├── install.sh           # Main automated installation script
│   ├── connect-wifi.sh      # Connect to new WiFi networks
│   ├── change-vpn.sh        # Change VPN server
│   └── router-status.sh     # Check system status
├── docs/
│   ├── GETTING_STARTED.md   # Complete setup guide (start here!)
│   ├── MANUAL_SETUP.md      # Step-by-step manual configuration
│   ├── NORDVPN_CREDENTIALS.md  # How to get NordVPN credentials
│   └── TROUBLESHOOTING.md   # Common issues and solutions
└── README.md                # This file
```

## 📚 Documentation

- **[Getting Started Guide](docs/GETTING_STARTED.md)** - Complete setup from scratch
- **[Manual Setup Guide](docs/MANUAL_SETUP.md)** - Understand each configuration step
- **[NordVPN Credentials](docs/NORDVPN_CREDENTIALS.md)** - How to obtain service credentials
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Solutions to common problems
## 🐛 Troubleshooting

See **[Troubleshooting Guide](docs/TROUBLESHOOTING.md)** for detailed solutions.

### Quick Diagnostic Commands

```bash
# Check all services at once
bash scripts/router-status.sh

# Check specific services
sudo systemctl status hostapd dnsmasq wpa_supplicant@wlan1 openvpn@nordvpn

# Verify VPN is working
curl ifconfig.me  # Should show VPN server IP

# View logs
sudo journalctl -u openvpn@nordvpn -f
```

### Common Issues

- **Access Point not visible**: `sudo rfkill unblock wifi && sudo systemctl restart hostapd`
- **VPN won't connect**: Check credentials and internet connectivity
- **No internet on clients**: Verify VPN tunnel is up (`ip link show tun0`)
- **Slow performance**: Try different VPN server or channel
See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues and solutions.

Quick checks:
```bash
# Check all services
sudo systemctl status hostapd
sudo systemctl status dnsmasq
sudo systemctl status openvpn@nordvpn
## 🎓 Learning Resources

### Understanding the Setup

Each component serves a specific purpose:

- **hostapd**: Creates the WiFi access point (wlan0)
- **dnsmasq**: Provides DHCP and DNS services to clients
- **wpa_supplicant**: Connects to external WiFi (wlan1)
- **OpenVPN**: Establishes VPN tunnel to NordVPN
- **iptables**: Routes traffic through VPN and manages firewall

Want to understand everything in detail? Read the **[Manual Setup Guide](docs/MANUAL_SETUP.md)**.

## 🔄 Updates and Maintenance

### Keep Your System Updated

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Check for driver updates
cd /tmp/8812au-20210820
git pull
sudo ./install-driver.sh
```

### Backup Your Configuration

```bash
# Create backup
sudo tar -czf ~/router-backup-$(date +%Y%m%d).tar.gz \
    /etc/hostapd/ /etc/dnsmasq.conf \
    /etc/wpa_supplicant/wpa_supplicant-wlan1.conf \
    /etc/openvpn/nordvpn.conf \
    /etc/dhcpcd.conf /etc/iptables/
```

## 🌍 Tested Environments

This setup has been tested with:
- ✅ Raspberry Pi 4 Model B (2GB, 4GB, 8GB)
- ✅ Raspberry Pi OS Lite (64-bit) - Bookworm
- ✅ Netgear A7000 USB WiFi Adapter
- ✅ NordVPN service
- ✅ Various hotel and public WiFi networks

## ❓ FAQ

**Q: Can I use a different VPN provider?**  
A: Yes, but you'll need to adapt the OpenVPN configuration for your provider.

**Q: Will this work with other WiFi adapters?**  
A: Any adapter with Linux driver support should work. The 8812AU chipset is recommended.

**Q: Can I use the built-in WiFi for both AP and client?**  
A: No, you need separate interfaces for Access Point and WiFi client modes.

**Q: What's the performance impact of VPN?**  
A: Expect 20-40% speed reduction due to encryption overhead, varies by server.

**Q: Can I connect via the access point to manage the router?**  
A: For security, management (SSH) is only available via Ethernet on 192.168.100.2.

---

**Status**: ✅ Ready for deployment  
**Last Updated**: November 2025
curl ifconfig.me  # Should show VPN server IP, not your real IP
```

## 📖 Additional Resources

- [NordVPN OpenVPN Configuration Files](https://nordvpn.com/ovpn/)
- [Raspberry Pi Documentation](https://www.raspberrypi.com/documentation/)
- [Realtek 8812AU Driver Repository](https://github.com/morrownr/8812au-20210820)

## 🤝 Contributing

This project is open source and welcomes contributions! If you've improved the setup process or found solutions to common issues, please submit a pull request.

## 📝 License

MIT License - Feel free to use and modify for your own travel router projects.

## ⚠️ Disclaimer

This setup is for securing your own devices on untrusted networks. Ensure you comply with NordVPN's terms of service and local laws regarding VPN usage.

---

**Current Status**: 📍 Phase 1 - OS Installation in Progress
