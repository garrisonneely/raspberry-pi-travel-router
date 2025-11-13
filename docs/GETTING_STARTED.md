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
✓ Netgear A7000 USB WiFi Adapter (RTL8814AU chipset)  
✓ MicroSD card (32GB+, Class 10)  
✓ USB-C power supply (official RPi 5V/3A recommended)  
✓ Ethernet cable  
✓ Computer for flashing and SSH

### 1.2 Download Raspberry Pi OS

1. Download **Raspberry Pi Imager**: https://www.raspberrypi.com/software/
2. Or download **Raspberry Pi OS** directly: https://www.raspberrypi.com/software/operating-systems/

**Recommended**: 
- **Desktop OS** for troubleshooting with GUI access (easier debugging)
- **Lite OS** for production use (better performance, lower resource usage)

Both versions are fully supported by the installation script.

## Phase 2: Flash the Operating System

### 2.1 Using Raspberry Pi Imager (Recommended)

1. **Launch Raspberry Pi Imager**
2. Click **"Choose Device"** → Select "Raspberry Pi 4"
3. Click **"Choose OS"** → 
   - For Desktop: "Raspberry Pi OS (64-bit)"
   - For Lite: "Raspberry Pi OS (other)" → "Raspberry Pi OS Lite (64-bit)"
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

**Installation Modes:**

The script offers two modes at startup:
- **Install Mode** (default): Normal installation - press Enter or wait 10 seconds
- **Reset Mode**: Clean up previous installation - press 'r' within 10 seconds

**Reset mode will:**
- Stop and disable all services
- Remove driver modules
- Clean up all configuration files
- Restore backups
- Clear iptables rules
- Reset NetworkManager to defaults

Use reset mode if you need to start fresh without re-imaging the SD card.

### 7.3 Installation Phases

The installation script runs through 12 distinct phases:

**Phase 1: System Preparation - BEGIN**
- Updates package lists and system packages
- Installs required packages (git, dkms, hostapd, dnsmasq, openvpn, etc.)
- **🔧 ETHERNET STATIC IP CONFIGURED**: eth0 set to 192.168.100.2/24 via NetworkManager
- **Note**: Uses NetworkManager for modern, Desktop OS-compatible network management
- **Recommended**: After Phase 1, connect your computer to the Pi via Ethernet cable
- This provides reliable SSH access for the remaining phases
- Time: 2-5 minutes
- Network: Connected via WiFi DHCP initially, then Ethernet 192.168.100.2

**Phase 2: USB WiFi Driver Installation - BEGIN**
- Auto-detects USB WiFi adapter chipset (RTL8812AU or RTL8814AU)
- **Note**: Netgear A7000 uses RTL8814AU chipset
- Clones and compiles correct driver for your adapter
- Installs driver via DKMS
- Time: 10-15 minutes (longest phase)
- **⚠️ REBOOT REQUIRED**: After this phase, system will reboot to load the driver
- **🔌 SWITCH TO ETHERNET**: After reboot, connect via Ethernet at 192.168.100.2
- Command after reboot: `ssh pi@192.168.100.2`
- After reboot: SSH back in and re-run `sudo bash scripts/install.sh` to continue

**Phase 3: Network Interface Configuration - BEGIN**
- Configures network interface settings
- Sets up wlan0 (Access Point): 192.168.4.1/24
- Sets up eth0 (Management): 192.168.100.2/24 (already active from Phase 1 via NetworkManager)
- Configures wlan1 (WiFi client) interface
- **⚠️ IMPORTANT**: Configuration is written but NOT applied yet (except eth0 which is already set)
- Remaining static IPs will be applied when services start in Phase 11
- Time: < 1 minute

**Phase 4: Access Point Configuration - BEGIN**
- Prompts for Access Point SSID (default: GKTravelRouter)
- Prompts for Access Point password (minimum 8 characters)
- Creates hostapd configuration for wlan0
- Time: < 1 minute

**Phase 5: DHCP Server Configuration - BEGIN**
- Configures dnsmasq for DHCP and DNS services
- Sets up 192.168.4.2-192.168.4.20 address pool
- Configures DNS forwarding to Google DNS (8.8.8.8, 8.8.4.4)
- Time: < 1 minute

**Phase 6: WiFi Client Configuration - BEGIN**
- Prompts for WiFi network SSID to connect to
- Prompts for WiFi password
- Creates wpa_supplicant configuration for wlan1
- Time: < 1 minute

**Phase 7: VPN Configuration - BEGIN**
- Downloads NordVPN OpenVPN configuration files
- Prompts for VPN server selection (default: us9952.nordvpn.com)
- Prompts for NordVPN service credentials
- Creates VPN configuration with credentials
- Time: 1-2 minutes

**Phase 8: Routing and Firewall Configuration - BEGIN**
- Enables IP forwarding
- Configures iptables NAT rules
- Routes traffic from wlan0 → tun0 (VPN tunnel)
- Blocks wlan0 → eth0 traffic for security
- Saves firewall rules
- Time: < 1 minute

**Phase 9: Startup Script Configuration - BEGIN**
- Creates /etc/rc.local for startup tasks
- Configures automatic iptables restoration
- Enables WiFi with rfkill
- Time: < 1 minute

**Phase 10: Enabling Services - BEGIN**
- Enables hostapd (Access Point)
- Enables dnsmasq (DHCP/DNS)
- Enables wpa_supplicant@wlan1 (WiFi client)
- Enables openvpn@nordvpn (VPN)
- Time: < 1 minute

**Phase 11: Starting Services - BEGIN**
- Configures NetworkManager to not manage wireless interfaces (wlan0/wlan1)
- Starts all configured services
- Establishes WiFi connection on wlan1
- **Requests DHCP lease for wlan1** (critical for internet access)
- Brings up VPN tunnel on tun0
- Verifies eth0 static IP (192.168.100.2) is still configured
- **Note**: You should already be connected via Ethernet at 192.168.100.2 from Phase 2 reboot
- Time: 1-2 minutes (VPN connection may take 10-30 seconds)

**Phase 12: System Verification - BEGIN**
- Checks all service statuses
- Verifies network interfaces are up
- Tests internet connectivity
- **Runs comprehensive health check** with detailed diagnostics
- Reports any errors with troubleshooting steps
- Reports any issues
- Time: < 1 minute

**Total Installation Time**: 20-40 minutes (including driver compilation and reboot)

**Expected Reboots**: 1 reboot after Phase 2 (driver installation)

### 7.4 Important: Connection Switching During Installation

**⚠️ Critical Information:**

The installation uses **two connection methods** for reliability:

**Phase 1: WiFi DHCP** (Initial Connection)
- Connect via your router's DHCP-assigned IP (e.g., 192.168.1.100)
- Run installation script, which configures Ethernet with static IP 192.168.100.2
- Phase 1 completes in a few minutes

**Phase 2+: Ethernet 192.168.100.2** (After Reboot)
- After Phase 2 reboot, **switch your SSH connection to Ethernet**:
  ```bash
  ssh pi@192.168.100.2
  ```
- Connect Ethernet cable between your computer (set to 192.168.100.1) and Pi
- Complete all remaining phases via this stable Ethernet connection
- This prevents WiFi configuration changes from disrupting your SSH session

**Why this approach?**
- Phases 3-11 configure WiFi interfaces (wlan0, wlan1)
- If connected via WiFi during these phases, you could lose access
- Ethernet provides a separate, stable management interface
- You can always access the Pi at 192.168.100.2 regardless of WiFi state

### 7.5 Monitoring Installation Progress

You can monitor the installation in real-time by watching the log file. Open a second SSH session and run:

```bash
tail -f /var/log/travel-router-install.log
```

You'll see each phase marked with:
- `PHASE X: Description - BEGIN` when starting
- `PHASE X: Description - COMPLETE` when finished

This helps you track progress during the long driver compilation in Phase 2.

### 7.6 During Installation

The script will automatically handle most prompts. You'll be asked to provide:
- Access Point SSID and password (Phase 4)
- WiFi network to connect to (Phase 6)
- NordVPN server and credentials (Phase 7)

**Note**: The driver installation may briefly show a prompt asking to edit driver options - the script automatically selects the default (no) which is appropriate for travel router use.

### 7.7 After Driver Installation (Phase 2)

**IMPORTANT**: Phase 2 (driver installation) requires a system reboot. When you see:

```
[SUCCESS] PHASE 2: USB WiFi Driver Installation - COMPLETE
System will reboot to load the driver...
After reboot, SSH back in and re-run: sudo bash ~/raspberry-pi-travel-router/scripts/install.sh
```

The system will reboot. After reboot:

1. Wait 30-60 seconds for the Pi to boot
2. Reconnect via SSH (use the same IP you used before)
3. Re-run the installation script:
   ```bash
   cd ~/raspberry-pi-travel-router
   sudo bash scripts/install.sh
   ```
4. The script will automatically detect that Phase 2 is complete and continue from Phase 3

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

1. **Run the health check first**:
   ```bash
   sudo bash scripts/router-health.sh
   ```
   This provides detailed diagnostics and specific troubleshooting steps.

2. **wlan1 has no IP address** (Common issue):
   If installation completes but you have no internet:
   ```bash
   # Quick fix
   sudo bash scripts/fix-wlan1-dhcp.sh
   
   # Or manually
   sudo apt install -y isc-dhcp-client
   sudo dhclient wlan1
   ```

3. **Check the installation log**:
   ```bash
   cat /var/log/travel-router-install.log
   ```

4. **Check service status**:
   ```bash
   bash scripts/router-status.sh
   ```

5. **Collect detailed diagnostics**:
   ```bash
   sudo bash scripts/collect-diagnostics.sh
   ```

6. **View real-time logs**:
   ```bash
   sudo journalctl -f
   ```

7. **Restart services**:
   ```bash
   sudo systemctl restart hostapd dnsmasq wpa_supplicant@wlan1 openvpn@nordvpn
   ```

8. **See full troubleshooting guide**: [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)

## Next Steps

- **Backup your configuration**: Important after successful setup
- **Test performance**: Run speed tests
- **Configure additional WiFi networks**: Add home, work, etc.
- **Set up monitoring**: Optional logging and alerts
- **Secure your setup**: Change passwords, review firewall rules

## Quick Reference

### Common Commands

```bash
# Run health check (comprehensive diagnostics)
sudo bash scripts/router-health.sh

# Fix wlan1 DHCP issue
sudo bash scripts/fix-wlan1-dhcp.sh

# Collect detailed diagnostics
sudo bash scripts/collect-diagnostics.sh

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
