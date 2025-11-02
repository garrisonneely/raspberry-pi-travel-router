#!/bin/bash

###############################################################################
# Change VPN Server
# Usage: ./change-vpn.sh us9952.nordvpn.com
###############################################################################

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root: sudo bash change-vpn.sh"
    exit 1
fi

if [ $# -lt 1 ]; then
    echo "Usage: sudo bash change-vpn.sh <server.nordvpn.com>"
    echo ""
    echo "Example: sudo bash change-vpn.sh us9952.nordvpn.com"
    echo ""
    echo "To find servers:"
    echo "  Denver: us9952, us9953, us9954"
    echo "  List all: ls /etc/openvpn/ovpn_udp/"
    exit 1
fi

SERVER="$1"
CONFIG="/etc/openvpn/ovpn_udp/${SERVER}.udp.ovpn"

if [ ! -f "$CONFIG" ]; then
    echo "[ERROR] Configuration not found: $CONFIG"
    echo "[INFO] Available configs:"
    ls -1 /etc/openvpn/ovpn_udp/*.udp.ovpn | head -20
    exit 1
fi

echo "[INFO] Stopping current VPN connection..."
systemctl stop openvpn@nordvpn

echo "[INFO] Backing up current config..."
cp /etc/openvpn/nordvpn.conf /etc/openvpn/nordvpn.conf.backup

echo "[INFO] Installing new server config: $SERVER"
cp "$CONFIG" /etc/openvpn/nordvpn.conf

echo "[INFO] Updating credentials path..."
sed -i 's/^auth-user-pass.*/auth-user-pass \/etc\/openvpn\/nordvpn-credentials/' /etc/openvpn/nordvpn.conf

echo "[INFO] Starting VPN with new server..."
systemctl start openvpn@nordvpn

echo "[INFO] Waiting for connection (15 seconds)..."
sleep 15

echo "[INFO] Checking VPN status..."
if systemctl is-active --quiet openvpn@nordvpn; then
    if ip link show tun0 &> /dev/null; then
        echo "[SUCCESS] VPN connected to: $SERVER"
        echo "[INFO] Testing external IP..."
        EXTERNAL_IP=$(curl -s --max-time 10 ifconfig.me)
        if [ -n "$EXTERNAL_IP" ]; then
            echo "[INFO] External IP: $EXTERNAL_IP"
        fi
    else
        echo "[WARNING] VPN service running but tun0 not found"
        echo "[INFO] Check logs: sudo journalctl -u openvpn@nordvpn -f"
    fi
else
    echo "[ERROR] VPN failed to start"
    echo "[INFO] Check logs: sudo journalctl -u openvpn@nordvpn -n 50"
    exit 1
fi
