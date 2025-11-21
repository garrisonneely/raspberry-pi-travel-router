#!/bin/bash

###############################################################################
# Connect to New WiFi Network
# Usage: ./connect-wifi.sh "WiFiName" "WiFiPassword"
###############################################################################

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root: sudo bash connect-wifi.sh"
    exit 1
fi

if [ $# -lt 2 ]; then
    echo "Usage: sudo bash connect-wifi.sh \"WiFiName\" \"WiFiPassword\""
    exit 1
fi

SSID="$1"
PASSWORD="$2"

echo "[INFO] Configuring wlan1 to connect to: $SSID"

# Backup current config
cp /etc/wpa_supplicant/wpa_supplicant-wlan1.conf /etc/wpa_supplicant/wpa_supplicant-wlan1.conf.backup

# Update configuration
cat > /etc/wpa_supplicant/wpa_supplicant-wlan1.conf << EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=US

network={
    ssid="$SSID"
    psk="$PASSWORD"
    priority=1
}
EOF

chmod 600 /etc/wpa_supplicant/wpa_supplicant-wlan1.conf

echo "[INFO] Restarting wpa_supplicant..."
systemctl restart wpa_supplicant@wlan1

echo "[INFO] Waiting for connection..."
sleep 5

# Wait for WiFi connection
CONNECTED=false
for i in {1..10}; do
    if iw wlan1 link | grep -q "Connected"; then
        CONNECTED=true
        break
    fi
    echo "[INFO] Waiting for WiFi connection... ($i/10)"
    sleep 2
done

if [ "$CONNECTED" = false ]; then
    echo "[ERROR] Failed to connect to: $SSID"
    echo "[INFO] Check credentials and try again"
    echo "[INFO] View logs: sudo journalctl -u wpa_supplicant@wlan1 -f"
    exit 1
fi

CONNECTED_SSID=$(iw wlan1 link | grep SSID | awk '{print $2}')
echo "[SUCCESS] Connected to: $CONNECTED_SSID"

# Request new DHCP lease
echo "[INFO] Requesting new DHCP lease..."
pkill -f "dhcpcd.*wlan1" 2>/dev/null || true
pkill -f "dhclient.*wlan1" 2>/dev/null || true
sleep 1

if command -v dhcpcd &> /dev/null; then
    dhcpcd -b wlan1
elif command -v dhclient &> /dev/null; then
    dhclient wlan1 &
else
    echo "[WARNING] No DHCP client found"
fi

# Wait for IP
echo "[INFO] Waiting for IP address (up to 30 seconds)..."
for attempt in {1..30}; do
    wlan1_ip=$(ip addr show wlan1 | grep "inet " | awk '{print $2}')
    if [ -n "$wlan1_ip" ]; then
        echo "[SUCCESS] Got IP: $wlan1_ip"
        break
    fi
    sleep 1
done

if [ -z "$wlan1_ip" ]; then
    echo "[ERROR] Failed to get IP address"
    echo "[INFO] Network may require captive portal authentication"
    exit 1
fi

echo "[INFO] Testing internet connectivity..."
if ping -c 3 -W 5 8.8.8.8 &> /dev/null; then
    echo "[SUCCESS] Internet connectivity OK"
    
    # Ensure wlan0 (AP) still has correct IP
    echo "[INFO] Verifying Access Point configuration..."
    wlan0_ip=$(ip addr show wlan0 | grep "inet " | awk '{print $2}')
    if [ "$wlan0_ip" != "192.168.4.1/24" ]; then
        echo "[INFO] Reconfiguring wlan0..."
        ip addr flush dev wlan0 2>/dev/null || true
        ip link set wlan0 up
        ip addr add 192.168.4.1/24 dev wlan0
        systemctl restart hostapd
        systemctl restart dnsmasq
    fi
    
    echo "[INFO] Restarting VPN..."
    systemctl restart openvpn@nordvpn
    sleep 5
    
    if ip link show tun0 &> /dev/null; then
        echo "[SUCCESS] VPN tunnel active"
    else
        echo "[WARNING] VPN tunnel not up yet, check: systemctl status openvpn@nordvpn"
    fi
else
    echo "[WARNING] No internet connectivity"
    echo "[INFO] Network may require browser authentication"
fi

echo ""
echo "WiFi change complete!"
echo "Run 'sudo bash scripts/router-status.sh' to verify full setup"
