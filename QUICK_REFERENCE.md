# Quick Reference Card

Keep this handy while traveling with your VPN router!

## 🔌 Network Information

| Interface | Purpose | IP Address |
|-----------|---------|------------|
| **wlan0** | Access Point (Your WiFi) | 192.168.4.1 |
| **wlan1** | WiFi Client (Hotel/Public) | DHCP from network |
| **eth0** | Management (SSH Only) | 192.168.100.2 |
| **tun0** | VPN Tunnel | 10.x.x.x (assigned) |

## 📶 WiFi Access Point

**SSID**: GKTravelRouter (or your custom name)  
**Password**: CABOFUN1 (or your custom password)  
**DHCP Range**: 192.168.4.2 - 192.168.4.20

## 🔐 SSH Access

```bash
# Via Ethernet cable
ssh pi@192.168.100.2

# Default username: pi
# Password: [your password]
```

## ⚡ Quick Commands

### Check System Status
```bash
bash scripts/router-status.sh
```

### Connect to New WiFi
```bash
sudo bash scripts/connect-wifi.sh "WiFiName" "Password"
```

### Change VPN Server
```bash
# Denver area servers: us9952, us9953, us9954
sudo bash scripts/change-vpn.sh us9952.nordvpn.com
```

### Restart Services
```bash
# Restart VPN
sudo systemctl restart openvpn@nordvpn

# Restart Access Point
sudo systemctl restart hostapd

# Restart all services
sudo systemctl restart hostapd dnsmasq wpa_supplicant@wlan1 openvpn@nordvpn
```

### View Logs
```bash
# VPN logs (real-time)
sudo journalctl -u openvpn@nordvpn -f

# All services
sudo journalctl -f

# Installation log
cat /var/log/travel-router-install.log
```

### Check VPN Connection
```bash
# Show external IP (should be VPN IP)
curl ifconfig.me

# Check VPN tunnel exists
ip link show tun0

# Check VPN service status
sudo systemctl status openvpn@nordvpn
```

### Network Diagnostics
```bash
# Show all interfaces
ip addr show

# Check WiFi connection
iw wlan1 link

# Show routing table
ip route show

# Test internet
ping -c 3 8.8.8.8
```

## 🔧 Common Fixes

### WiFi Blocked
```bash
sudo rfkill unblock wifi
sudo systemctl restart hostapd
```

### No Internet After VPN Restart
```bash
sudo iptables-restore < /etc/iptables/rules.v4
```

### Services Won't Start
```bash
# Reboot the Pi
sudo reboot
```

## 📝 Important File Locations

```
/etc/hostapd/hostapd.conf                      # Access Point config
/etc/dnsmasq.conf                              # DHCP server config
/etc/wpa_supplicant/wpa_supplicant-wlan1.conf  # WiFi client config
/etc/openvpn/nordvpn.conf                      # VPN config
/etc/openvpn/nordvpn-credentials               # VPN credentials
/etc/iptables/rules.v4                         # Firewall rules
/var/log/travel-router-install.log             # Installation log
```

## 🚨 Emergency Recovery

### Complete Service Restart
```bash
cd ~/raspberry-pi-travel-router
sudo bash scripts/install.sh
# Choose to skip driver installation if already working
```

### Restore from Backup
```bash
# If you created a backup
cd ~
sudo tar -xzf router-backup-YYYYMMDD.tar.gz -C /
sudo reboot
```

## 🌐 Verification URLs

- **What's My IP**: https://www.whatismyip.com/
- **DNS Leak Test**: https://dnsleaktest.com/
- **Speed Test**: https://www.speedtest.net/

## 📞 Getting Help

1. Check status: `bash scripts/router-status.sh`
2. View logs: `sudo journalctl -f`
3. Read troubleshooting: `docs/TROUBLESHOOTING.md`
4. Check NordVPN status: https://nordvpn.com/servers/tools/

## 🔒 Security Reminders

- ✅ Changed default SSH password
- ✅ Changed WiFi password
- ✅ Management only via Ethernet
- ✅ VPN credentials secured (600 permissions)
- ✅ Regular system updates (`sudo apt update && sudo apt upgrade`)

## 🎯 Performance Tips

- Use VPN server geographically close to you
- Try different channels if WiFi is slow (1, 6, or 11)
- Use 5GHz networks when available
- Keep Pi well-ventilated
- Consider UDP vs TCP for VPN (UDP usually faster)

## 📊 Typical Speeds

- **Without VPN**: Full WiFi speed
- **With VPN**: 60-80% of WiFi speed (encryption overhead)
- **Factors**: VPN server load, distance, time of day

## 🔄 Regular Maintenance

```bash
# Monthly updates
sudo apt update && sudo apt upgrade -y

# Check disk space
df -h

# Check memory usage
free -h

# Restart if running for weeks
sudo reboot
```

## 📱 Travel Checklist

Before you go:
- [ ] Router powered on and working
- [ ] Ethernet cable packed
- [ ] Power adapter packed
- [ ] Know your WiFi credentials
- [ ] Have PuTTY/SSH client on laptop
- [ ] Backup of configuration saved elsewhere

## 🆘 Quick Troubleshooting

| Problem | Quick Fix |
|---------|-----------|
| Can't see WiFi | `sudo rfkill unblock wifi; sudo systemctl restart hostapd` |
| Can't connect to WiFi | Check password, verify SSID in hostapd.conf |
| Connected but no internet | Check VPN: `sudo systemctl status openvpn@nordvpn` |
| VPN won't connect | Verify credentials, check internet: `ping 8.8.8.8` |
| Slow performance | Change VPN server or WiFi channel |
| Can't SSH | Check Ethernet cable, verify 192.168.100.2 |

---

**Save this file to your phone or laptop for quick reference while traveling!**
