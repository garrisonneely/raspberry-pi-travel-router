#!/bin/bash

###############################################################################
# Travel Router Status Check
# Usage: ./router-status.sh
###############################################################################

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=========================================="
echo "  Travel Router Status"
echo "=========================================="
echo ""

# Service Status
echo -e "${BLUE}[Service Status]${NC}"
services=("hostapd" "dnsmasq" "wpa_supplicant@wlan1" "openvpn@nordvpn")
for service in "${services[@]}"; do
    if systemctl is-active --quiet "$service"; then
        echo -e "  ${GREEN}✓${NC} $service: RUNNING"
    else
        echo -e "  ${RED}✗${NC} $service: STOPPED"
    fi
done

echo ""
echo -e "${BLUE}[Network Interfaces]${NC}"
interfaces=("wlan0" "wlan1" "eth0" "tun0")
for iface in "${interfaces[@]}"; do
    if ip link show "$iface" &> /dev/null; then
        ip_addr=$(ip addr show "$iface" | grep "inet " | awk '{print $2}' | head -1)
        if [ -n "$ip_addr" ]; then
            echo -e "  ${GREEN}✓${NC} $iface: $ip_addr"
        else
            echo -e "  ${YELLOW}!${NC} $iface: UP (No IP)"
        fi
    else
        echo -e "  ${RED}✗${NC} $iface: DOWN"
    fi
done

echo ""
echo -e "${BLUE}[WiFi Client (wlan1)]${NC}"
if iw wlan1 link | grep -q "Connected"; then
    ssid=$(iw wlan1 link | grep SSID | awk '{print $2}')
    signal=$(iw wlan1 link | grep signal | awk '{print $2, $3}')
    echo -e "  ${GREEN}✓${NC} Connected to: $ssid"
    echo -e "    Signal: $signal"
else
    echo -e "  ${RED}✗${NC} Not connected to WiFi"
fi

echo ""
echo -e "${BLUE}[VPN Status]${NC}"
if ip link show tun0 &> /dev/null; then
    echo -e "  ${GREEN}✓${NC} VPN tunnel: ACTIVE"
    
    # Try to get external IP
    external_ip=$(timeout 5 curl -s ifconfig.me 2>/dev/null)
    if [ -n "$external_ip" ]; then
        echo -e "    External IP: $external_ip"
    fi
    
    # Get VPN server from config
    vpn_server=$(grep "^remote " /etc/openvpn/nordvpn.conf | awk '{print $2}')
    if [ -n "$vpn_server" ]; then
        echo -e "    Server: $vpn_server"
    fi
else
    echo -e "  ${RED}✗${NC} VPN tunnel: INACTIVE"
fi

echo ""
echo -e "${BLUE}[Internet Connectivity]${NC}"
if ping -c 2 -W 3 8.8.8.8 &> /dev/null; then
    echo -e "  ${GREEN}✓${NC} Internet: OK"
else
    echo -e "  ${RED}✗${NC} Internet: FAILED"
fi

echo ""
echo -e "${BLUE}[Access Point]${NC}"
ap_ssid=$(grep "^ssid=" /etc/hostapd/hostapd.conf | cut -d'=' -f2)
echo -e "  SSID: $ap_ssid"
echo -e "  IP: 192.168.4.1"

# Count connected clients
client_count=$(iw dev wlan0 station dump | grep "^Station" | wc -l)
echo -e "  Connected clients: $client_count"

echo ""
echo "=========================================="
echo "Quick Commands:"
echo "  View logs: sudo journalctl -u openvpn@nordvpn -f"
echo "  Restart VPN: sudo systemctl restart openvpn@nordvpn"
echo "  Connect WiFi: sudo bash connect-wifi.sh \"SSID\" \"password\""
echo "=========================================="
