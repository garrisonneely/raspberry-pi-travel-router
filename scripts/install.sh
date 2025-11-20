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
# Phase 0: Reset/Cleanup Function
###############################################################################

phase0_reset() {
    log_warning "=========================================="
    log_warning "RESET MODE: Cleaning up previous installation"
    log_warning "=========================================="
    
    log_info "Stopping services..."
    systemctl stop openvpn@nordvpn 2>/dev/null || true
    systemctl stop wpa_supplicant@wlan1 2>/dev/null || true
    systemctl stop hostapd 2>/dev/null || true
    systemctl stop dnsmasq 2>/dev/null || true
    
    log_info "Killing DHCP clients..."
    pkill -f "dhcpcd.*wlan1" 2>/dev/null || true
    pkill -f "dhclient.*wlan1" 2>/dev/null || true
    systemctl stop systemd-networkd 2>/dev/null || true
    
    log_info "Disabling services..."
    systemctl disable hostapd 2>/dev/null || true
    systemctl disable dnsmasq 2>/dev/null || true
    systemctl disable wpa_supplicant@wlan1 2>/dev/null || true
    systemctl disable openvpn@nordvpn 2>/dev/null || true
    systemctl disable systemd-networkd 2>/dev/null || true
    
    log_info "Removing DKMS driver modules..."
    # Remove both possible drivers
    dkms remove rtl8814au/5.8.5.1 --all 2>/dev/null || true
    dkms remove rtl8812au/5.13.6 --all 2>/dev/null || true
    
    log_info "Removing driver source directories..."
    rm -rf /usr/src/rtl8814au-5.8.5.1 2>/dev/null || true
    rm -rf /usr/src/rtl8812au-5.13.6 2>/dev/null || true
    rm -rf /tmp/8814au 2>/dev/null || true
    rm -rf /tmp/8812au-20210820 2>/dev/null || true
    
    log_info "Removing configuration files..."
    rm -f /etc/hostapd/hostapd.conf 2>/dev/null || true
    rm -f /etc/dnsmasq.conf 2>/dev/null || true
    rm -f /etc/wpa_supplicant/wpa_supplicant-wlan1.conf 2>/dev/null || true
    rm -f /etc/openvpn/nordvpn.conf 2>/dev/null || true
    rm -f /etc/openvpn/nordvpn.auth 2>/dev/null || true
    rm -f /etc/default/hostapd 2>/dev/null || true
    
    log_info "Removing NetworkManager configurations..."
    rm -f /etc/NetworkManager/conf.d/unmanaged.conf 2>/dev/null || true
    rm -f /etc/NetworkManager/conf.d/10-unmanaged-eth0.conf 2>/dev/null || true
    rm -f /etc/NetworkManager/system-connections/eth0-static.nmconnection 2>/dev/null || true
    
    log_info "Removing systemd-networkd configurations..."
    rm -f /etc/systemd/network/10-eth0.network 2>/dev/null || true
    
    log_info "Restoring backup files..."
    if [ -f /etc/dhcpcd.conf.backup ]; then
        mv /etc/dhcpcd.conf.backup /etc/dhcpcd.conf
    fi
    if [ -f /etc/sysctl.conf.backup ]; then
        mv /etc/sysctl.conf.backup /etc/sysctl.conf
    fi
    
    log_info "Flushing iptables rules..."
    iptables -F 2>/dev/null || true
    iptables -t nat -F 2>/dev/null || true
    iptables -X 2>/dev/null || true
    iptables -t nat -X 2>/dev/null || true
    netfilter-persistent save 2>/dev/null || true
    
    log_info "Removing state file..."
    rm -f "$STATE_FILE" 2>/dev/null || true
    
    log_info "Restarting NetworkManager to restore defaults..."
    systemctl restart NetworkManager 2>/dev/null || true
    
    log_info "Bringing interfaces down..."
    ip link set wlan0 down 2>/dev/null || true
    ip link set wlan1 down 2>/dev/null || true
    
    log_success "=========================================="
    log_success "Reset complete! System is now clean."
    log_success "=========================================="
    log_info "You can now run this script again for a fresh installation."
    log_info "Reboot recommended: sudo reboot"
    
    exit 0
}

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
    model=$(tr -d '\0' < /proc/device-tree/model)
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
        iptables iptables-persistent rfkill net-tools wireless-tools bc \
        isc-dhcp-client || \
        { log_error "Failed to install required packages"; exit 1; }
    
    log_info "Configuring ethernet static IP for management access..."
    
    # Configure eth0 with static IP using NetworkManager (modern, Desktop OS compatible)
    log_info "Configuring eth0 with NetworkManager..."
    
    # First, ensure NetworkManager is managing eth0 (remove any unmanaged config)
    rm -f /etc/NetworkManager/conf.d/10-unmanaged-eth0.conf 2>/dev/null || true
    
    # Get the current wired connection name (usually "Wired connection 1")
    ETH0_CONNECTION=$(nmcli -t -f NAME,DEVICE connection show | grep "eth0" | cut -d: -f1 | head -n1)
    
    if [ -z "$ETH0_CONNECTION" ]; then
        log_info "No existing connection found, creating new connection for eth0..."
        nmcli connection add type ethernet con-name "eth0-static" ifname eth0 \
            ipv4.addresses 192.168.100.2/24 \
            ipv4.method manual \
            connection.autoconnect yes
        ETH0_CONNECTION="eth0-static"
    else
        log_info "Found existing connection: $ETH0_CONNECTION"
        # Modify existing connection to use static IP
        nmcli connection modify "$ETH0_CONNECTION" \
            ipv4.addresses 192.168.100.2/24 \
            ipv4.method manual \
            connection.autoconnect yes
    fi
    
    # Apply the connection immediately
    nmcli connection up "$ETH0_CONNECTION" 2>/dev/null || true
    
    # Ensure systemd-networkd is disabled (NetworkManager is in control)
    systemctl stop systemd-networkd 2>/dev/null || true
    systemctl disable systemd-networkd 2>/dev/null || true
    
    # Remove any conflicting systemd-networkd configs
    rm -f /etc/systemd/network/10-eth0.network 2>/dev/null || true
    
    log_success "Ethernet configured with static IP: 192.168.100.2 (via NetworkManager)"
    log_success "Configuration persists across reboots"
    log_warning "You can now connect via Ethernet using: ssh pi@192.168.100.2"
    log_info "Recommended: Switch to Ethernet connection before Phase 2 to avoid WiFi disruptions"
    
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
    if (lsmod | grep -q "8812au" || lsmod | grep -q "8814au") && ip link show wlan1 &> /dev/null; then
        log_success "Driver already loaded and wlan1 interface detected"
        mark_phase_complete "phase2"
        log_info "Skipping Phase 2 - already complete"
        return 0
    fi
    
    log_info "Detecting USB WiFi adapter..."
    
    # Detect which Realtek chipset is present
    DRIVER_REPO=""
    DRIVER_NAME=""
    DRIVER_DIR=""
    
    if lsusb | grep -q "0846:9054"; then
        # Netgear A7000 - RTL8814AU
        log_info "Detected: Netgear A7000 (RTL8814AU chipset)"
        DRIVER_REPO="https://github.com/morrownr/8814au.git"
        DRIVER_NAME="8814au"
        DRIVER_DIR="8814au"
    elif lsusb | grep -q "0bda:8812"; then
        # RTL8812AU chipset
        log_info "Detected: RTL8812AU chipset"
        DRIVER_REPO="https://github.com/morrownr/8812au-20210820.git"
        DRIVER_NAME="8812au"
        DRIVER_DIR="8812au-20210820"
    else
        log_error "FATAL: No supported USB WiFi adapter detected"
        log_error "Supported adapters:"
        log_error "  - Netgear A7000 (RTL8814AU chipset)"
        log_error "  - RTL8812AU chipset adapters"
        log_error ""
        log_error "Connected USB devices:"
        lsusb
        log_error ""
        log_error "Please connect a supported USB WiFi adapter and reboot"
        exit 1
    fi
    
    log_info "Checking for existing driver installation..."
    if lsmod | grep -q "$DRIVER_NAME"; then
        log_warning "Driver $DRIVER_NAME already loaded"
        read -p "$(echo -e ${YELLOW}Reinstall driver? [y/N]:${NC} )" -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Skipping driver installation"
            return
        fi
    fi
    
    log_info "Cloning $DRIVER_NAME driver repository..."
    cd /tmp
    if [ -d "$DRIVER_DIR" ]; then
        rm -rf "$DRIVER_DIR"
    fi
    git clone "$DRIVER_REPO" || \
        { log_error "Failed to clone driver repository"; exit 1; }
    
    cd "$DRIVER_DIR"
    log_info "Installing $DRIVER_NAME driver (this may take several minutes)..."
    
    # Run installation with defaults (no interactive prompts)
    # The driver installation may ask to edit options - we skip this for automated setup
    echo -e "n\ny" | ./install-driver.sh || { log_error "Driver installation failed"; exit 1; }
    
    mark_phase_complete "phase2"
    log_success "PHASE 2: USB WiFi Driver Installation - COMPLETE"
    log_warning "System will reboot to load the driver..."
    log_info ""
    log_info "=========================================="
    log_info "IMPORTANT: After reboot, connect via Ethernet!"
    log_info "=========================================="
    log_info "Ethernet IP: 192.168.100.2"
    log_info "Command: ssh pi@192.168.100.2"
    log_info ""
    log_info "Using Ethernet prevents WiFi configuration issues"
    log_info "from disrupting your SSH connection."
    log_info "=========================================="
    log_info ""
    log_info "After reconnecting, run:"
    log_info "  cd ~/raspberry-pi-travel-router"
    log_info "  sudo bash scripts/install.sh"
    log_info "=========================================="
    
    # Verify wlan1 will exist after reboot by checking driver compilation
    if [ ! -d "/var/lib/dkms/$DRIVER_NAME" ]; then
        log_error "FATAL: Driver DKMS installation failed"
        log_error "The wlan1 interface will not be available after reboot"
        log_error "Check /var/log/travel-router-install.log for details"
        exit 1
    fi
    
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
    
    log_warning "IMPORTANT: Phase 3 configures static IPs but does NOT apply them immediately"
    log_warning "Static IPs will be applied in Phase 11 when all services start"
    log_warning "This prevents network connectivity issues during installation"
    
    # Check if dhcpcd is being used
    if [ -f /etc/dhcpcd.conf ]; then
        log_info "Backing up existing dhcpcd.conf..."
        cp /etc/dhcpcd.conf /etc/dhcpcd.conf.backup 2>/dev/null || true
        
        log_info "Configuring static IP addresses in dhcpcd..."
        
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

# Note: eth0 is managed by systemd-networkd (configured in Phase 1)

interface wlan1
    env wpa_supplicant_conf=/etc/wpa_supplicant/wpa_supplicant-wlan1.conf
EOF
        
        log_info "Network configuration written to /etc/dhcpcd.conf"
    else
        log_info "dhcpcd not found - system uses NetworkManager or systemd-networkd"
        log_info "Will configure network interfaces directly in Phase 11"
    fi
    
    log_info "Note: eth0 already configured via systemd-networkd in Phase 1"
    log_info "Static IPs will be applied when services start in Phase 11"
    
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
    
    # Prompt for SSID and password with timeout for defaults
    log_info "Press Enter to use default values or type custom values..."
    read -t 5 -p "Enter Access Point SSID [GKTravelRouter]: " AP_SSID || true
    AP_SSID=${AP_SSID:-GKTravelRouter}
    
    read -t 5 -p "Enter Access Point Password [CABOFUN1]: " AP_PASSWORD || true
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
    
    log_info "Enter WiFi network credentials to connect to..."
    read -t 10 -p "Enter WiFi network SSID: " WIFI_SSID || true
    if [ -z "$WIFI_SSID" ]; then
        log_error "WiFi SSID is required"
        exit 1
    fi
    
    read -t 10 -sp "Enter WiFi network password: " WIFI_PASSWORD || true
    echo
    if [ -z "$WIFI_PASSWORD" ]; then
        log_error "WiFi password is required"
        exit 1
    fi
    
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
    
    log_info "Press Enter to use default server or type custom server..."
    read -t 5 -p "Enter NordVPN server [us9952.nordvpn.com]: " VPN_SERVER || true
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
    read -t 10 -p "NordVPN service username: " NORD_USER || true
    if [ -z "$NORD_USER" ]; then
        log_error "NordVPN username is required"
        exit 1
    fi
    
    read -t 10 -sp "NordVPN service password: " NORD_PASS || true
    echo
    if [ -z "$NORD_PASS" ]; then
        log_error "NordVPN password is required"
        exit 1
    fi
    
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
    # Create sysctl.conf if it doesn't exist
    touch /etc/sysctl.conf
    
    # Enable IP forwarding
    if grep -q "^net.ipv4.ip_forward" /etc/sysctl.conf; then
        sed -i 's/^#*net.ipv4.ip_forward.*/net.ipv4.ip_forward=1/' /etc/sysctl.conf
    else
        echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
    fi
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
    
    log_info "Configuring network interfaces..."
    
    # CRITICAL: Force NetworkManager to release wlan0/wlan1 IMMEDIATELY
    if systemctl is-active --quiet NetworkManager; then
        log_info "Forcing NetworkManager to release wireless interfaces..."
        
        # Create unmanaged config for wireless interfaces only (eth0 stays managed)
        mkdir -p /etc/NetworkManager/conf.d
        cat > /etc/NetworkManager/conf.d/unmanaged.conf << 'EOF'
[keyfile]
unmanaged-devices=interface-name:wlan0;interface-name:wlan1
EOF
        
        # Force NetworkManager to immediately unmanage the wireless interfaces
        nmcli device set wlan0 managed no 2>/dev/null || true
        nmcli device set wlan1 managed no 2>/dev/null || true
        
        # Disconnect any active connections on wireless interfaces
        nmcli device disconnect wlan0 2>/dev/null || true
        nmcli device disconnect wlan1 2>/dev/null || true
        
        # Reload NetworkManager config without full restart (keeps eth0 stable)
        nmcli general reload 2>/dev/null || true
        
        log_success "NetworkManager released wireless interfaces"
        sleep 2
    fi
    
    # Bring down wireless interfaces to reset them
    ip link set wlan0 down 2>/dev/null || true
    ip link set wlan1 down 2>/dev/null || true
    sleep 1
    
    # Only restart dhcpcd if it exists and is active
    if systemctl list-unit-files | grep -q "^dhcpcd.service"; then
        if systemctl is-active --quiet dhcpcd; then
            log_info "Restarting dhcpcd..."
            systemctl restart dhcpcd
            sleep 3
        fi
    fi
    
    # Configure wlan0 with static IP for AP
    log_info "Configuring wlan0 with static IP..."
    ip addr flush dev wlan0 2>/dev/null || true
    ip link set wlan0 up
    ip addr add 192.168.4.1/24 dev wlan0
    sleep 2
    
    log_info "Starting hostapd..."
    systemctl restart hostapd
    sleep 3
    
    log_info "Starting dnsmasq..."
    systemctl restart dnsmasq
    sleep 2
    
    # Check if wlan1 exists, if not try to load the driver
    if ! ip link show wlan1 &> /dev/null; then
        log_warning "wlan1 interface not found, attempting to load driver..."
        modprobe 8812au 2>/dev/null || modprobe 8814au 2>/dev/null || true
        sleep 3
        
        if ! ip link show wlan1 &> /dev/null; then
            log_error "wlan1 interface still not found after loading driver"
            log_error "Please ensure USB WiFi adapter is connected"
            log_info "Detected USB devices:"
            lsusb | grep -i "realtek\|netgear" || log_warning "No Realtek/Netgear USB devices found"
            log_info ""
            log_info "To fix: ensure adapter is plugged in, then reboot and re-run:"
            log_info "  sudo reboot"
            log_info "After reboot:"
            log_info "  sudo rm /var/lib/travel-router-install.state"
            log_info "  sudo bash scripts/install.sh"
            exit 1
        fi
    fi
    
    # Bring up wlan1 for WiFi client
    log_info "Bringing up wlan1..."
    ip link set wlan1 up
    sleep 2
    
    log_info "Starting wpa_supplicant for wlan1..."
    systemctl restart wpa_supplicant@wlan1
    sleep 5
    
    # Verify wlan1 connection
    log_info "Waiting for wlan1 to connect..."
    WIFI_CONNECTED=false
    for i in {1..10}; do
        if iw wlan1 link | grep -q "Connected"; then
            log_success "wlan1 connected successfully"
            WIFI_CONNECTED=true
            break
        fi
        log_info "Waiting for connection... ($i/10)"
        sleep 2
    done
    
    if [ "$WIFI_CONNECTED" = false ]; then
        log_error "FATAL: wlan1 failed to connect to WiFi"
        log_error "SSID: $WIFI_SSID"
        log_error ""
        log_error "Possible causes:"
        log_error "  - Incorrect WiFi password"
        log_error "  - SSID not in range"
        log_error "  - WiFi network issues"
        log_error ""
        log_error "Check wpa_supplicant logs:"
        log_error "  sudo journalctl -u wpa_supplicant@wlan1 -n 50"
        log_error ""
        log_error "To retry with different credentials:"
        log_error "  sudo rm /var/lib/travel-router-install.state"
        log_error "  sudo bash scripts/install.sh"
        exit 1
    fi
    
    # Request DHCP lease for wlan1
    log_info "Requesting DHCP lease for wlan1..."
    
    # Try dhcpcd first (most common on Raspberry Pi OS)
    if command -v dhcpcd &> /dev/null; then
        log_info "Using dhcpcd for DHCP..."
        # Kill any existing dhcpcd for wlan1
        pkill -f "dhcpcd.*wlan1" 2>/dev/null || true
        sleep 1
        # Start dhcpcd for wlan1 in background
        dhcpcd -b wlan1
        sleep 5
    elif command -v dhclient &> /dev/null; then
        log_info "Using dhclient for DHCP..."
        pkill -f "dhclient.*wlan1" 2>/dev/null || true
        sleep 1
        dhclient -v wlan1 &
        sleep 5
    else
        log_error "No DHCP client found (dhcpcd or dhclient)"
        log_error "Install with: apt install -y isc-dhcp-client"
        exit 1
    fi
    
    # Verify wlan1 got an IP
    wlan1_ip=$(ip addr show wlan1 | grep "inet " | awk '{print $2}')
    if [ -n "$wlan1_ip" ]; then
        log_success "wlan1 received IP: $wlan1_ip"
    else
        log_error "FATAL: wlan1 did not receive IP address via DHCP"
        log_error ""
        log_error "Connected to WiFi but no IP assigned. Possible causes:"
        log_error "  - Hotel network requires captive portal authentication"
        log_error "  - DHCP server not responding"
        log_error "  - MAC address filtering on network"
        log_error "  - Network requires static IP assignment"
        log_error ""
        log_error "Debug information:"
        log_error "  WiFi connection: $(iw wlan1 link | grep SSID | awk '{print $2}')"
        log_error "  Signal level: $(iw wlan1 link | grep signal | awk '{print $2, $3}')"
        log_error ""
        log_error "Next steps:"
        log_error "  1. Check if network requires browser authentication"
        log_error "  2. Verify network allows your device's MAC address"
        log_error "  3. Try different WiFi network"
        log_error ""
        log_error "Check DHCP logs: sudo journalctl | grep dhcp | tail -30"
        exit 1
    fi
    
    log_info "Starting OpenVPN..."
    systemctl restart openvpn@nordvpn
    sleep 10
    
    # Verify VPN tunnel is up (CRITICAL)
    log_info "Verifying VPN tunnel..."
    if systemctl is-active --quiet openvpn@nordvpn; then
        log_success "VPN service is running"
        
        # Check for tun0 interface
        VPN_RETRIES=0
        while [ $VPN_RETRIES -lt 6 ]; do
            if ip link show tun0 &> /dev/null; then
                tun0_ip=$(ip addr show tun0 | grep "inet " | awk '{print $2}')
                if [ -n "$tun0_ip" ]; then
                    log_success "VPN tunnel active: $tun0_ip"
                    break
                fi
            fi
            VPN_RETRIES=$((VPN_RETRIES + 1))
            log_info "Waiting for VPN tunnel... ($VPN_RETRIES/6)"
            sleep 5
        done
        
        if [ $VPN_RETRIES -eq 6 ]; then
            log_error "FATAL: VPN service running but tun0 interface not created"
            log_error ""
            log_error "Possible causes:"
            log_error "  - Invalid NordVPN credentials"
            log_error "  - NordVPN server unreachable"
            log_error "  - OpenVPN configuration error"
            log_error ""
            log_error "Check logs: sudo journalctl -u openvpn@nordvpn -n 50"
            exit 1
        fi
    else
        log_error "FATAL: VPN service failed to start"
        log_error ""
        log_error "Check logs for errors:"
        log_error "  sudo journalctl -u openvpn@nordvpn -n 50"
        log_error ""
        log_error "Common issues:"
        log_error "  - Invalid NordVPN credentials"
        log_error "  - Missing OpenVPN configuration files"
        log_error "  - Network connectivity issues"
        exit 1
    fi
    
    # Verify eth0 static IP is still set (managed by NetworkManager)
    if ! ip addr show eth0 | grep -q "192.168.100.2"; then
        log_warning "eth0 static IP not found, checking NetworkManager..."
        # This shouldn't happen if Phase 1 configured it correctly
        nmcli connection up "eth0-static" 2>/dev/null || \
        nmcli connection up "Wired connection 1" 2>/dev/null || \
        log_error "Failed to activate eth0 connection via NetworkManager"
    else
        log_success "eth0 static IP verified: 192.168.100.2"
    fi
    
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
        log_error "FATAL: wlan1 not connected to WiFi"
        exit 1
    fi
    
    echo ""
    log_info "Checking internet connectivity through VPN..."
    INTERNET_OK=false
    for attempt in {1..3}; do
        if ping -c 2 -W 5 8.8.8.8 &> /dev/null; then
            log_success "Internet connectivity: OK"
            INTERNET_OK=true
            break
        fi
        log_info "Attempt $attempt/3 failed, retrying..."
        sleep 3
    done
    
    if [ "$INTERNET_OK" = false ]; then
        log_error "FATAL: No internet connectivity through VPN"
        log_error ""
        log_error "The travel router is non-functional without internet access"
        log_error ""
        log_error "Check routing:"
        log_error "  ip route show"
        log_error "Check VPN tunnel:"
        log_error "  ip addr show tun0"
        log_error "Check firewall rules:"
        log_error "  sudo iptables -t nat -L -v -n"
        log_error ""
        log_error "To debug:"
        log_error "  sudo bash scripts/router-health.sh"
        exit 1
    fi
    
    echo ""
    log_info "Final verification complete - all critical components operational"
    
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
    
    # Run comprehensive health check
    echo ""
    log_info "Running comprehensive health check..."
    echo ""
    
    # Try multiple paths to find the health check script
    HEALTH_CHECK_FOUND=false
    
    # Path 1: Same directory as install script
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -f "$SCRIPT_DIR/router-health.sh" ]; then
        bash "$SCRIPT_DIR/router-health.sh"
        HEALTH_CHECK_FOUND=true
    # Path 2: scripts directory relative to current directory
    elif [ -f "./scripts/router-health.sh" ]; then
        bash "./scripts/router-health.sh"
        HEALTH_CHECK_FOUND=true
    # Path 3: In repository root
    elif [ -f "$(pwd)/router-health.sh" ]; then
        bash "$(pwd)/router-health.sh"
        HEALTH_CHECK_FOUND=true
    # Path 4: Look for it anywhere in the repo
    elif [ -f ~/raspberry-pi-travel-router/scripts/router-health.sh ]; then
        bash ~/raspberry-pi-travel-router/scripts/router-health.sh
        HEALTH_CHECK_FOUND=true
    fi
    
    if [ "$HEALTH_CHECK_FOUND" = false ]; then
        log_warning "Health check script not found"
        log_info "You can manually run: sudo bash ~/raspberry-pi-travel-router/scripts/router-health.sh"
    fi
    
    # Install network initialization service for reboot persistence
    echo ""
    log_info "Installing network initialization service..."
    
    # Copy the init script to system location
    INIT_SCRIPT="$SCRIPT_DIR/travel-router-network-init.sh"
    if [ ! -f "$INIT_SCRIPT" ]; then
        # Try alternative path
        INIT_SCRIPT="./scripts/travel-router-network-init.sh"
    fi
    
    if [ -f "$INIT_SCRIPT" ]; then
        cp "$INIT_SCRIPT" /usr/local/bin/travel-router-network-init.sh
        chmod +x /usr/local/bin/travel-router-network-init.sh
        
        # Copy and enable service
        SERVICE_FILE="$SCRIPT_DIR/../config/travel-router-network.service"
        if [ ! -f "$SERVICE_FILE" ]; then
            SERVICE_FILE="./config/travel-router-network.service"
        fi
        
        if [ -f "$SERVICE_FILE" ]; then
            cp "$SERVICE_FILE" /etc/systemd/system/
            systemctl daemon-reload
            systemctl enable travel-router-network.service
            log_success "Network initialization service installed"
        else
            log_warning "Service file not found, skipping service installation"
        fi
    else
        log_warning "Init script not found, skipping service installation"
    fi
    
    echo ""
    log_success "Travel router setup complete!"
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
    
    # Offer reset option at the start
    echo ""
    log_info "Choose installation mode:"
    echo "  - Press 'r' within 10 seconds for RESET (clean up previous installation)"
    echo "  - Press Enter or wait 10 seconds for INSTALL (default)"
    echo ""
    
    read -t 10 -n 1 -p "$(echo -e ${YELLOW}Mode [Install/reset]:${NC} )" MODE_CHOICE || true
    echo ""
    
    if [[ "$MODE_CHOICE" =~ ^[Rr]$ ]]; then
        log_info "Reset mode selected"
        phase0_reset
    fi
    
    log_info "Install mode selected (default)"
    
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
    echo "  - ./scripts/router-health.sh - Comprehensive health check"
    echo "  - ./scripts/connect-wifi.sh - Connect to new WiFi"
    echo "  - ./scripts/change-vpn.sh - Change VPN server"
    echo "  - ./scripts/router-status.sh - Check system status"
    echo ""
    log_info "Full installation log: $LOGFILE"
    echo "=========================================="
}

# Run main installation
main
