#!/bin/bash
#############################################
# Travel Router Network Initialization
# Configures wlan0 (AP) and wlan1 (client) on boot
#############################################

set -e

# Configure wlan0 for Access Point
echo "Configuring wlan0 (Access Point)..."
ip addr flush dev wlan0 2>/dev/null || true
ip link set wlan0 up 2>/dev/null || true
sleep 1
ip addr add 192.168.4.1/24 dev wlan0 2>/dev/null || true
echo "wlan0 configured with 192.168.4.1/24"

# Wait for wlan1 to be up
echo "Waiting for wlan1..."
for i in {1..30}; do
    if ip link show wlan1 &>/dev/null && [ "$(cat /sys/class/net/wlan1/operstate 2>/dev/null)" = "up" ]; then
        break
    fi
    sleep 1
done

# Wait for WiFi connection
for i in {1..30}; do
    if iw wlan1 link 2>/dev/null | grep -q "Connected"; then
        break
    fi
    sleep 1
done

# Kill any stale DHCP clients
pkill -f "dhcpcd.*wlan1" 2>/dev/null || true
pkill -f "dhclient.*wlan1" 2>/dev/null || true
sleep 1

# Request DHCP lease
if command -v dhcpcd &> /dev/null; then
    dhcpcd -b wlan1
elif command -v dhclient &> /dev/null; then
    dhclient wlan1
fi

# Wait for IP (up to 30 seconds)
for i in {1..30}; do
    if ip -4 addr show wlan1 | grep -q "inet "; then
        exit 0
    fi
    sleep 1
done

# If we get here, DHCP failed
exit 1
