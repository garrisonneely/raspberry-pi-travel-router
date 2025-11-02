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

echo "[INFO] Waiting for connection (10 seconds)..."
sleep 10

echo "[INFO] Checking connection status..."
if iw wlan1 link | grep -q "Connected"; then
    CONNECTED_SSID=$(iw wlan1 link | grep SSID | awk '{print $2}')
    echo "[SUCCESS] Connected to: $CONNECTED_SSID"
    
    echo "[INFO] Testing internet connectivity..."
    if ping -c 3 -W 5 8.8.8.8 &> /dev/null; then
        echo "[SUCCESS] Internet connectivity OK"
    else
        echo "[WARNING] No internet connectivity detected"
    fi
else
    echo "[ERROR] Failed to connect to: $SSID"
    echo "[INFO] Check credentials and try again"
    echo "[INFO] View logs: sudo journalctl -u wpa_supplicant@wlan1 -f"
    exit 1
fi
