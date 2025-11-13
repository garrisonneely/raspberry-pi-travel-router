#!/bin/bash

###############################################################################
# Collect Diagnostic Information for wlan1 DHCP Issue
###############################################################################

echo "=========================================="
echo "  Diagnostic Information Collection"
echo "=========================================="
echo ""

# Create output file
OUTPUT="/tmp/router-diagnostics-$(date +%Y%m%d-%H%M%S).txt"

{
    echo "==================== SYSTEM INFO ===================="
    echo "Date: $(date)"
    echo "Hostname: $(hostname)"
    echo "Kernel: $(uname -r)"
    echo "OS: $(cat /etc/os-release | grep PRETTY_NAME)"
    echo ""
    
    echo "==================== NETWORK INTERFACES ===================="
    ip addr show
    echo ""
    
    echo "==================== WIRELESS STATUS ===================="
    echo "--- wlan1 link status ---"
    iw wlan1 link || echo "Failed to get wlan1 link status"
    echo ""
    
    echo "--- wlan1 info ---"
    iw wlan1 info || echo "Failed to get wlan1 info"
    echo ""
    
    echo "==================== ROUTING TABLE ===================="
    ip route
    echo ""
    
    echo "==================== DHCP CLIENT STATUS ===================="
    echo "--- Is dhclient installed? ---"
    which dhclient && dhclient --version || echo "dhclient NOT installed"
    echo ""
    
    echo "--- Is dhcpcd installed? ---"
    which dhcpcd && dhcpcd --version || echo "dhcpcd NOT installed"
    echo ""
    
    echo "--- dhcpcd service status ---"
    systemctl status dhcpcd --no-pager || echo "dhcpcd service not found"
    echo ""
    
    echo "--- Running dhclient processes ---"
    ps aux | grep dhclient | grep -v grep || echo "No dhclient processes"
    echo ""
    
    echo "==================== SERVICE STATUS ===================="
    echo "--- NetworkManager ---"
    systemctl status NetworkManager --no-pager || echo "NetworkManager not running"
    echo ""
    
    echo "--- wpa_supplicant@wlan1 ---"
    systemctl status wpa_supplicant@wlan1 --no-pager
    echo ""
    
    echo "--- hostapd ---"
    systemctl status hostapd --no-pager
    echo ""
    
    echo "--- dnsmasq ---"
    systemctl status dnsmasq --no-pager
    echo ""
    
    echo "--- openvpn@nordvpn ---"
    systemctl status openvpn@nordvpn --no-pager
    echo ""
    
    echo "==================== NETWORKMANAGER DEVICE STATUS ===================="
    nmcli device status || echo "nmcli failed"
    echo ""
    
    echo "==================== LOGS: wpa_supplicant@wlan1 ===================="
    journalctl -u wpa_supplicant@wlan1 -n 50 --no-pager
    echo ""
    
    echo "==================== LOGS: dhcpcd (if exists) ===================="
    journalctl -u dhcpcd -n 50 --no-pager 2>&1 || echo "No dhcpcd logs"
    echo ""
    
    echo "==================== LOGS: dhclient search ===================="
    journalctl --no-pager | grep -i dhclient | tail -n 30 || echo "No dhclient logs found"
    echo ""
    
    echo "==================== LOGS: NetworkManager wlan1 ===================="
    journalctl -u NetworkManager --no-pager | grep wlan1 | tail -n 30 || echo "No NetworkManager wlan1 logs"
    echo ""
    
    echo "==================== CONFIGURATION FILES ===================="
    echo "--- /etc/wpa_supplicant/wpa_supplicant-wlan1.conf ---"
    cat /etc/wpa_supplicant/wpa_supplicant-wlan1.conf 2>&1 | sed 's/psk=.*/psk=***HIDDEN***/'
    echo ""
    
    echo "--- /etc/dhcpcd.conf (if exists) ---"
    if [ -f /etc/dhcpcd.conf ]; then
        cat /etc/dhcpcd.conf | tail -n 50
    else
        echo "dhcpcd.conf does not exist"
    fi
    echo ""
    
    echo "--- /etc/NetworkManager/conf.d/unmanaged.conf ---"
    cat /etc/NetworkManager/conf.d/unmanaged.conf 2>&1 || echo "unmanaged.conf does not exist"
    echo ""
    
    echo "==================== CONNECTIVITY TEST ===================="
    echo "--- Ping via wlan1 to 8.8.8.8 ---"
    ping -I wlan1 -c 3 -W 5 8.8.8.8 2>&1 || echo "Ping via wlan1 failed"
    echo ""
    
    echo "--- DNS resolution ---"
    nslookup google.com 2>&1 || echo "DNS resolution failed"
    echo ""
    
    echo "==================== PACKAGE INFO ===================="
    echo "--- isc-dhcp-client (dhclient package) ---"
    dpkg -l | grep isc-dhcp-client || echo "isc-dhcp-client NOT installed"
    echo ""
    
    echo "--- dhcpcd5 package ---"
    dpkg -l | grep dhcpcd5 || echo "dhcpcd5 NOT installed"
    echo ""
    
    echo "==================== END OF DIAGNOSTICS ===================="
    
} > "$OUTPUT" 2>&1

echo "Diagnostics saved to: $OUTPUT"
echo ""
echo "To view:"
echo "  cat $OUTPUT"
echo ""
echo "To copy to clipboard (if you have xclip):"
echo "  cat $OUTPUT | xclip -selection clipboard"
echo ""
echo "Or copy the file to your PC and open it:"
echo "  scp pi@192.168.100.2:$OUTPUT ."
echo ""

# Also display it
echo "==================== SUMMARY ===================="
grep -E "dhclient|dhcpcd|wlan1.*inet|Connected|FAIL|ERROR" "$OUTPUT" | head -n 30
echo ""
echo "Full diagnostics above saved to: $OUTPUT"
