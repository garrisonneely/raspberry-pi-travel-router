# Manual Setup Guide

This guide provides detailed step-by-step instructions for manually configuring your Raspberry Pi as a travel VPN router. Use this if you want to understand each component or need to customize the setup.

## Prerequisites

- Raspberry Pi 4 Model B with Raspberry Pi OS Lite installed
- Netgear A7000 USB WiFi adapter (or compatible 8812AU chipset)
- SSH access to the Pi
- Active NordVPN subscription

## Table of Contents

1. [System Preparation](#1-system-preparation)
2. [USB WiFi Driver Installation](#2-usb-wifi-driver-installation)
3. [Network Interface Configuration](#3-network-interface-configuration)
4. [Access Point Setup](#4-access-point-setup)
5. [DHCP Server Configuration](#5-dhcp-server-configuration)
6. [WiFi Client Configuration](#6-wifi-client-configuration)
7. [VPN Setup](#7-vpn-setup)
8. [Routing and Firewall](#8-routing-and-firewall)
9. [Startup Scripts](#9-startup-scripts)
10. [Service Enablement](#10-service-enablement)
11. [Testing and Verification](#11-testing-and-verification)

---

## 1. System Preparation

### Update System Packages

```bash
sudo apt update
sudo apt upgrade -y
```

### Install Required Packages

```bash
sudo apt install -y git dkms build-essential hostapd dnsmasq \
    openvpn unzip wget iptables iptables-persistent rfkill \
    net-tools wireless-tools
```

### Basic Configuration

```bash
# Run raspi-config
sudo raspi-config

# Recommended settings:
# - Change password
# - Set locale and timezone
# - Expand filesystem
# - Enable SSH (if not already enabled)
```

---

## 2. USB WiFi Driver Installation

The Netgear A7000 uses the Realtek RTL8812AU chipset.

### Clone and Install Driver

```bash
cd /tmp
git clone https://github.com/morrownr/8812au-20210820.git
cd 8812au-20210820
sudo ./install-driver.sh
```

### Reboot and Verify

```bash
sudo reboot

# After reboot, verify wlan1 exists
ip link show wlan1
```

You should see output showing the wlan1 interface.

---

## 3. Network Interface Configuration

Configure static IP addresses for the router interfaces.

### Edit dhcpcd Configuration

```bash
sudo nano /etc/dhcpcd.conf
```

Add to the end of the file:

```conf
# Travel Router Configuration

# Access Point Interface (wlan0)
interface wlan0
    static ip_address=192.168.4.1/24
    nohook wpa_supplicant
    nohook dhcp

# Management Interface (eth0)
interface eth0
    static ip_address=192.168.100.2/24

# WiFi Client Interface (wlan1)
interface wlan1
    env wpa_supplicant_conf=/etc/wpa_supplicant/wpa_supplicant-wlan1.conf
```

Save with `Ctrl+O`, `Enter`, then exit with `Ctrl+X`.

---

## 4. Access Point Setup

Configure hostapd to create a WiFi access point on wlan0.

### Create hostapd Configuration

```bash
sudo nano /etc/hostapd/hostapd.conf
```

Add the following (customize SSID and password):

```conf
interface=wlan0
driver=nl80211
ssid=GKTravelRouter
hw_mode=g
channel=7
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=CABOFUN1
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
```

**Security Note**: Change `ssid` and `wpa_passphrase` to your preferred values. Password must be 8-63 characters.

### Configure hostapd Daemon

```bash
sudo nano /etc/default/hostapd
```

Add or modify the line:

```conf
DAEMON_CONF="/etc/hostapd/hostapd.conf"
```

---

## 5. DHCP Server Configuration

Configure dnsmasq to provide DHCP and DNS services to connected clients.

### Backup Existing Configuration

```bash
sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.backup
```

### Create New Configuration

```bash
sudo nano /etc/dnsmasq.conf
```

Add:

```conf
# Travel Router DHCP Configuration
interface=wlan0
dhcp-range=192.168.4.2,192.168.4.20,255.255.255.0,24h
domain=wlan
address=/gw.wlan/192.168.4.1

# DNS servers (using Google DNS)
server=8.8.8.8
server=8.8.4.4

# Logging for troubleshooting
log-queries
log-dhcp
```

---

## 6. WiFi Client Configuration

Configure wpa_supplicant to connect wlan1 to external WiFi networks.

### Create wpa_supplicant Configuration

```bash
sudo nano /etc/wpa_supplicant/wpa_supplicant-wlan1.conf
```

Add (replace with your WiFi details):

```conf
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=US

network={
    ssid="YourWiFiNetwork"
    psk="YourWiFiPassword"
    priority=1
}
```

**Note**: For additional networks, add more `network={}` blocks with different priorities.

### Set Proper Permissions

```bash
sudo chmod 600 /etc/wpa_supplicant/wpa_supplicant-wlan1.conf
```

---

## 7. VPN Setup

Configure OpenVPN to connect to NordVPN.

### Download NordVPN Configurations

```bash
cd /tmp
wget https://downloads.nordcdn.com/configs/archives/servers/ovpn.zip
sudo unzip ovpn.zip -d /etc/openvpn/
```

### Create Credentials File

First, get your NordVPN service credentials from https://my.nordaccount.com/ (see [NORDVPN_CREDENTIALS.md](NORDVPN_CREDENTIALS.md) for detailed instructions).

```bash
sudo nano /etc/openvpn/nordvpn-credentials
```

Add your credentials (replace with your actual credentials):

```
your_service_username
your_service_password
```

### Set Credentials File Permissions

```bash
sudo chmod 600 /etc/openvpn/nordvpn-credentials
```

### Choose and Configure VPN Server

For Denver area, use servers like us9952, us9953, us9954:

```bash
# Copy your chosen server config
sudo cp /etc/openvpn/ovpn_udp/us9952.nordvpn.com.udp.ovpn /etc/openvpn/nordvpn.conf
```

### Update Configuration to Use Credentials

```bash
sudo nano /etc/openvpn/nordvpn.conf
```

Find the line:
```
auth-user-pass
```

Change it to:
```
auth-user-pass /etc/openvpn/nordvpn-credentials
```

You can also add these lines for better reliability:
```
keepalive 10 60
persist-key
persist-tun
```

---

## 8. Routing and Firewall

Configure IP forwarding and iptables rules to route traffic through the VPN.

### Enable IP Forwarding

```bash
sudo nano /etc/sysctl.conf
```

Uncomment or add:
```
net.ipv4.ip_forward=1
```

Apply immediately:
```bash
sudo sysctl -p
```

### Configure iptables Rules

```bash
# Flush existing rules
sudo iptables -F
sudo iptables -t nat -F
sudo iptables -X

# NAT configuration - Route through VPN
sudo iptables -t nat -A POSTROUTING -o tun0 -j MASQUERADE

# Forward traffic from Access Point to VPN
sudo iptables -A FORWARD -i wlan0 -o tun0 -j ACCEPT
sudo iptables -A FORWARD -i tun0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT

# Allow SSH on management interface
sudo iptables -A INPUT -i eth0 -p tcp --dport 22 -j ACCEPT

# Block traffic from WiFi clients to management network (security)
sudo iptables -A FORWARD -i wlan0 -o eth0 -j DROP
```

### Save iptables Rules

```bash
sudo mkdir -p /etc/iptables
sudo iptables-save | sudo tee /etc/iptables/rules.v4
```

Make iptables-persistent non-interactive:
```bash
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections
```

---

## 9. Startup Scripts

Create a startup script to ensure proper initialization on boot.

### Create rc.local

```bash
sudo nano /etc/rc.local
```

Add:

```bash
#!/bin/bash
# Travel Router Startup Script

# Restore iptables rules
iptables-restore < /etc/iptables/rules.v4

# Ensure rfkill is unblocked for WiFi
rfkill unblock wifi
rfkill unblock all

# Ensure IP forwarding is enabled
echo 1 > /proc/sys/net/ipv4/ip_forward

# Log startup
echo "$(date): Travel router services started" >> /var/log/travel-router-startup.log

exit 0
```

### Make Executable

```bash
sudo chmod +x /etc/rc.local
```

### Enable rc-local Service

```bash
sudo systemctl enable rc-local
```

---

## 10. Service Enablement

Enable and start all required services.

### Unmask and Enable hostapd

```bash
sudo systemctl unmask hostapd
sudo systemctl enable hostapd
```

### Enable Other Services

```bash
sudo systemctl enable dnsmasq
sudo systemctl enable wpa_supplicant@wlan1
sudo systemctl enable openvpn@nordvpn
```

### Unblock WiFi

```bash
sudo rfkill unblock wifi
sudo rfkill unblock all
```

### Restart Network Services

```bash
sudo systemctl restart dhcpcd
sleep 3
sudo systemctl start hostapd
sudo systemctl start dnsmasq
sudo systemctl start wpa_supplicant@wlan1
sleep 5
sudo systemctl start openvpn@nordvpn
```

---

## 11. Testing and Verification

### Check Service Status

```bash
sudo systemctl status hostapd
sudo systemctl status dnsmasq
sudo systemctl status wpa_supplicant@wlan1
sudo systemctl status openvpn@nordvpn
```

All services should show "active (running)".

### Verify Network Interfaces

```bash
ip addr show
```

You should see:
- **wlan0**: 192.168.4.1
- **wlan1**: IP from external WiFi
- **eth0**: 192.168.100.2
- **tun0**: VPN tunnel IP (10.x.x.x typically)

### Check WiFi Connection

```bash
iw wlan1 link
```

Should show connection to your external WiFi network.

### Test VPN Connection

```bash
curl ifconfig.me
```

This should return your VPN server's IP address, NOT your real IP.

### Test from Client Device

1. Connect a device to your "GKTravelRouter" WiFi
2. Open a browser and visit: https://www.whatismyip.com/
3. Verify the IP shown is your VPN server's IP
4. Test DNS leak: https://dnsleaktest.com/

### Check Routing

```bash
ip route show
```

Default route should go through tun0.

### View Logs

```bash
# All services
sudo journalctl -f

# Specific service
sudo journalctl -u openvpn@nordvpn -f
```

---

## Common Post-Setup Tasks

### Add Multiple WiFi Networks

Edit the wpa_supplicant configuration:

```bash
sudo nano /etc/wpa_supplicant/wpa_supplicant-wlan1.conf
```

Add networks with priorities:

```conf
network={
    ssid="HomeWiFi"
    psk="homepassword"
    priority=3
}

network={
    ssid="WorkWiFi"
    psk="workpassword"
    priority=2
}

network={
    ssid="HotelWiFi"
    psk="hotelpassword"
    priority=1
}
```

Higher priority = preferred network.

### Change VPN Server

```bash
# List available servers
ls /etc/openvpn/ovpn_udp/us*.udp.ovpn

# Copy new server config
sudo cp /etc/openvpn/ovpn_udp/us9953.nordvpn.com.udp.ovpn /etc/openvpn/nordvpn.conf

# Update auth line
sudo sed -i 's/^auth-user-pass.*/auth-user-pass \/etc\/openvpn\/nordvpn-credentials/' /etc/openvpn/nordvpn.conf

# Restart VPN
sudo systemctl restart openvpn@nordvpn
```

### View Connected Clients

```bash
# Connected to Access Point
iw dev wlan0 station dump

# DHCP leases
cat /var/lib/misc/dnsmasq.leases
```

---

## Maintenance

### Regular Updates

```bash
sudo apt update
sudo apt upgrade -y
```

### Backup Configuration

```bash
# Backup important configs
sudo tar -czf ~/router-backup-$(date +%Y%m%d).tar.gz \
    /etc/hostapd/hostapd.conf \
    /etc/dnsmasq.conf \
    /etc/wpa_supplicant/wpa_supplicant-wlan1.conf \
    /etc/openvpn/nordvpn.conf \
    /etc/openvpn/nordvpn-credentials \
    /etc/dhcpcd.conf \
    /etc/iptables/rules.v4 \
    /etc/rc.local
```

### Monitor Performance

```bash
# CPU and memory
top

# Network throughput
sudo iftop

# Service status
bash scripts/router-status.sh
```

---

## Next Steps

- Review [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues
- Create helper scripts for common tasks
- Set up monitoring and logging
- Test performance and optimize settings

---

## Security Recommendations

1. **Change Default Passwords**: Update both SSH and WiFi passwords
2. **Keep System Updated**: Regularly run apt update/upgrade
3. **Secure Credentials**: Ensure proper file permissions (600) on sensitive files
4. **Monitor Logs**: Regularly check /var/log for unusual activity
5. **Use Strong WiFi Password**: Minimum 12 characters, mixed case, numbers, symbols
6. **Limit SSH Access**: Only allow from trusted networks (eth0)
7. **Disable Unused Services**: Remove any services you don't need
8. **Regular Backups**: Back up your configuration regularly
