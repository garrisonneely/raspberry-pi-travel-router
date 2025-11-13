#!/bin/bash

###############################################################################
# Fix wlan1 DHCP Issue
# 
# This script fixes the common issue where wlan1 connects to WiFi but
# doesn't get an IP address via DHCP
###############################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

echo "=========================================="
echo "  wlan1 DHCP Fix Script"
echo "=========================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run as root"
    echo "Usage: sudo bash scripts/fix-wlan1-dhcp.sh"
    exit 1
fi

log_info "Current wlan1 status:"
ip addr show wlan1 | grep "inet " || echo "  No IP address"
iw wlan1 link | grep -E "SSID|signal" || echo "  Not connected"
echo ""

# The issue: dhcpcd or NetworkManager may not be managing wlan1
log_info "Checking what's managing wlan1..."

# Check if NetworkManager is managing it (it shouldn't be)
if nmcli device status | grep wlan1 | grep -q "connected\|connecting"; then
    log_warning "NetworkManager is managing wlan1 (should be unmanaged)"
    log_info "Forcing NetworkManager to release wlan1..."
    nmcli device set wlan1 managed no
    nmcli device disconnect wlan1
    sleep 2
fi

# Check if dhcpcd is running
if systemctl is-active --quiet dhcpcd; then
    log_info "dhcpcd is running, attempting to restart..."
    systemctl restart dhcpcd
    sleep 5
else
    log_info "dhcpcd not active, starting dhclient manually..."
    # Kill any existing dhclient on wlan1
    pkill -f "dhclient.*wlan1" 2>/dev/null || true
    
    # Start dhclient for wlan1
    dhclient -v wlan1 2>&1 | head -n 20 &
    sleep 5
fi

# Check if we got an IP
log_info "Checking for IP address..."
wlan1_ip=$(ip addr show wlan1 | grep "inet " | awk '{print $2}')

if [ -n "$wlan1_ip" ]; then
    log_success "wlan1 now has IP: $wlan1_ip"
    
    # Test connectivity through wlan1
    log_info "Testing connectivity through wlan1..."
    if ping -I wlan1 -c 3 -W 5 8.8.8.8 &> /dev/null; then
        log_success "Internet connectivity working through wlan1!"
        
        # Now restart VPN
        log_info "Restarting VPN connection..."
        systemctl restart openvpn@nordvpn
        sleep 10
        
        if ip link show tun0 &> /dev/null; then
            log_success "VPN tunnel established!"
            tun0_ip=$(ip addr show tun0 | grep "inet " | awk '{print $2}')
            log_info "VPN IP: $tun0_ip"
        else
            log_warning "VPN tunnel not yet established, check logs:"
            echo "  sudo journalctl -u openvpn@nordvpn -n 50"
        fi
    else
        log_warning "wlan1 has IP but cannot reach internet"
        log_info "This might be a captive portal - check if you need to accept terms"
    fi
else
    log_error "Failed to get IP address on wlan1"
    echo ""
    log_info "Troubleshooting steps:"
    echo "1. Check wpa_supplicant is running:"
    echo "   sudo systemctl status wpa_supplicant@wlan1"
    echo ""
    echo "2. Check WiFi connection:"
    echo "   iw wlan1 link"
    echo ""
    echo "3. Check for DHCP issues in logs:"
    echo "   sudo journalctl | grep -i dhcp | tail -n 20"
    echo ""
    echo "4. Try manually requesting DHCP:"
    echo "   sudo dhclient -v wlan1"
    echo ""
    echo "5. Check if network has captive portal:"
    echo "   curl -I http://detectportal.firefox.com/success.txt"
    exit 1
fi

echo ""
echo "=========================================="
log_success "Fix complete! Run health check to verify:"
echo "  sudo bash scripts/router-health.sh"
echo "=========================================="
