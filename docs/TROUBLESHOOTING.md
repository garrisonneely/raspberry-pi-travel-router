# Troubleshooting Guide

Common issues and solutions for the Raspberry Pi Travel VPN Router.

## Table of Contents

- [Service Issues](#service-issues)
- [WiFi Problems](#wifi-problems)
- [VPN Connection Issues](#vpn-connection-issues)
- [Network Connectivity](#network-connectivity)
- [Performance Issues](#performance-issues)

## Service Issues

### hostapd Won't Start

**Symptoms**: Access Point not visible, can't connect to router WiFi

**Checks**:
```bash
sudo systemctl status hostapd
sudo journalctl -u hostapd -n 50
```

**Solutions**:

1. **WiFi blocked by rfkill**:
   ```bash
   sudo rfkill unblock wifi
   sudo systemctl restart hostapd
   ```

2. **wlan0 interface not available**:
   ```bash
   ip link show wlan0
   sudo ip link set wlan0 up
   ```

3. **Configuration error**:
   ```bash
   # Test configuration
   sudo hostapd -dd /etc/hostapd/hostapd.conf
   # Look for error messages
   ```

4. **wpa_supplicant conflict**:
   ```bash
   # Ensure wlan0 not managed by wpa_supplicant
   sudo killall wpa_supplicant
   sudo systemctl restart hostapd
   ```

### dnsmasq Won't Start

**Symptoms**: Devices connect but get no IP address

**Checks**:
```bash
sudo systemctl status dnsmasq
sudo journalctl -u dnsmasq -n 50
```

**Solutions**:

1. **Port 53 already in use**:
   ```bash
   # Check what's using port 53
   sudo netstat -tulpn | grep :53
   
   # Usually systemd-resolved
   sudo systemctl disable systemd-resolved
   sudo systemctl stop systemd-resolved
   sudo systemctl restart dnsmasq
   ```

2. **Interface not ready**:
   ```bash
   # Ensure wlan0 has IP
   ip addr show wlan0
   
   # Restart dhcpcd and dnsmasq
   sudo systemctl restart dhcpcd
   sleep 3
   sudo systemctl restart dnsmasq
   ```

### wpa_supplicant@wlan1 Won't Start

**Symptoms**: Can't connect to external WiFi

**Checks**:
```bash
sudo systemctl status wpa_supplicant@wlan1
sudo journalctl -u wpa_supplicant@wlan1 -n 50
```

**Solutions**:

1. **Configuration file missing**:
   ```bash
   ls -l /etc/wpa_supplicant/wpa_supplicant-wlan1.conf
   # Should exist and be readable
   ```

2. **Wrong permissions**:
   ```bash
   sudo chmod 600 /etc/wpa_supplicant/wpa_supplicant-wlan1.conf
   sudo systemctl restart wpa_supplicant@wlan1
   ```

3. **Wrong WiFi credentials**:
   ```bash
   sudo nano /etc/wpa_supplicant/wpa_supplicant-wlan1.conf
   # Verify SSID and password
   sudo systemctl restart wpa_supplicant@wlan1
   ```

### openvpn@nordvpn Won't Start

**Symptoms**: No VPN tunnel, traffic not routed through VPN

**Checks**:
```bash
sudo systemctl status openvpn@nordvpn
sudo journalctl -u openvpn@nordvpn -n 50
```

**Solutions**:

1. **Authentication failure**:
   ```bash
   # Check credentials file
   sudo cat /etc/openvpn/nordvpn-credentials
   # Should have username on line 1, password on line 2
   
   # Verify auth-user-pass line in config
   grep auth-user-pass /etc/openvpn/nordvpn.conf
   # Should be: auth-user-pass /etc/openvpn/nordvpn-credentials
   ```

2. **Wrong credentials**:
   - Get new service credentials from NordVPN dashboard
   - Update /etc/openvpn/nordvpn-credentials
   - Restart service

3. **No internet connection**:
   ```bash
   # VPN needs internet first
   ping -c 3 8.8.8.8
   # If fails, check wlan1 connection
   ```

4. **DNS resolution issues**:
   ```bash
   # Test DNS
   nslookup nordvpn.com
   
   # Add to /etc/openvpn/nordvpn.conf if needed:
   echo "dhcp-option DNS 8.8.8.8" | sudo tee -a /etc/openvpn/nordvpn.conf
   ```

## WiFi Problems

### Can't See Access Point

**Solutions**:

1. **Check hostapd status**:
   ```bash
   sudo systemctl status hostapd
   # Should be active (running)
   ```

2. **Check wlan0 interface**:
   ```bash
   ip addr show wlan0
   # Should show 192.168.4.1
   ```

3. **Channel conflict**:
   ```bash
   # Edit hostapd config
   sudo nano /etc/hostapd/hostapd.conf
   # Try different channel (1, 6, or 11)
   channel=6
   sudo systemctl restart hostapd
   ```

### Can't Connect to External WiFi (wlan1)

**Solutions**:

1. **Check available networks**:
   ```bash
   sudo iw wlan1 scan | grep SSID
   ```

2. **Test manual connection**:
   ```bash
   sudo wpa_supplicant -i wlan1 -c /etc/wpa_supplicant/wpa_supplicant-wlan1.conf -d
   # Look for authentication errors
   ```

3. **Special characters in password**:
   ```bash
   # Use wpa_passphrase to generate proper config
   wpa_passphrase "YourSSID" "YourPassword" | sudo tee -a /etc/wpa_supplicant/wpa_supplicant-wlan1.conf
   ```

### USB WiFi Adapter Not Detected

**Symptoms**: wlan1 interface doesn't exist

**Solutions**:

1. **Check USB connection**:
   ```bash
   lsusb
   # Should see Realtek or Netgear device
   ```

2. **Check driver loaded**:
   ```bash
   lsmod | grep 8812au
   # Should show the driver
   ```

3. **Reinstall driver**:
   ```bash
   cd /tmp
   git clone https://github.com/morrownr/8812au-20210820.git
   cd 8812au-20210820
   sudo ./install-driver.sh
   sudo reboot
   ```

## VPN Connection Issues

### VPN Connects But No Internet

**Solutions**:

1. **Check routing**:
   ```bash
   ip route show
   # Should see default via tun0
   ```

2. **Check iptables**:
   ```bash
   sudo iptables -L -n -v
   sudo iptables -t nat -L -n -v
   ```

3. **Restore iptables rules**:
   ```bash
   sudo iptables-restore < /etc/iptables/rules.v4
   ```

4. **Check IP forwarding**:
   ```bash
   cat /proc/sys/net/ipv4/ip_forward
   # Should be 1
   
   # If not:
   echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward
   ```

### VPN Randomly Disconnects

**Solutions**:

1. **Check for weak WiFi signal**:
   ```bash
   iw wlan1 link
   # Check signal strength
   ```

2. **Add reconnect to OpenVPN config**:
   ```bash
   sudo nano /etc/openvpn/nordvpn.conf
   # Add these lines:
   keepalive 10 60
   persist-key
   persist-tun
   ```

3. **Check system logs**:
   ```bash
   sudo journalctl -u openvpn@nordvpn -f
   # Watch for disconnection messages
   ```

### DNS Leaks

**Check for leaks**:
```bash
# From a connected client device, visit:
# https://dnsleaktest.com/

# Or from Pi:
dig +short myip.opendns.com @resolver1.opendns.com
# Should show VPN IP, not your real IP
```

**Solutions**:

1. **Force DNS through VPN**:
   ```bash
   sudo nano /etc/openvpn/nordvpn.conf
   # Add:
   dhcp-option DNS 103.86.96.100
   dhcp-option DNS 103.86.99.100
   ```

2. **Update dnsmasq**:
   ```bash
   sudo nano /etc/dnsmasq.conf
   # Change DNS servers:
   server=103.86.96.100
   server=103.86.99.100
   sudo systemctl restart dnsmasq
   ```

## NetworkManager Conflicts (Desktop OS)

### System Becomes Unresponsive After Reboot

**Symptoms**: 
- Pi responds to 3-4 pings then stops
- SSH cannot connect or disconnects immediately
- Ethernet becomes unreliable

**Cause**: NetworkManager and systemd-networkd both trying to manage eth0

**Solution - Use Reset Mode**:
```bash
# SSH in via Ethernet (192.168.100.2) if possible
# Or connect monitor/keyboard to Pi

# Run installation script in reset mode
cd ~/raspberry-pi-travel-router
sudo bash scripts/install.sh
# Press 'r' within 10 seconds when prompted

# Then reboot
sudo reboot

# After reboot, run installation again (fresh start)
sudo bash scripts/install.sh
# Press Enter for Install mode
```

**Manual Fix** (if reset doesn't work):
```bash
# Stop systemd-networkd (conflicts with NetworkManager on Desktop OS)
sudo systemctl stop systemd-networkd
sudo systemctl disable systemd-networkd

# Remove conflicting config
sudo rm -f /etc/systemd/network/10-eth0.network

# Configure eth0 via NetworkManager instead
sudo nmcli connection modify "Wired connection 1" ipv4.addresses 192.168.100.2/24
sudo nmcli connection modify "Wired connection 1" ipv4.method manual
sudo nmcli connection up "Wired connection 1"

# Reboot
sudo reboot
```

### Wireless Interfaces Not Starting

**Symptoms**: hostapd or wpa_supplicant won't start, interfaces remain down

**Cause**: NetworkManager still managing wlan0/wlan1

**Check**:
```bash
nmcli device status
# Should show wlan0 and wlan1 as "unmanaged"
```

**Solution**:
```bash
# Force NetworkManager to release wireless interfaces
sudo nmcli device set wlan0 managed no
sudo nmcli device set wlan1 managed no

# Create persistent unmanaged config
sudo mkdir -p /etc/NetworkManager/conf.d
sudo bash -c 'cat > /etc/NetworkManager/conf.d/unmanaged.conf << "EOF"
[keyfile]
unmanaged-devices=interface-name:wlan0;interface-name:wlan1
EOF'

# Reload NetworkManager
sudo nmcli general reload

# Restart services
sudo systemctl restart hostapd
sudo systemctl restart wpa_supplicant@wlan1
```

## Network Connectivity

### Clients Get IP But No Internet

**Solutions**:

1. **Check VPN status**:
   ```bash
   sudo systemctl status openvpn@nordvpn
   ip link show tun0
   ```

2. **Test from Pi itself**:
   ```bash
   ping -c 3 8.8.8.8
   curl ifconfig.me
   ```

3. **Check NAT rules**:
   ```bash
   sudo iptables -t nat -L POSTROUTING -n -v
   # Should see MASQUERADE rule for tun0
   ```

### Slow Performance

**Solutions**:

1. **Check VPN server location**:
   ```bash
   # Change to closer server
   sudo bash scripts/change-vpn.sh us9952.nordvpn.com
   ```

2. **Try TCP instead of UDP**:
   ```bash
   # Use config from ovpn_tcp instead
   sudo cp /etc/openvpn/ovpn_tcp/us9952.nordvpn.com.tcp.ovpn /etc/openvpn/nordvpn.conf
   # Update auth line
   sudo sed -i 's/^auth-user-pass.*/auth-user-pass \/etc\/openvpn\/nordvpn-credentials/' /etc/openvpn/nordvpn.conf
   sudo systemctl restart openvpn@nordvpn
   ```

3. **Check WiFi signal**:
   ```bash
   iw wlan1 link
   # Low signal = slow performance
   ```

### Can't SSH Into Pi

**Solutions**:

1. **Check Ethernet connection**:
   ```bash
   ip addr show eth0
   # Should show 192.168.100.2
   ```

2. **Check SSH service**:
   ```bash
   sudo systemctl status ssh
   ```

3. **Check firewall**:
   ```bash
   sudo iptables -L INPUT -n -v
   # Should allow SSH on eth0
   ```

## Performance Issues

### High CPU Usage

**Check**:
```bash
top
# Look for high CPU processes
```

**Common causes**:
- OpenVPN encryption overhead (normal, 10-30%)
- hostapd (should be <5%)
- Compiling/building (if still installing)

### High Memory Usage

**Check**:
```bash
free -h
```

**Solutions**:
- Raspberry Pi 4 with 2GB+ RAM is recommended
- Close unnecessary services
- Reboot if memory leak suspected

### WiFi Range Issues

**Solutions**:

1. **Check channel**:
   ```bash
   sudo nano /etc/hostapd/hostapd.conf
   # Try channel 1, 6, or 11
   # Avoid channels with interference
   ```

2. **USB WiFi adapter positioning**:
   - Use USB extension cable
   - Position adapter away from Pi
   - Avoid metal enclosures

## Complete System Reset

If all else fails:

```bash
# Stop all services
sudo systemctl stop hostapd dnsmasq wpa_supplicant@wlan1 openvpn@nordvpn

# Restore backups
sudo cp /etc/dhcpcd.conf.backup /etc/dhcpcd.conf
sudo cp /etc/dnsmasq.conf.backup /etc/dnsmasq.conf

# Reboot
sudo reboot

# Run install script again
sudo bash scripts/install.sh
```

## Getting Help

### Collect Diagnostic Information

```bash
# Run status script
bash scripts/router-status.sh > status.txt

# Collect service logs
sudo journalctl -u hostapd -n 100 > logs.txt
sudo journalctl -u dnsmasq -n 100 >> logs.txt
sudo journalctl -u wpa_supplicant@wlan1 -n 100 >> logs.txt
sudo journalctl -u openvpn@nordvpn -n 100 >> logs.txt

# Network configuration
ip addr > network.txt
ip route >> network.txt
sudo iptables -L -n -v >> network.txt
```

### Reset Installation Without Re-imaging

If you need to start completely fresh without re-flashing the SD card:

```bash
cd ~/raspberry-pi-travel-router
sudo bash scripts/install.sh
# Press 'r' within 10 seconds when prompted for Reset mode

# After reset completes, reboot
sudo reboot

# Then run installation again
cd ~/raspberry-pi-travel-router
sudo bash scripts/install.sh
# Press Enter for Install mode
```

**Reset mode cleans up:**
- ✓ Stops and disables all services
- ✓ Removes DKMS driver modules
- ✓ Deletes all configuration files
- ✓ Restores backup configurations
- ✓ Clears iptables rules
- ✓ Resets NetworkManager to defaults
- ✓ Removes state tracking file

This is much faster than re-imaging and preserves your base OS configuration.

### Useful Commands

```bash
# Complete service restart
sudo systemctl restart hostapd dnsmasq wpa_supplicant@wlan1 openvpn@nordvpn

# Watch logs in real-time
sudo journalctl -f

# Network interface status
iwconfig
ifconfig

# Check processes
ps aux | grep -E "hostapd|dnsmasq|wpa_supplicant|openvpn"
```
