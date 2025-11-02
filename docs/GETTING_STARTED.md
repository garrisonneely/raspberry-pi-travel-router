# Getting Started with Your Travel VPN Router

This guide will walk you through setting up your Raspberry Pi from scratch to a fully functional travel VPN router.

## Overview

**Time Required**: 30-60 minutes  
**Difficulty**: Intermediate  
**Prerequisites**: Basic command line knowledge

## What You'll Build

A portable VPN router that:
- Creates a secure WiFi hotspot for your devices
- Routes all traffic through NordVPN
- Connects to any hotel/public WiFi
- Provides a separate management interface

## Phase 1: Prepare the Hardware

### 1.1 Gather Components

✓ Raspberry Pi 4 Model B  
✓ Netgear A7000 USB WiFi Adapter  
✓ MicroSD card (32GB+, Class 10)  
✓ USB-C power supply (official RPi 5V/3A recommended)  
✓ Ethernet cable  
✓ Computer for flashing and SSH

### 1.2 Download Raspberry Pi OS

1. Download **Raspberry Pi Imager**: https://www.raspberrypi.com/software/
2. Or download **Raspberry Pi OS Lite (64-bit)** directly: https://www.raspberrypi.com/software/operating-systems/

**Recommended**: Use the Lite version (no desktop) for better performance.

## Phase 2: Flash the Operating System

### 2.1 Using Raspberry Pi Imager (Recommended)

1. **Launch Raspberry Pi Imager**
2. Click **"Choose Device"** → Select "Raspberry Pi 4"
3. Click **"Choose OS"** → "Raspberry Pi OS (other)" → "Raspberry Pi OS Lite (64-bit)"
4. Click **"Choose Storage"** → Select your microSD card
5. Click the **⚙️ gear icon** (or press `Ctrl+Shift+X`) for advanced options:

   **Set hostname**: `travelrouter`  
   **Enable SSH**: ✓ Use password authentication  
   **Set username and password**:
   - Username: `pi` (or your choice)
   - Password: (choose a strong password)
   
   **Configure wireless LAN** (optional, for initial setup):
   - SSID: Your current WiFi name
   - Password: Your WiFi password
   - Wireless LAN country: US
   
   **Set locale settings**:
   - Time zone: America/Denver (or your timezone)
   - Keyboard layout: us

6. Click **"Save"**
7. Click **"Write"** and confirm
8. Wait for writing and verification to complete

### 2.2 Using balenaEtcher (Alternative)

1. Download OS image from Raspberry Pi website
2. Launch balenaEtcher: https://www.balena.io/etcher/
3. Select the downloaded .img file
4. Select your microSD card
5. Click "Flash!"

**Important**: After flashing with Etcher, you must manually enable SSH:

**On Windows**:
1. After flashing, the SD card will show as "boot" drive
2. Open File Explorer → Navigate to the boot drive
3. Create a new empty file named `ssh` (no extension)
   - Right-click → New → Text Document
   - Name it `ssh` and remove the `.txt` extension
4. Eject the SD card safely

**On Mac/Linux**:
```bash
# Mount the boot partition and create ssh file
touch /Volumes/boot/ssh
```

## Phase 3: First Boot and Connection

### 3.1 Hardware Setup

1. **Insert** the microSD card into your Raspberry Pi
2. **Connect** Ethernet cable from Pi to your computer or router
3. **Connect** the Netgear A7000 USB WiFi adapter to Pi
4. **Connect** power supply last (Pi will boot automatically)

### 3.2 Find Your Pi's IP Address

**Method 1: Router Admin Panel**
- Log into your router (usually 192.168.1.1 or 192.168.0.1)
- Look for "Connected Devices" or "DHCP Clients"
- Find "travelrouter" or "raspberrypi"

**Method 2: Network Scan** (Windows)
```powershell
# In PowerShell
arp -a | findstr "b8-27-eb dc-a6-32 e4-5f-01"
```

**Method 3: Try Default Hostname**
```
raspberrypi.local
```
or
```
travelrouter.local
```

### 3.3 Connect via SSH

**Using PuTTY** (Windows):

1. **Open PuTTY**
2. **Host Name**: Enter the IP address or `raspberrypi.local`
3. **Port**: 22
4. **Connection type**: SSH
5. Click **"Open"**
6. **Security Alert**: Click "Yes" (first time only)
7. **Login as**: `pi` (or username you set)
8. **Password**: Enter your password

**Using Terminal** (Mac/Linux):
```bash
ssh pi@raspberrypi.local
# or
ssh pi@192.168.x.x
```

## Phase 4: Initial Configuration

### 4.1 Change Default Password (if not done during imaging)

```bash
passwd
```

Enter new password twice.

### 4.2 Run Initial Setup

```bash
sudo raspi-config
```

Navigate with arrow keys, Enter to select:

1. **System Options** → **S4 Hostname** → Set to `travelrouter`
2. **Localisation Options** → **L2 Timezone** → Americas → Denver (or your zone)
3. **Localisation Options** → **L3 Keyboard** → Generic 104-key PC → English (US)
4. **Advanced Options** → **A1 Expand Filesystem**
5. Select **Finish** → Reboot? **Yes**

### 4.3 Update System

After reboot, reconnect via SSH and run:

```bash
sudo apt update
sudo apt upgrade -y
```

This may take 5-15 minutes.

## Phase 5: Get NordVPN Service Credentials

Before running the installation, you need your NordVPN service credentials.

**See detailed instructions**: [docs/NORDVPN_CREDENTIALS.md](docs/NORDVPN_CREDENTIALS.md)

**Quick steps**:
1. Go to https://my.nordaccount.com/
2. Navigate to Services → NordVPN → Manual Setup
3. Generate or copy your service credentials
4. Save them temporarily (you'll need them during installation)

## Phase 6: Transfer Installation Scripts

### 6.1 Clone or Download Repository

**Option A: Using git** (recommended):

First, install git if not already installed:
```bash
sudo apt install git -y
```

Then clone the repository:
```bash
cd ~
git clone https://github.com/garrisonneely/raspberry-pi-travel-router.git
cd raspberry-pi-travel-router
```

**Note**: If this is a private repository, you'll need to authenticate. Use one of these methods:

**Method 1: Personal Access Token** (recommended):
```bash
# When prompted for password, use your Personal Access Token instead
# Create token at: https://github.com/settings/tokens
git clone https://github.com/garrisonneely/raspberry-pi-travel-router.git
```

**Method 2: GitHub CLI**:
```bash
# Install GitHub CLI
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install gh -y

# Authenticate and clone
gh auth login
git clone https://github.com/garrisonneely/raspberry-pi-travel-router.git
```

**Option B: Manual transfer via SCP/WinSCP**:

**Using WinSCP** (Windows):
1. Download WinSCP: https://winscp.net/
2. **File protocol**: SCP
3. **Host name**: Your Pi's IP
4. **User name**: pi
5. **Password**: Your password
6. Click **Login**
7. Drag and drop the entire `raspberry-pi-travel-router` folder to `/home/pi/`

**Using scp** (Mac/Linux):
```bash
scp -r ./raspberry-pi-travel-router pi@raspberrypi.local:~/
```

### 6.2 Make Scripts Executable

```bash
cd ~/raspberry-pi-travel-router/scripts
chmod +x *.sh
```

## Phase 7: Run Installation

### 7.1 Prepare Information

Before starting, have ready:
- **WiFi Network Name** (SSID) to connect to
- **WiFi Password**
- **NordVPN service username** (from Phase 5)
- **NordVPN service password** (from Phase 5)
- **Access Point Name** (default: GKTravelRouter)
- **Access Point Password** (default: CABOFUN1, or choose your own)

### 7.2 Run Installation Script

```bash
cd ~/raspberry-pi-travel-router
sudo bash scripts/install.sh
```

### 7.3 Follow Prompts

The script will:
1. ✓ Update system packages
2. ✓ Install USB WiFi driver (may take 10-15 minutes)
3. ✓ Configure network interfaces
4. ✓ Ask for Access Point SSID and password
5. ✓ Ask for WiFi network to connect to
6. ✓ Ask for NordVPN server selection
7. ✓ Ask for NordVPN credentials
8. ✓ Configure firewall and routing
9. ✓ Enable and start all services
10. ✓ Verify installation

**Installation time**: 20-40 minutes (driver compilation is the longest part)

### 7.4 During Installation

The script will automatically handle most prompts. You'll be asked to provide:
- Access Point SSID and password
- WiFi network to connect to
- NordVPN server and credentials

**Note**: The driver installation may briefly show a prompt asking to edit driver options - the script automatically selects the default (no) which is appropriate for travel router use.

### 7.4 Review Installation Log

```bash
tail -f /var/log/travel-router-install.log
```

Press `Ctrl+C` to exit log viewer.

## Phase 8: Testing

### 8.1 Check System Status

```bash
bash scripts/router-status.sh
```

All services should show ✓ (green checkmarks).

### 8.2 Connect a Device

1. **On your laptop/phone**:
   - Look for WiFi network: **GKTravelRouter** (or your chosen name)
   - Connect using password: **CABOFUN1** (or your chosen password)

2. **Wait 30 seconds** for VPN to fully establish

3. **Test VPN connection**:
   - Visit: https://www.whatismyip.com/
   - IP should be from VPN server location (Denver area)
   - Should NOT show your real IP

4. **Test DNS leak**:
   - Visit: https://dnsleaktest.com/
   - Click "Extended test"
   - All servers should be NordVPN servers

### 8.3 Verify from Raspberry Pi

```bash
# Check external IP (should be VPN IP)
curl ifconfig.me

# Check all interfaces are up
ip addr show

# Check VPN tunnel
ip link show tun0

# Check WiFi connection
iw wlan1 link
```

## Phase 9: Usage

### 9.1 Normal Operation

The router will automatically:
- Start all services on boot
- Connect to saved WiFi networks
- Establish VPN tunnel
- Create access point

**No manual intervention needed!**

### 9.2 Connecting to New WiFi

**Via SSH** (connect to eth0 at 192.168.100.2):

```bash
ssh pi@192.168.100.2
sudo bash scripts/connect-wifi.sh "HotelWiFiName" "HotelPassword"
```

### 9.3 Changing VPN Server

```bash
ssh pi@192.168.100.2
sudo bash scripts/change-vpn.sh us9953.nordvpn.com
```

### 9.4 Checking Status

```bash
ssh pi@192.168.100.2
bash scripts/router-status.sh
```

## Troubleshooting

If something isn't working:

1. **Check the installation log**:
   ```bash
   cat /var/log/travel-router-install.log
   ```

2. **Check service status**:
   ```bash
   bash scripts/router-status.sh
   ```

3. **View real-time logs**:
   ```bash
   sudo journalctl -f
   ```

4. **Restart services**:
   ```bash
   sudo systemctl restart hostapd dnsmasq wpa_supplicant@wlan1 openvpn@nordvpn
   ```

5. **See full troubleshooting guide**: [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)

## Next Steps

- **Backup your configuration**: Important after successful setup
- **Test performance**: Run speed tests
- **Configure additional WiFi networks**: Add home, work, etc.
- **Set up monitoring**: Optional logging and alerts
- **Secure your setup**: Change passwords, review firewall rules

## Quick Reference

### Common Commands

```bash
# Check status
bash scripts/router-status.sh

# Connect to WiFi
sudo bash scripts/connect-wifi.sh "SSID" "password"

# Change VPN server
sudo bash scripts/change-vpn.sh us9952.nordvpn.com

# View logs
sudo journalctl -u openvpn@nordvpn -f

# Restart VPN
sudo systemctl restart openvpn@nordvpn

# Reboot Pi
sudo reboot
```

### Network Information

- **Access Point**: 192.168.4.1 (SSID: GKTravelRouter)
- **Management (SSH)**: 192.168.100.2 (via Ethernet)
- **DHCP Range**: 192.168.4.2 - 192.168.4.20

### Important Files

- `/etc/hostapd/hostapd.conf` - Access point config
- `/etc/dnsmasq.conf` - DHCP server config
- `/etc/wpa_supplicant/wpa_supplicant-wlan1.conf` - WiFi client config
- `/etc/openvpn/nordvpn.conf` - VPN config
- `/etc/iptables/rules.v4` - Firewall rules
- `/var/log/travel-router-install.log` - Installation log

## Support

- **Issues**: Check [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
- **Manual setup**: See [docs/MANUAL_SETUP.md](docs/MANUAL_SETUP.md)
- **NordVPN help**: [docs/NORDVPN_CREDENTIALS.md](docs/NORDVPN_CREDENTIALS.md)

---

**Congratulations!** You now have a fully functional travel VPN router. 🎉
