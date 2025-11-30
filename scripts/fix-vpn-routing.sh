#!/bin/bash

###############################################################################
# Fix VPN Routing - Apply correct NAT and routing rules
# 
# Run this when:
# - VPN is connected but clients can't reach internet
# - NAT rules missing for tun0
# - Default route not via VPN
#
# Usage: sudo bash scripts/fix-vpn-routing.sh
###############################################################################

set -e

# Color codes
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
echo "  VPN Routing Fix Script"
echo "=========================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run as root"
    echo "Usage: sudo bash scripts/fix-vpn-routing.sh"
    exit 1
fi

# Check if VPN is connected
if ! ip link show tun0 &> /dev/null; then
    log_error "VPN tunnel (tun0) not found"
    log_error "Start VPN first: sudo systemctl start openvpn@nordvpn"
    exit 1
fi

log_info "VPN tunnel detected, applying fixes..."
echo ""

# 1. Enable IP forwarding
log_info "Step 1: Enabling IP forwarding..."
echo 1 > /proc/sys/net/ipv4/ip_forward
sysctl -w net.ipv4.ip_forward=1 &> /dev/null
log_success "IP forwarding enabled"

# 2. Fix NAT rules
log_info "Step 2: Applying NAT rules for tun0..."

# Show current NAT rules before changes
log_info "Current NAT rules before changes:"
iptables -t nat -L POSTROUTING -n -v --line-numbers | head -20

# Remove any existing tun0 MASQUERADE rules to avoid duplicates
log_info "Removing any existing tun0 MASQUERADE rules..."
REMOVE_OUTPUT=$(iptables -t nat -D POSTROUTING -o tun0 -j MASQUERADE 2>&1)
REMOVE_EXIT=$?
if [ $REMOVE_EXIT -eq 0 ]; then
    log_info "Removed existing rule: $REMOVE_OUTPUT"
else
    log_info "No existing rule to remove (or error): $REMOVE_OUTPUT"
fi

# Add NAT rule for VPN tunnel
log_info "Adding NAT MASQUERADE rule for tun0..."
ADD_OUTPUT=$(iptables -t nat -A POSTROUTING -o tun0 -j MASQUERADE 2>&1)
ADD_EXIT=$?

if [ $ADD_EXIT -ne 0 ]; then
    log_error "Failed to add NAT rule. iptables command failed with exit code: $ADD_EXIT"
    log_error "Error output: $ADD_OUTPUT"
    log_error ""
    log_error "Checking iptables modules..."
    lsmod | grep -E "ip_tables|nf_nat|iptable_nat|nf_conntrack" || log_error "Required modules not loaded"
    log_error ""
    log_error "Checking if iptables-legacy is needed..."
    which iptables-legacy &>/dev/null && log_info "iptables-legacy available at: $(which iptables-legacy)"
    exit 1
fi

log_info "iptables command executed successfully"

# Verify rule was added
log_info "Verifying NAT rule was added..."
NAT_RULES=$(iptables -t nat -L POSTROUTING -n -v 2>&1)
echo "$NAT_RULES"

if echo "$NAT_RULES" | grep -q "MASQUERADE.*tun0"; then
    log_success "NAT rule for tun0 applied successfully"
else
    log_error "NAT rule not found in iptables output"
    log_error ""
    log_error "Full NAT table:"
    iptables -t nat -L -n -v
    log_error ""
    log_error "Trying alternative: Check if using nftables instead of iptables..."
    if command -v nft &>/dev/null; then
        log_info "nftables detected:"
        nft list ruleset 2>&1 | head -50
    fi
    exit 1
fi

# 3. Fix forwarding rules
log_info "Step 3: Configuring packet forwarding rules..."

# Ensure forwarding from wlan0 to tun0 is allowed
iptables -D FORWARD -i wlan0 -o tun0 -j ACCEPT 2>/dev/null || true
iptables -A FORWARD -i wlan0 -o tun0 -j ACCEPT

# Allow established connections back
iptables -D FORWARD -i tun0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
iptables -A FORWARD -i tun0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT

log_success "Forwarding rules configured"

# 4. Save iptables rules
log_info "Step 4: Saving iptables rules..."
mkdir -p /etc/iptables
iptables-save > /etc/iptables/rules.v4
log_success "iptables rules saved to /etc/iptables/rules.v4"

# 5. Show current routing table
echo ""
log_info "Current routing table:"
ip route show | head -10

echo ""
log_info "Current NAT rules:"
iptables -t nat -L POSTROUTING -n -v | grep -E "MASQUERADE|Chain"

# 6. Test connectivity
echo ""
log_info "Step 5: Testing connectivity..."

if ping -c 2 -W 3 8.8.8.8 &> /dev/null; then
    log_success "Can ping 8.8.8.8 (Google DNS)"
else
    log_warning "Cannot ping 8.8.8.8"
fi

if timeout 5 curl -s http://ifconfig.me &> /dev/null; then
    public_ip=$(timeout 5 curl -s http://ifconfig.me)
    log_success "HTTP working - Public IP: $public_ip"
else
    log_warning "HTTP request failed or timed out"
fi

echo ""
echo "=========================================="
log_success "VPN routing fixes applied!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Connect a device to your travel router WiFi"
echo "  2. Try browsing - should work now"
echo "  3. Check IP: https://www.whatismyip.com/"
echo "  4. Verify it shows NordVPN server location"
echo ""
echo "If issues persist:"
echo "  - Restart OpenVPN: sudo systemctl restart openvpn@nordvpn"
echo "  - Run this script again after restart"
echo "  - Check logs: sudo journalctl -u openvpn@nordvpn -n 50"
echo "=========================================="
