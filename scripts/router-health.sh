#!/bin/bash

###############################################################################
# Raspberry Pi Travel VPN Router - Health Check Script
#
# Tests all connectivity layers and provides detailed diagnostics
# Usage: sudo bash scripts/router-health.sh
###############################################################################

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Error tracking
ERRORS=()
WARNINGS=()

###############################################################################
# Helper Functions
###############################################################################

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_test() {
    echo -e "${YELLOW}[TEST]${NC} $1"
}

print_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

print_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ERRORS+=("$1")
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    WARNINGS+=("$1")
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

###############################################################################
# Test Functions
###############################################################################

test_interfaces() {
    print_header "1. Network Interfaces"
    
    # Test eth0
    print_test "Checking eth0 (Management Interface)"
    if ip link show eth0 &> /dev/null; then
        eth0_ip=$(ip addr show eth0 | grep "inet " | awk '{print $2}')
        if [ -n "$eth0_ip" ]; then
            print_pass "eth0: UP with IP $eth0_ip"
        else
            print_warn "eth0: UP but no IP address"
        fi
    else
        print_warn "eth0: Interface not found"
    fi
    
    # Test wlan0 (AP)
    print_test "Checking wlan0 (Access Point)"
    if ip link show wlan0 &> /dev/null; then
        if ip link show wlan0 | grep -q "UP"; then
            wlan0_ip=$(ip addr show wlan0 | grep "inet " | awk '{print $2}')
            if [ "$wlan0_ip" = "192.168.4.1/24" ]; then
                print_pass "wlan0: UP with correct IP $wlan0_ip"
            else
                print_fail "wlan0: UP but wrong IP ($wlan0_ip, expected 192.168.4.1/24)"
            fi
        else
            print_fail "wlan0: Interface DOWN"
        fi
    else
        print_fail "wlan0: Interface not found"
    fi
    
    # Test wlan1 (Client)
    print_test "Checking wlan1 (WiFi Client)"
    if ip link show wlan1 &> /dev/null; then
        if ip link show wlan1 | grep -q "UP"; then
            wlan1_ip=$(ip addr show wlan1 | grep "inet " | awk '{print $2}')
            if [ -n "$wlan1_ip" ]; then
                print_pass "wlan1: UP with IP $wlan1_ip"
            else
                print_fail "wlan1: UP but no IP (not connected to WiFi)"
            fi
        else
            print_fail "wlan1: Interface DOWN"
        fi
    else
        print_fail "wlan1: Interface not found (USB WiFi adapter may not be detected)"
    fi
    
    # Test tun0 (VPN)
    print_test "Checking tun0 (VPN Tunnel)"
    if ip link show tun0 &> /dev/null; then
        if ip link show tun0 | grep -q "UP"; then
            tun0_ip=$(ip addr show tun0 | grep "inet " | awk '{print $2}')
            print_pass "tun0: UP with IP $tun0_ip"
        else
            print_fail "tun0: Interface DOWN"
        fi
    else
        print_fail "tun0: Interface not found (VPN not connected)"
    fi
}

test_services() {
    print_header "2. Service Status"
    
    services=("hostapd" "dnsmasq" "wpa_supplicant@wlan1" "openvpn@nordvpn")
    
    for service in "${services[@]}"; do
        print_test "Checking $service"
        if systemctl is-active --quiet "$service"; then
            print_pass "$service: Running"
        else
            print_fail "$service: NOT running"
            # Show last 3 lines of logs for debugging
            print_info "Last error: $(journalctl -u $service -n 3 --no-pager | tail -n 1)"
        fi
    done
}

test_wifi_connection() {
    print_header "3. WiFi Client Connection"
    
    print_test "Checking wlan1 WiFi connection"
    if iw wlan1 link 2>/dev/null | grep -q "Connected"; then
        ssid=$(iw wlan1 link | grep SSID | awk '{print $2}')
        signal=$(iw wlan1 link | grep signal | awk '{print $2, $3}')
        print_pass "Connected to SSID: $ssid (Signal: $signal)"
    else
        print_fail "Not connected to WiFi network"
        print_info "Check /etc/wpa_supplicant/wpa_supplicant-wlan1.conf for correct SSID/password"
    fi
}

test_vpn_connection() {
    print_header "4. VPN Connection"
    
    print_test "Checking OpenVPN process"
    if pgrep -x openvpn > /dev/null; then
        print_pass "OpenVPN process running"
    else
        print_fail "OpenVPN process not found"
    fi
    
    print_test "Checking VPN tunnel interface"
    if ip link show tun0 &> /dev/null; then
        vpn_ip=$(ip addr show tun0 | grep "inet " | awk '{print $2}')
        print_pass "VPN tunnel active with IP: $vpn_ip"
    else
        print_fail "VPN tunnel not established"
        print_info "Check: journalctl -u openvpn@nordvpn -n 20"
    fi
    
    print_test "Checking VPN gateway"
    vpn_gateway=$(ip route | grep tun0 | grep default | awk '{print $3}')
    if [ -n "$vpn_gateway" ]; then
        print_pass "VPN gateway: $vpn_gateway"
    else
        print_warn "No VPN gateway found in routing table"
    fi
}

test_routing() {
    print_header "5. Routing Configuration"
    
    print_test "Checking IP forwarding"
    if [ "$(cat /proc/sys/net/ipv4/ip_forward)" = "1" ]; then
        print_pass "IP forwarding: Enabled"
    else
        print_fail "IP forwarding: Disabled"
    fi
    
    print_test "Checking NAT rules (MASQUERADE)"
    nat_output=$(iptables -t nat -L POSTROUTING -n -v 2>/dev/null)
    if echo "$nat_output" | grep -E "MASQUERADE.*tun0|tun0.*MASQUERADE" > /dev/null; then
        print_pass "NAT rule for tun0: Configured"
    else
        print_fail "NAT rule for tun0: Missing"
        print_info "Current NAT rules: $(echo "$nat_output" | grep -v "^Chain" | grep -v "^$" | head -5 || echo 'none')"
    fi
    
    print_test "Checking default route"
    default_route=$(ip route | grep default | head -n 1)
    if echo "$default_route" | grep -q "tun0"; then
        print_pass "Default route via VPN: $default_route"
    else
        print_warn "Default route NOT via VPN: $default_route"
    fi
}

test_connectivity_from_pi() {
    print_header "6. Connectivity Test (from Pi)"
    
    print_test "Ping test to 8.8.8.8 (Google DNS)"
    if ping -c 3 -W 5 8.8.8.8 &> /dev/null; then
        print_pass "Can reach 8.8.8.8"
    else
        print_fail "Cannot reach 8.8.8.8 (no internet from Pi)"
    fi
    
    print_test "DNS resolution test"
    # Try multiple DNS resolution methods
    dns_working=false
    if host google.com &> /dev/null; then
        dns_working=true
    elif nslookup google.com &> /dev/null; then
        dns_working=true
    elif dig google.com +short &> /dev/null; then
        dns_working=true
    elif getent hosts google.com &> /dev/null; then
        dns_working=true
    elif ping -c 1 -W 2 google.com &> /dev/null; then
        dns_working=true
    fi
    
    if [ "$dns_working" = true ]; then
        print_pass "DNS resolution working"
    else
        print_warn "DNS resolution test inconclusive (but HTTP working below suggests DNS is OK)"
    fi
    
    print_test "HTTP connectivity test"
    if curl -s --connect-timeout 5 http://ifconfig.me &> /dev/null; then
        public_ip=$(curl -s --connect-timeout 5 http://ifconfig.me)
        print_pass "HTTP working - Public IP: $public_ip"
        
        # Check if IP is from NordVPN range
        print_test "Verifying VPN tunnel"
        if echo "$public_ip" | grep -qE "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$"; then
            print_info "Public IP appears to be: $public_ip"
            print_info "Verify this is a NordVPN IP at: https://nordvpn.com/what-is-my-ip/"
        fi
    else
        print_fail "HTTP connectivity failed"
    fi
}

test_ap_clients() {
    print_header "7. Access Point Status"
    
    print_test "Checking hostapd status"
    if systemctl is-active --quiet hostapd; then
        print_pass "hostapd is running"
        
        # Try to get connected clients (requires hostapd_cli)
        if command -v hostapd_cli &> /dev/null; then
            client_count=$(hostapd_cli -i wlan0 all_sta 2>/dev/null | grep -c "^[0-9a-f][0-9a-f]:" || echo "0")
            client_count=$(echo "$client_count" | tr -d '\n\r ')
            if [ "$client_count" -gt 0 ] 2>/dev/null; then
                print_info "Connected AP clients: $client_count"
            else
                print_info "No clients currently connected to AP"
            fi
        fi
    else
        print_fail "hostapd is not running"
    fi
    
    print_test "Checking DHCP server"
    if systemctl is-active --quiet dnsmasq; then
        print_pass "dnsmasq (DHCP) is running"
        
        # Check DHCP leases
        if [ -f /var/lib/misc/dnsmasq.leases ]; then
            lease_count=$(wc -l < /var/lib/misc/dnsmasq.leases)
            print_info "Active DHCP leases: $lease_count"
        fi
    else
        print_fail "dnsmasq is not running"
    fi
}

test_dns() {
    print_header "8. DNS Configuration"
    
    print_test "Checking dnsmasq configuration"
    if [ -f /etc/dnsmasq.conf ]; then
        dns_servers=$(grep "^server=" /etc/dnsmasq.conf | cut -d= -f2)
        if [ -n "$dns_servers" ]; then
            print_pass "DNS servers configured:"
            echo "$dns_servers" | while read server; do
                print_info "  - $server"
            done
        else
            print_warn "No DNS servers configured in dnsmasq.conf"
        fi
    else
        print_fail "dnsmasq.conf not found"
    fi
}

###############################################################################
# Main Execution
###############################################################################

main() {
    clear
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Travel VPN Router - Health Check${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "Running comprehensive connectivity tests..."
    echo ""
    
    # Run all tests
    test_interfaces
    test_services
    test_wifi_connection
    test_vpn_connection
    test_routing
    test_connectivity_from_pi
    test_ap_clients
    test_dns
    
    # Summary
    print_header "SUMMARY"
    
    if [ ${#ERRORS[@]} -eq 0 ]; then
        if [ ${#WARNINGS[@]} -eq 0 ]; then
            print_pass "All tests passed! Router is healthy."
        else
            echo -e "${YELLOW}Tests completed with ${#WARNINGS[@]} warning(s):${NC}"
            for warning in "${WARNINGS[@]}"; do
                echo -e "  ${YELLOW}⚠${NC} $warning"
            done
        fi
    else
        echo -e "${RED}Tests completed with ${#ERRORS[@]} error(s):${NC}"
        for error in "${ERRORS[@]}"; do
            echo -e "  ${RED}✗${NC} $error"
        done
        
        if [ ${#WARNINGS[@]} -gt 0 ]; then
            echo ""
            echo -e "${YELLOW}And ${#WARNINGS[@]} warning(s):${NC}"
            for warning in "${WARNINGS[@]}"; do
                echo -e "  ${YELLOW}⚠${NC} $warning"
            done
        fi
        
        echo ""
        echo -e "${BLUE}========================================${NC}"
        echo -e "${BLUE}TROUBLESHOOTING STEPS:${NC}"
        echo -e "${BLUE}========================================${NC}"
        
        # Provide specific troubleshooting based on errors
        if [[ " ${ERRORS[@]} " =~ "wlan1: UP but no IP" ]] || [[ " ${ERRORS[@]} " =~ "Not connected to WiFi" ]]; then
            echo -e "${YELLOW}WiFi Connection Issue:${NC}"
            echo "  1. Check WiFi credentials:"
            echo "     sudo cat /etc/wpa_supplicant/wpa_supplicant-wlan1.conf"
            echo "  2. Restart wpa_supplicant:"
            echo "     sudo systemctl restart wpa_supplicant@wlan1"
            echo "  3. Check available networks:"
            echo "     sudo iw wlan1 scan | grep SSID"
        fi
        
        if [[ " ${ERRORS[@]} " =~ "VPN" ]] || [[ " ${ERRORS[@]} " =~ "tun0" ]]; then
            echo ""
            echo -e "${YELLOW}VPN Connection Issue:${NC}"
            echo "  1. Check OpenVPN logs:"
            echo "     sudo journalctl -u openvpn@nordvpn -n 50"
            echo "  2. Verify credentials:"
            echo "     sudo cat /etc/openvpn/nordvpn.auth"
            echo "  3. Test VPN config:"
            echo "     sudo openvpn --config /etc/openvpn/nordvpn.conf"
            echo "  4. Try different server:"
            echo "     sudo bash scripts/change-vpn.sh"
        fi
        
        if [[ " ${ERRORS[@]} " =~ "Cannot reach 8.8.8.8" ]]; then
            echo ""
            echo -e "${YELLOW}Internet Connectivity Issue:${NC}"
            echo "  1. Check routing table:"
            echo "     ip route"
            echo "  2. Check NAT rules:"
            echo "     sudo iptables -t nat -L -n -v"
            echo "  3. Verify IP forwarding:"
            echo "     cat /proc/sys/net/ipv4/ip_forward"
            echo "  4. Test from wlan1 directly:"
            echo "     ping -I wlan1 -c 3 8.8.8.8"
        fi
    fi
    
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Detailed Logs:${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo "  Installation log: /var/log/travel-router-install.log"
    echo "  Service logs: journalctl -u <service-name>"
    echo "  Network status: ip addr; ip route"
    echo ""
}

# Check for root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}This script should be run as root for full diagnostics${NC}"
    echo "Usage: sudo bash scripts/router-health.sh"
    echo ""
    echo "Running limited checks..."
    echo ""
fi

main
