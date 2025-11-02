# Travel VPN Router Setup Checklist

Use this checklist to track your progress through the setup process.

## Pre-Setup Preparation

- [ ] Raspberry Pi 4 Model B available
- [ ] Netgear A7000 USB WiFi adapter available
- [ ] MicroSD card (32GB+, Class 10) available
- [ ] USB-C power supply available
- [ ] Ethernet cable available
- [ ] Computer with PuTTY or SSH client
- [ ] Active NordVPN subscription

## Phase 1: OS Installation

- [ ] Download Raspberry Pi Imager
- [ ] Flash Raspberry Pi OS Lite (64-bit) to microSD
- [ ] Enable SSH (via Imager settings or ssh file)
- [ ] Configure initial settings (hostname, password, WiFi)
- [ ] Eject microSD card safely

## Phase 2: Hardware Setup

- [ ] Insert microSD card into Raspberry Pi
- [ ] Connect Netgear A7000 USB adapter
- [ ] Connect Ethernet cable
- [ ] Power on Raspberry Pi
- [ ] Wait 1-2 minutes for boot

## Phase 3: Initial Connection

- [ ] Find Raspberry Pi IP address
- [ ] Connect via SSH using PuTTY
- [ ] Login successful
- [ ] Change default password (if not done in imaging)
- [ ] Run `sudo raspi-config`
  - [ ] Set hostname to "travelrouter"
  - [ ] Set timezone
  - [ ] Expand filesystem
  - [ ] Reboot

## Phase 4: System Updates

- [ ] Reconnect after reboot
- [ ] Run `sudo apt update`
- [ ] Run `sudo apt upgrade -y`
- [ ] Wait for updates to complete

## Phase 5: NordVPN Credentials

- [ ] Visit https://my.nordaccount.com/
- [ ] Navigate to Services → NordVPN → Manual Setup
- [ ] Generate or copy service username
- [ ] Generate or copy service password
- [ ] Save credentials in secure location (temporarily)

## Phase 6: Transfer Installation Files

Choose one method:

### Method A: Git Clone
- [ ] SSH into Pi
- [ ] Run `git clone https://github.com/YOUR_USERNAME/raspberry-pi-travel-router.git`
- [ ] Run `cd raspberry-pi-travel-router`
- [ ] Run `chmod +x scripts/*.sh`

### Method B: Manual Transfer (WinSCP)
- [ ] Download WinSCP
- [ ] Connect to Raspberry Pi
- [ ] Transfer repository folder to `/home/pi/`
- [ ] SSH into Pi
- [ ] Run `cd raspberry-pi-travel-router`
- [ ] Run `chmod +x scripts/*.sh`

## Phase 7: Gather Required Information

Write down the following (keep secure):

**WiFi Network to Connect To:**
- SSID: _______________________________
- Password: ___________________________

**Access Point Settings:**
- SSID: _______________________________ (default: GKTravelRouter)
- Password: ___________________________ (default: CABOFUN1)

**NordVPN Service Credentials:**
- Username: ___________________________
- Password: ___________________________

**VPN Server Preference:**
- Server: _____________________________ (default: us9952.nordvpn.com)

## Phase 8: Run Installation

- [ ] Run `cd ~/raspberry-pi-travel-router`
- [ ] Run `sudo bash scripts/install.sh`
- [ ] Confirm to continue installation
- [ ] Wait for Phase 1: System Preparation
- [ ] Wait for Phase 2: WiFi Driver (15-20 minutes)
- [ ] Provide Access Point SSID when prompted
- [ ] Provide Access Point password when prompted
- [ ] Provide WiFi SSID to connect when prompted
- [ ] Provide WiFi password when prompted
- [ ] Provide VPN server when prompted
- [ ] Provide NordVPN username when prompted
- [ ] Provide NordVPN password when prompted
- [ ] Wait for remaining phases to complete
- [ ] Review verification output

## Phase 9: Verification

### From Raspberry Pi (via SSH):
- [ ] Run `bash scripts/router-status.sh`
- [ ] Verify all services show ✓ (green)
- [ ] Run `curl ifconfig.me`
- [ ] Verify IP shown is VPN server IP (not your real IP)
- [ ] Run `ip addr show`
- [ ] Verify wlan0 has 192.168.4.1
- [ ] Verify eth0 has 192.168.100.2
- [ ] Verify tun0 exists with VPN IP

### From Client Device:
- [ ] Look for WiFi network with your chosen SSID
- [ ] Connect to WiFi using your chosen password
- [ ] Connection successful
- [ ] Open web browser
- [ ] Visit https://www.whatismyip.com/
- [ ] Verify IP is VPN server IP (not your real IP)
- [ ] Visit https://dnsleaktest.com/
- [ ] Run extended test
- [ ] Verify all DNS servers are NordVPN servers
- [ ] Test browsing several websites
- [ ] Test streaming (if desired)

## Phase 10: Document Your Setup

- [ ] Note the Raspberry Pi management IP: 192.168.100.2
- [ ] Note your Access Point SSID: _______________________
- [ ] Note your Access Point password: __________________
- [ ] Save SSH login details securely
- [ ] Bookmark https://my.nordaccount.com/ for credentials
- [ ] Save this checklist for future reference

## Post-Setup Tasks

- [ ] Test connecting to different WiFi network using `connect-wifi.sh`
- [ ] Test changing VPN server using `change-vpn.sh`
- [ ] Create backup of configuration
  ```bash
  sudo tar -czf ~/router-backup-$(date +%Y%m%d).tar.gz \
      /etc/hostapd/ /etc/dnsmasq.conf \
      /etc/wpa_supplicant/wpa_supplicant-wlan1.conf \
      /etc/openvpn/nordvpn.conf \
      /etc/dhcpcd.conf /etc/iptables/
  ```
- [ ] Transfer backup to safe location
- [ ] Test reboot: `sudo reboot` and verify everything starts correctly
- [ ] Update documentation if you made any custom changes

## Travel Preparation

Before traveling with your router:

- [ ] Test router in portable setup
- [ ] Verify battery power solution (if using)
- [ ] Pack necessary cables (Ethernet, power)
- [ ] Ensure router is configured with latest settings
- [ ] Have SSH client on your laptop
- [ ] Know how to connect via Ethernet for management
- [ ] Bookmark troubleshooting guide
- [ ] Screenshot or save WiFi credentials for router AP

## Troubleshooting Reference

If issues occur:

1. **Check Status**: `bash scripts/router-status.sh`
2. **View Logs**: `sudo journalctl -u openvpn@nordvpn -f`
3. **Restart Services**: 
   ```bash
   sudo systemctl restart hostapd dnsmasq wpa_supplicant@wlan1 openvpn@nordvpn
   ```
4. **Check Installation Log**: `cat /var/log/travel-router-install.log`
5. **Review Troubleshooting Guide**: `docs/TROUBLESHOOTING.md`

## Success Indicators

✅ All services running  
✅ VPN tunnel active (tun0 exists)  
✅ External IP shows VPN location  
✅ No DNS leaks  
✅ Clients can connect and browse  
✅ SSH access via Ethernet works  
✅ Configuration persists after reboot  

---

**Setup Complete!** 🎉

Your Raspberry Pi is now a fully functional travel VPN router. Safe travels and secure browsing!
