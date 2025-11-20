#!/bin/bash
#############################################
# Emergency fix for wlan1 DHCP on running system
# This fixes systems where wlan1 connects but has no IPv4
#############################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

# Must run as root
if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
fi

echo "========================================"
echo "Emergency wlan1 DHCP Fix"
echo "========================================"

# Check wlan1 exists and is up
if ! ip link show wlan1 &>/dev/null; then
    log_error "wlan1 interface not found"
    exit 1
fi

# Check if connected to WiFi
if ! iw wlan1 link | grep -q "Connected"; then
    log_error "wlan1 not connected to WiFi. Run connect-wifi.sh first"
    exit 1
fi

SSID=$(iw wlan1 link | grep "SSID" | awk '{print $2}')
log_info "wlan1 connected to: $SSID"

# Check current IP
current_ip=$(ip -4 addr show wlan1 | grep "inet " | awk '{print $2}')
if [ -n "$current_ip" ]; then
    log_warning "wlan1 already has IP: $current_ip"
    log_info "Releasing old lease and requesting new one..."
fi

# Kill any existing DHCP clients for wlan1
log_info "Stopping existing DHCP clients on wlan1..."
pkill -f "dhcpcd.*wlan1" 2>/dev/null && sleep 1 || true
pkill -f "dhclient.*wlan1" 2>/dev/null && sleep 1 || true

# Flush any old IP
ip addr flush dev wlan1 2>/dev/null || true

# Try dhcpcd first (most common on RPi)
if command -v dhcpcd &> /dev/null; then
    log_info "Requesting DHCP via dhcpcd..."
    dhcpcd -b wlan1
    sleep 5
    
    # Check if we got IP
    new_ip=$(ip -4 addr show wlan1 | grep "inet " | awk '{print $2}')
    if [ -n "$new_ip" ]; then
        log_success "Got IP via dhcpcd: $new_ip"
    else
        log_warning "dhcpcd didn't get IP, trying dhclient..."
        
        # Fallback to dhclient
        if command -v dhclient &> /dev/null; then
            dhclient -v wlan1
            sleep 5
            new_ip=$(ip -4 addr show wlan1 | grep "inet " | awk '{print $2}')
            if [ -n "$new_ip" ]; then
                log_success "Got IP via dhclient: $new_ip"
            fi
        else
            log_error "dhclient not found. Install with: apt install -y isc-dhcp-client"
        fi
    fi
else
    log_warning "dhcpcd not found, trying dhclient..."
    
    if command -v dhclient &> /dev/null; then
        log_info "Requesting DHCP via dhclient..."
        dhclient -v wlan1
        sleep 5
        new_ip=$(ip -4 addr show wlan1 | grep "inet " | awk '{print $2}')
        if [ -n "$new_ip" ]; then
            log_success "Got IP via dhclient: $new_ip"
        fi
    else
        log_error "No DHCP client found!"
        log_error "Install one with: apt install -y isc-dhcp-client"
        exit 1
    fi
fi

# Final check
final_ip=$(ip -4 addr show wlan1 | grep "inet " | awk '{print $2}')
if [ -z "$final_ip" ]; then
    log_error "Failed to get IP address for wlan1"
    log_info "This could mean:"
    log_info "  - Router requires captive portal authentication"
    log_info "  - Router has MAC filtering enabled"
    log_info "  - DHCP server is not responding"
    log_info "  - Network requires static IP assignment"
    exit 1
fi

log_success "wlan1 has IP: $final_ip"

# Test connectivity through wlan1
log_info "Testing internet connectivity..."
if ping -I wlan1 -c 3 8.8.8.8 &>/dev/null; then
    log_success "Internet working through wlan1!"
else
    log_warning "Cannot ping 8.8.8.8 through wlan1"
    log_info "Checking DNS..."
    if ping -I wlan1 -c 3 google.com &>/dev/null; then
        log_success "DNS working, connectivity confirmed!"
    else
        log_warning "May need captive portal authentication"
    fi
fi

# Restart VPN to use new wlan1 connection
log_info "Restarting VPN service..."
systemctl restart openvpn@nordvpn
sleep 3

# Check VPN status
if systemctl is-active --quiet openvpn@nordvpn; then
    log_success "VPN service restarted"
    sleep 5
    
    # Check if tun0 is up
    if ip link show tun0 &>/dev/null; then
        tun0_ip=$(ip addr show tun0 | grep "inet " | awk '{print $2}')
        if [ -n "$tun0_ip" ]; then
            log_success "VPN tunnel active: $tun0_ip"
        fi
    else
        log_warning "VPN tunnel not yet up, check: journalctl -u openvpn@nordvpn -n 50"
    fi
else
    log_warning "VPN service failed to start, check: journalctl -u openvpn@nordvpn -n 50"
fi

echo ""
echo "========================================"
echo "Summary:"
echo "  wlan1 IP: $final_ip"
echo "  Run router-status.sh to verify full setup"
echo "========================================"
