#!/bin/bash

###############################################################################
# Raspberry Pi Travel VPN Router - Main Installation Script
# 
# This script automates the complete setup of a travel VPN router with:
# - USB WiFi driver installation (Realtek 8812AU)
# - Access Point configuration (hostapd)
# - DHCP server setup (dnsmasq)
# - WiFi client configuration (wpa_supplicant)
# - VPN setup (OpenVPN with NordVPN)
# - Firewall and routing configuration
#
# Usage: sudo bash install.sh
###############################################################################

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log file location
LOGFILE="/var/log/travel-router-install.log"
exec > >(tee -a "$LOGFILE") 2>&1

# State file to track completed phases
STATE_FILE="/var/lib/travel-router-install.state"

###############################################################################
# Helper Functions
###############################################################################

mark_phase_complete() {
    local phase=$1
    mkdir -p "$(dirname "$STATE_FILE")"
    echo "$phase" >> "$STATE_FILE"
    log_info "Marked $phase as complete"
}

is_phase_complete() {
    local phase=$1
    [ -f "$STATE_FILE" ] && grep -q "^$phase$" "$STATE_FILE"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root. Use: sudo bash install.sh"
        exit 1
    fi
}

check_raspberry_pi() {
    if [ ! -f /proc/device-tree/model ]; then
        log_warning "Cannot detect Raspberry Pi model"
        return
    fi
    model=$(cat /proc/device-tree/model)
    log_info "Detected: $model"
}

prompt_continue() {
    read -p "$(echo -e ${YELLOW}Continue? [y/N]:${NC} )" -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_warning "Installation cancelled by user"
        exit 1
    fi
}

###############################################################################
# Phase 1: System Preparation
###############################################################################

phase1_system_prep() {
    log_info "=========================================="
    log_info "PHASE 1: System Preparation - BEGIN"
    log_info "=========================================="
    
    log_info "Updating package lists..."
    apt update || { log_error "Failed to update package lists"; exit 1; }
    
    log_info "Upgrading existing packages..."
    apt upgrade -y || { log_error "Failed to upgrade packages"; exit 1; }
    
    log_info "Installing required packages..."
    apt install -y git dkms build-essential hostapd dnsmasq openvpn unzip wget \
        iptables iptables-persistent rfkill net-tools wireless-tools bc || \
        { log_error "Failed to install required packages"; exit 1; }
    
    mark_phase_complete "phase1"
    log_success "PHASE 1: System Preparation - COMPLETE"
}

###############################################################################
# Phase 2: USB WiFi Driver Installation
###############################################################################

phase2_wifi_driver() {
    log_info "=========================================="
    log_info "PHASE 2: USB WiFi Driver Installation - BEGIN"
    log_info "=========================================="
    
    # Check if phase 2 is already complete
    if is_phase_complete "phase2"; then
        log_success "Phase 2 already completed (driver installed and verified)"
        log_info "Skipping Phase 2"
        return 0
    fi
    
    # Check if driver is loaded and wlan1 exists (completed but not marked)
    if lsmod | grep -q "8812au" && ip link show wlan1 &> /dev/null; then
        log_success "Driver 8812au already loaded and wlan1 interface detected"
        mark_phase_complete "phase2"
        log_info "Skipping Phase 2 - already complete"
        return 0
    fi
    
    log_info "Checking for existing driver installation..."
    if lsmod | grep -q "8812au"; then
        log_warning "Driver 8812au already loaded"
        read -p "$(echo -e ${YELLOW}Reinstall driver? [y/N]:${NC} )" -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Skipping driver installation"
            return
        fi
    fi
    
    log_info "Cloning 8812au driver repository..."
    cd /tmp
    if [ -d "8812au-20210820" ]; then
        rm -rf 8812au-20210820
    fi
    git clone https://github.com/morrownr/8812au-20210820.git || \
        { log_error "Failed to clone driver repository"; exit 1; }
    
    cd 8812au-20210820
    log_info "Installing driver (this may take several minutes)..."
    
    # Run installation with defaults (no interactive prompts)
    # The driver installation may ask to edit options - we skip this for automated setup
    echo -e "n\ny" | ./install-driver.sh || { log_error "Driver installation failed"; exit 1; }
    
    mark_phase_complete "phase2"
    log_success "PHASE 2: USB WiFi Driver Installation - COMPLETE"
    log_warning "System will reboot to load the driver..."
    log_info "After reboot, SSH back in and re-run: sudo bash ~/raspberry-pi-travel-router/scripts/install.sh"
    log_info "The script will automatically continue from Phase 3."
    
    read -p "$(echo -e ${YELLOW}Press Enter to reboot now...${NC} )"
    reboot
    exit 0
}

###############################################################################
# Phase 3: Network Interface Configuration
###############################################################################

phase3_network_interfaces() {
    log_info "=========================================="
    log_info "PHASE 3: Network Interface Configuration - BEGIN"
    log_info "=========================================="
    
    if is_phase_complete "phase3"; then
        log_success "Phase 3 already completed"
        log_info "Skipping Phase 3"
        return 0
    fi
    
    log_info "Backing up existing dhcpcd.conf..."
    cp /etc/dhcpcd.conf /etc/dhcpcd.conf.backup || true
    
    log_info "Configuring static IP addresses..."
    
    # Remove any existing wlan0/wlan1/eth0 configurations
    sed -i '/^interface wlan0/,/^$/d' /etc/dhcpcd.conf
    sed -i '/^interface wlan1/,/^$/d' /etc/dhcpcd.conf
    sed -i '/^interface eth0/,/^$/d' /etc/dhcpcd.conf
    
    cat >> /etc/dhcpcd.conf << 'EOF'

# Travel Router Configuration
interface wlan0
    static ip_address=192.168.4.1/24
    nohook wpa_supplicant
    nohook dhcp

interface eth0
    static ip_address=192.168.100.2/24

interface wlan1
    env wpa_supplicant_conf=/etc/wpa_supplicant/wpa_supplicant-wlan1.conf
EOF
    
    mark_phase_complete "phase3"
    log_success "PHASE 3: Network Interface Configuration - COMPLETE"
}

###############################################################################
# Phase 4: Access Point Configuration
###############################################################################

phase4_access_point() {
    log_info "=========================================="
    log_info "PHASE 4: Access Point Configuration - BEGIN"
    log_info "=========================================="
    
    if is_phase_complete "phase4"; then
        log_success "Phase 4 already completed"
        log_info "Skipping Phase 4"
        return 0
    fi
    
    # Clean up any stale lock files from interrupted sessions
    rm -f /etc/hostapd/.hostapd.conf.swp 2>/dev/null || true
    
    # Prompt for SSID and password
    read -p "Enter Access Point SSID [GKTravelRouter]: " AP_SSID
    AP_SSID=${AP_SSID:-GKTravelRouter}
    
    read -p "Enter Access Point Password [CABOFUN1]: " AP_PASSWORD
    AP_PASSWORD=${AP_PASSWORD:-CABOFUN1}
    
    # Validate password length
    if [ ${#AP_PASSWORD} -lt 8 ]; then
        log_error "Password must be at least 8 characters"
        exit 1
    fi
    
    log_info "Creating hostapd configuration..."
    cat > /etc/hostapd/hostapd.conf << EOF
interface=wlan0
driver=nl80211
ssid=$AP_SSID
hw_mode=g
channel=7
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=$AP_PASSWORD
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOF
    
    log_info "Configuring hostapd daemon..."
    sed -i 's|#DAEMON_CONF=""|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd || true
    echo 'DAEMON_CONF="/etc/hostapd/hostapd.conf"' > /etc/default/hostapd
    
    mark_phase_complete "phase4"
    log_success "PHASE 4: Access Point Configuration - COMPLETE (SSID: $AP_SSID)"
}

###############################################################################
phase5_dhcp_server() {
    log_info "=========================================="
    log_info "PHASE 5: DHCP Server Configuration - BEGIN"
    log_info "=========================================="
    
    if is_phase_complete "phase5"; then
        log_success "Phase 5 already completed"
        log_info "Skipping Phase 5"
        return 0
    fi
    
    # Clean up any stale lock files
    rm -f /etc/.dnsmasq.conf.swp 2>/dev/null || true
    
    log_info "Backing up existing dnsmasq.conf..."
    
    log_info "Backing up existing dnsmasq.conf..."
    mv /etc/dnsmasq.conf /etc/dnsmasq.conf.backup || true
    
    log_info "Creating dnsmasq configuration..."
    cat > /etc/dnsmasq.conf << 'EOF'
# Travel Router DHCP Configuration
interface=wlan0
dhcp-range=192.168.4.2,192.168.4.20,255.255.255.0,24h
domain=wlan
address=/gw.wlan/192.168.4.1

# DNS servers (using public DNS)
server=8.8.8.8
server=8.8.4.4

# Logging (useful for troubleshooting)
log-queries
log-dhcp
EOF
    
    mark_phase_complete "phase5"
    log_success "PHASE 5: DHCP Server Configuration - COMPLETE"
}

###############################################################################
# Phase 6: WiFi Client Configuration
###############################################################################

phase6_wifi_client() {
    log_info "=========================================="
    log_info "PHASE 6: WiFi Client Configuration - BEGIN"
    log_info "=========================================="
    
    if is_phase_complete "phase6"; then
        log_success "Phase 6 already completed"
        log_info "Skipping Phase 6"
        return 0
    fi
    
    read -p "Enter WiFi network SSID to connect to: " WIFI_SSID
    read -p "Enter WiFi network password: " WIFI_PASSWORD
    
    log_info "Creating wpa_supplicant configuration for wlan1..."
    cat > /etc/wpa_supplicant/wpa_supplicant-wlan1.conf << EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=US

network={
    ssid="$WIFI_SSID"
    psk="$WIFI_PASSWORD"
    priority=1
}
EOF
    
    chmod 600 /etc/wpa_supplicant/wpa_supplicant-wlan1.conf
    
    mark_phase_complete "phase6"
    log_success "PHASE 6: WiFi Client Configuration - COMPLETE (Network: $WIFI_SSID)"
}

###############################################################################
# Phase 7: VPN Configuration
###############################################################################

phase7_vpn_setup() {
    log_info "=========================================="
    log_info "PHASE 7: VPN Configuration - BEGIN"
    log_info "=========================================="
    
    if is_phase_complete "phase7"; then
        log_success "Phase 7 already completed"
        log_info "Skipping Phase 7"
        return 0
    fi
    
    # Clean up any stale lock files
    rm -f /etc/openvpn/.nordvpn.conf.swp 2>/dev/null || true
    rm -f /etc/openvpn/.nordvpn-credentials.swp 2>/dev/null || true
    
    log_info "Downloading NordVPN configuration files..."
    cd /tmp
    wget -q --show-progress https://downloads.nordcdn.com/configs/archives/servers/ovpn.zip || \
        { log_error "Failed to download NordVPN configs"; exit 1; }
    
    log_info "Extracting configuration files..."
    unzip -q -o ovpn.zip -d /etc/openvpn/ || \
        { log_error "Failed to extract configs"; exit 1; }
    
    log_info "Available US servers near Denver (Colorado):"
    echo "  - us9952.nordvpn.com (Denver)"
    echo "  - us9953.nordvpn.com (Denver)"
    echo "  - us9954.nordvpn.com (Denver)"
    echo "  - us10356.nordvpn.com (Denver)"
    
    read -p "Enter NordVPN server (e.g., us9952.nordvpn.com) [us9952.nordvpn.com]: " VPN_SERVER
    VPN_SERVER=${VPN_SERVER:-us9952.nordvpn.com}
    
    log_info "Searching for server configuration..."
    VPN_CONFIG="/etc/openvpn/ovpn_udp/${VPN_SERVER}.udp.ovpn"
    
    if [ ! -f "$VPN_CONFIG" ]; then
        log_error "Configuration file not found: $VPN_CONFIG"
        log_info "Listing available configs in /etc/openvpn/ovpn_udp/us*.udp.ovpn"
        ls -1 /etc/openvpn/ovpn_udp/us*.udp.ovpn | head -20
        exit 1
    fi
    
    log_info "Copying VPN configuration..."
    cp "$VPN_CONFIG" /etc/openvpn/nordvpn.conf
    
    log_info "Enter your NordVPN service credentials"
    log_info "(Find these in your NordVPN dashboard under 'Manual Setup')"
    read -p "NordVPN service username: " NORD_USER
    read -sp "NordVPN service password: " NORD_PASS
    echo
    
    log_info "Creating credentials file..."
    cat > /etc/openvpn/nordvpn-credentials << EOF
$NORD_USER
$NORD_PASS
EOF
    chmod 600 /etc/openvpn/nordvpn-credentials
    
    log_info "Updating VPN configuration to use credentials file..."
    sed -i 's/^auth-user-pass.*/auth-user-pass \/etc\/openvpn\/nordvpn-credentials/' /etc/openvpn/nordvpn.conf
    
    mark_phase_complete "phase7"
    log_success "PHASE 7: VPN Configuration - COMPLETE (Server: $VPN_SERVER)"
}

###############################################################################
# Phase 8: Routing and Firewall
###############################################################################

phase8_routing_firewall() {
    log_info "=========================================="
    log_info "PHASE 8: Routing and Firewall Configuration - BEGIN"
    log_info "=========================================="
    
    if is_phase_complete "phase8"; then
        log_success "Phase 8 already completed"
        log_info "Skipping Phase 8"
        return 0
    fi
    
    log_info "Enabling IP forwarding..."
    sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf || \
        echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
    sysctl -p
    
    log_info "Configuring iptables rules..."
    
    # Flush existing rules
    iptables -F
    iptables -t nat -F
    iptables -X
    
    # NAT configuration for VPN tunnel
    iptables -t nat -A POSTROUTING -o tun0 -j MASQUERADE
    
    # Forward traffic from wlan0 to VPN
    iptables -A FORWARD -i wlan0 -o tun0 -j ACCEPT
    iptables -A FORWARD -i tun0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
    
    # Allow SSH on eth0
    iptables -A INPUT -i eth0 -p tcp --dport 22 -j ACCEPT
    
    # Block traffic from wlan0 to eth0 (security)
    iptables -A FORWARD -i wlan0 -o eth0 -j DROP
    
    log_info "Saving iptables rules..."
    mkdir -p /etc/iptables
    iptables-save > /etc/iptables/rules.v4
    
    # Make iptables-persistent non-interactive
    echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
    echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
    
    mark_phase_complete "phase8"
    log_success "PHASE 8: Routing and Firewall Configuration - COMPLETE"
}

###############################################################################
# Phase 9: Startup Script Configuration
###############################################################################

phase9_startup_script() {
    log_info "=========================================="
    log_info "PHASE 9: Startup Script Configuration - BEGIN"
    log_info "=========================================="
    
    if is_phase_complete "phase9"; then
        log_success "Phase 9 already completed"
        log_info "Skipping Phase 9"
        return 0
    fi
    
    log_info "Creating rc.local startup script..."
    cat > /etc/rc.local << 'EOF'
#!/bin/bash
# Travel Router Startup Script

# Restore iptables rules
iptables-restore < /etc/iptables/rules.v4

# Ensure rfkill is unblocked for WiFi
rfkill unblock wifi
rfkill unblock all

# Ensure IP forwarding is enabled
echo 1 > /proc/sys/net/ipv4/ip_forward

# Log startup
echo "$(date): Travel router services started" >> /var/log/travel-router-startup.log

exit 0
EOF
    
    chmod +x /etc/rc.local
    
    # Enable rc-local service
    systemctl enable rc-local || true
    
    mark_phase_complete "phase9"
    log_success "PHASE 9: Startup Script Configuration - COMPLETE"
}

###############################################################################
# Phase 10: Service Enablement
###############################################################################

phase10_enable_services() {
    log_info "=========================================="
    log_info "PHASE 10: Enabling Services - BEGIN"
    log_info "=========================================="
    
    if is_phase_complete "phase10"; then
        log_success "Phase 10 already completed"
        log_info "Skipping Phase 10"
        return 0
    fi
    
    log_info "Unmasking and enabling hostapd..."
    systemctl unmask hostapd
    systemctl enable hostapd
    
    log_info "Enabling dnsmasq..."
    systemctl enable dnsmasq
    
    log_info "Enabling wpa_supplicant for wlan1..."
    systemctl enable wpa_supplicant@wlan1
    
    log_info "Enabling OpenVPN..."
    systemctl enable openvpn@nordvpn
    
    mark_phase_complete "phase10"
    log_success "PHASE 10: Enabling Services - COMPLETE"
}

###############################################################################
# Phase 11: Service Startup and Verification
###############################################################################

phase11_start_services() {
    log_info "=========================================="
    log_info "PHASE 11: Starting Services - BEGIN"
    log_info "=========================================="
    
    if is_phase_complete "phase11"; then
        log_success "Phase 11 already completed"
        log_info "Skipping Phase 11"
        return 0
    fi
    
    log_info "Unblocking WiFi with rfkill..."
    rfkill unblock wifi
    rfkill unblock all
    
    log_info "Restarting dhcpcd..."
    systemctl restart dhcpcd
    sleep 3
    
    log_info "Starting hostapd..."
    systemctl start hostapd
    sleep 2
    
    log_info "Starting dnsmasq..."
    systemctl start dnsmasq
    sleep 2
    
    log_info "Starting wpa_supplicant for wlan1..."
    systemctl start wpa_supplicant@wlan1
    sleep 5
    
    log_info "Starting OpenVPN..."
    systemctl start openvpn@nordvpn
    sleep 10
    
    mark_phase_complete "phase11"
    log_success "PHASE 11: Starting Services - COMPLETE"
}

###############################################################################
# Phase 12: System Verification
###############################################################################

phase12_verification() {
    log_info "=========================================="
    log_info "PHASE 12: System Verification - BEGIN"
    log_info "=========================================="
    
    echo ""
    log_info "Checking service status..."
    echo ""
    
    services=("hostapd" "dnsmasq" "wpa_supplicant@wlan1" "openvpn@nordvpn")
    all_good=true
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            log_success "$service: RUNNING"
        else
            log_error "$service: FAILED"
            all_good=false
        fi
    done
    
    echo ""
    log_info "Checking network interfaces..."
    echo ""
    
    interfaces=("wlan0" "wlan1" "eth0" "tun0")
    for iface in "${interfaces[@]}"; do
        if ip link show "$iface" &> /dev/null; then
            status=$(ip addr show "$iface" | grep "inet " | awk '{print $2}' || echo "No IP")
            log_success "$iface: UP ($status)"
        else
            log_warning "$iface: NOT FOUND"
            if [ "$iface" = "tun0" ]; then
                log_info "VPN may still be connecting..."
            fi
        fi
    done
    
    echo ""
    log_info "Checking wlan1 connection..."
    if iw wlan1 link | grep -q "Connected"; then
        ssid=$(iw wlan1 link | grep SSID | awk '{print $2}')
        log_success "wlan1 connected to: $ssid"
    else
        log_warning "wlan1 not connected to WiFi"
    fi
    
    echo ""
    log_info "Checking internet connectivity..."
    if ping -c 3 -W 5 8.8.8.8 &> /dev/null; then
        log_success "Internet connectivity: OK"
    else
        log_warning "Internet connectivity: FAILED"
        log_info "This may be normal if VPN is still connecting"
    fi
    
    echo ""
    if [ "$all_good" = true ]; then
        mark_phase_complete "phase12"
        log_success "=========================================="
        log_success "PHASE 12: System Verification - COMPLETE"
        log_success "Installation Complete!"
        log_success "=========================================="
    else
        mark_phase_complete "phase12"
        log_warning "=========================================="
        log_warning "PHASE 12: System Verification - COMPLETE (with warnings)"
        log_warning "Installation completed with warnings"
        log_warning "=========================================="
    fi
}

###############################################################################
# Main Installation Flow
###############################################################################

main() {
    clear
    echo "=========================================="
    echo "  Raspberry Pi Travel VPN Router Setup"
    echo "=========================================="
    echo ""
    
    check_root
    check_raspberry_pi
    
    # Show installation status if any phases are complete
    if [ -f "$STATE_FILE" ]; then
        echo ""
        log_info "Installation Status:"
        for i in {1..12}; do
            if is_phase_complete "phase$i"; then
                echo -e "  ${GREEN}✓${NC} Phase $i: Complete"
            else
                echo -e "  ${YELLOW}○${NC} Phase $i: Pending"
            fi
        done
        echo ""
        log_info "Resuming installation from next incomplete phase..."
    fi
    
    echo ""
    log_warning "This script will install and configure:"
    echo "  - USB WiFi drivers"
    echo "  - Access Point (hostapd)"
    echo "  - DHCP Server (dnsmasq)"
    echo "  - VPN Client (OpenVPN + NordVPN)"
    echo "  - Firewall and routing rules"
    echo ""
    log_warning "Existing configurations will be backed up"
    echo ""
    prompt_continue
    
    # Execute installation phases
    phase1_system_prep
    phase2_wifi_driver
    phase3_network_interfaces
    phase4_access_point
    phase5_dhcp_server
    phase6_wifi_client
    phase7_vpn_setup
    phase8_routing_firewall
    phase9_startup_script
    phase10_enable_services
    phase11_start_services
    phase12_verification
    
    echo ""
    echo "=========================================="
    echo "Next Steps:"
    echo "=========================================="
    echo "1. Connect your device to WiFi: $AP_SSID"
    echo "2. Wait 30 seconds for VPN to establish"
    echo "3. Test VPN: curl ifconfig.me"
    echo "4. Check logs: tail -f /var/log/travel-router-install.log"
    echo ""
    echo "Management Access:"
    echo "  SSH: ssh pi@192.168.100.2 (via Ethernet)"
    echo ""
    echo "Helper Scripts:"
    echo "  - ./connect-wifi.sh - Connect to new WiFi"
    echo "  - ./change-vpn.sh - Change VPN server"
    echo "  - ./router-status.sh - Check system status"
    echo ""
    log_info "Full installation log: $LOGFILE"
    echo "=========================================="
}

# Run main installation
main
