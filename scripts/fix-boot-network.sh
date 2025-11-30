#!/bin/bash
###############################################################################
# Fix Boot Network Configuration
# Ensures wlan0 and wlan1 get proper IPs after reboot
###############################################################################

set -e

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root: sudo bash fix-boot-network.sh"
    exit 1
fi

echo "=========================================="
echo "  Fixing Boot Network Configuration"
echo "=========================================="
echo ""

# Step 1: Fix wlan0 immediately
echo "[1/6] Configuring wlan0 with static IP..."
ip addr flush dev wlan0 2>/dev/null || true
ip link set wlan0 up
ip addr add 192.168.4.1/24 dev wlan0
echo "      ✓ wlan0 now has 192.168.4.1/24"
echo ""

# Step 2: Restart hostapd so clients can connect
echo "[2/6] Restarting hostapd..."
systemctl restart hostapd
sleep 2
echo "      ✓ Access Point restarted"
echo ""

# Step 3: Restart dnsmasq for DHCP
echo "[3/6] Restarting dnsmasq..."
systemctl restart dnsmasq
sleep 1
echo "      ✓ DHCP server restarted"
echo ""

# Step 4: Fix wlan1 DHCP
echo "[4/6] Requesting DHCP for wlan1..."
# Kill any stale DHCP clients
pkill -f "dhcpcd.*wlan1" 2>/dev/null || true
pkill -f "dhclient.*wlan1" 2>/dev/null || true
sleep 1

# Request new lease
if command -v dhcpcd &> /dev/null; then
    dhcpcd -b wlan1
else
    dhclient -v wlan1 &
fi

# Wait for IP
echo "      Waiting for wlan1 IP (up to 30 seconds)..."
for attempt in {1..30}; do
    sleep 1
    wlan1_ip=$(ip addr show wlan1 | grep "inet " | awk '{print $2}')
    if [ -n "$wlan1_ip" ]; then
        echo "      ✓ wlan1 received IP: $wlan1_ip"
        break
    fi
    if [ $attempt -eq 30 ]; then
        echo "      ✗ wlan1 did not get IP - check WiFi connection"
        exit 1
    fi
done
echo ""

# Step 5: Restart VPN
echo "[5/6] Restarting VPN..."
systemctl restart openvpn@nordvpn
sleep 10

# Check VPN status
if ip link show tun0 &> /dev/null; then
    tun0_ip=$(ip addr show tun0 | grep "inet " | awk '{print $2}')
    echo "      ✓ VPN tunnel active: $tun0_ip"
else
    echo "      ⚠ VPN tunnel not up yet - may need more time"
fi
echo ""

# Step 6: Update systemd service for better boot behavior
echo "[6/6] Updating boot persistence service..."

# Create improved network init script
cat > /usr/local/bin/travel-router-network-init.sh << 'INITEOF'
#!/bin/bash
# Travel Router Network Initialization - Improved Version

# Wait for NetworkManager to finish (if running)
if systemctl is-active --quiet NetworkManager; then
    sleep 5
fi

# Configure wlan0 (Access Point)
ip addr flush dev wlan0 2>/dev/null || true
ip link set wlan0 up 2>/dev/null || true
sleep 2
ip addr add 192.168.4.1/24 dev wlan0 2>/dev/null || true

# Wait for wlan1 WiFi connection (up to 60 seconds)
for i in {1..60}; do
    if iw wlan1 link 2>/dev/null | grep -q "Connected"; then
        break
    fi
    sleep 1
done

# Kill stale DHCP clients
pkill -f "dhcpcd.*wlan1" 2>/dev/null || true
pkill -f "dhclient.*wlan1" 2>/dev/null || true
sleep 2

# Request DHCP for wlan1
if command -v dhcpcd &> /dev/null; then
    dhcpcd -b wlan1 2>/dev/null || true
elif command -v dhclient &> /dev/null; then
    dhclient wlan1 2>/dev/null || true
fi

# Wait for wlan1 IP (up to 30 seconds)
for i in {1..30}; do
    if ip -4 addr show wlan1 | grep -q "inet "; then
        exit 0
    fi
    sleep 1
done

exit 0
INITEOF

chmod +x /usr/local/bin/travel-router-network-init.sh

# Update systemd service with better dependencies
cat > /etc/systemd/system/travel-router-network.service << 'SERVICEEOF'
[Unit]
Description=Travel Router Network Initialization
After=network.target wpa_supplicant@wlan1.service NetworkManager.service
Before=hostapd.service dnsmasq.service openvpn@nordvpn.service
Wants=wpa_supplicant@wlan1.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/travel-router-network-init.sh
TimeoutStartSec=120
Restart=no

[Install]
WantedBy=multi-user.target
SERVICEEOF

systemctl daemon-reload
systemctl enable travel-router-network.service

echo "      ✓ Boot service updated"
echo ""

echo "=========================================="
echo "✓ Network configuration fixed!"
echo "=========================================="
echo ""
echo "Current Status:"
bash /home/pi/raspberry-pi-travel-router/scripts/router-status.sh

echo ""
echo "Next reboot should maintain network configuration."
echo "Test with: sudo reboot"
