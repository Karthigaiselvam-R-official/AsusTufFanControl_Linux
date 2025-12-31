#!/bin/bash

# ASUS TUF F15 Fan Controller Setup Script for Kali Linux
# Run as root: sudo ./setup.sh

set -e

echo "=========================================="
echo "ASUS TUF F15 Fan Controller Setup"
echo "=========================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "ERROR: This script must be run as root (sudo ./setup.sh)"
    exit 1
fi

echo "[1/7] Installing dependencies..."
apt-get update
apt-get install -y \
    build-essential \
    qt6-base-dev \
    qt6-declarative-dev \
    qml6-module-qtquick \
    qml6-module-qtquick-controls \
    qml6-module-qtquick-layouts \
    cmake \
    git \
    linux-headers-$(uname -r) \
    dkms \
    acpi \
    lm-sensors \
    i2c-tools

echo "[2/7] Building ec_probe tool..."
# Security Fix: Use mktemp -d to prevent symlink attacks in /tmp
WORK_DIR=$(mktemp -d)
cd "$WORK_DIR"
echo "Working in secure temp directory: $WORK_DIR"

# Download and build ec_probe if not exists
if [ ! -f /bin/ec_probe ]; then
    cat > ec_probe.c << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/io.h>
#include <string.h>

#define EC_DATA 0x62
#define EC_SC 0x66

#define IBF 1
#define OBF 0

static inline int wait_ec(const uint32_t port, const uint32_t flag, const char value) {
    int timeout = 10000;
    while ((inb(port) >> flag & 1) != value && --timeout > 0)
        usleep(10);
    return timeout;
}

static uint8_t read_ec(const uint32_t port) {
    if (!wait_ec(EC_SC, IBF, 0)) return 0;
    outb(0x80, EC_SC);
    if (!wait_ec(EC_SC, IBF, 0)) return 0;
    outb(port, EC_DATA);
    if (!wait_ec(EC_SC, OBF, 1)) return 0;
    return inb(EC_DATA);
}

static int write_ec(const uint32_t port, const uint8_t value) {
    if (!wait_ec(EC_SC, IBF, 0)) return 0;
    outb(0x81, EC_SC);
    if (!wait_ec(EC_SC, IBF, 0)) return 0;
    outb(port, EC_DATA);
    if (!wait_ec(EC_SC, IBF, 0)) return 0;
    outb(value, EC_DATA);
    if (!wait_ec(EC_SC, IBF, 0)) return 0;
    return 1;
}

int main(int argc, char *argv[]) {
    if (argc < 3) {
        fprintf(stderr, "Usage: %s <read|write> <register> [value]\n", argv[0]);
        return 1;
    }

    if (iopl(3) < 0) {
        perror("iopl");
        fprintf(stderr, "Error: Need root privileges\n");
        return 1;
    }

    int reg = strtol(argv[2], NULL, 0);

    if (strcmp(argv[1], "read") == 0) {
        printf("0x%02x\n", read_ec(reg));
    } else if (strcmp(argv[1], "write") == 0 && argc == 4) {
        int val = strtol(argv[3], NULL, 0);
        if (write_ec(reg, val)) {
            printf("OK\n");
        } else {
            printf("FAIL\n");
            return 1;
        }
    } else {
        fprintf(stderr, "Invalid command\n");
        return 1;
    }

    return 0;
}
EOF

    gcc -O2 ec_probe.c -o ec_probe
    chmod +x ec_probe
    mv ec_probe /bin/ec_probe
    echo "✓ ec_probe installed to /bin/ec_probe"
else
    echo "✓ ec_probe already installed"
fi

echo "[3/7] Ensuring ASUS WMI drivers are enabled (Required for Turbo Policy)..."
# We used to blacklist these, but we NEED them for throttle_thermal_policy
rm -f /etc/modprobe.d/asus-fan-blacklist.conf
sed -i '/blacklist asus/d' /etc/modprobe.d/* 2>/dev/null || true

echo "✓ WMI Blacklist removed"

echo "[4/7] Creating udev rules for EC access..."
cat > /etc/udev/rules.d/99-ec-access.rules << EOF
# Allow EC access without root
KERNEL=="port", MODE="0666"
EOF

udevadm control --reload-rules
udevadm trigger

echo "[5/7] Configuring lm-sensors..."
sensors-detect --auto

echo "[6/7] Creating startup script..."
cat > /usr/local/bin/asus-fan-prepare.sh << 'EOF'
#!/bin/bash
# Prepare system for fan control

# Remove kernel modules
# Ensure WMI modules are loaded
modprobe asus_nb_wmi 2>/dev/null || true
modprobe asus_wmi 2>/dev/null || true

# Load required modules
modprobe coretemp
modprobe i2c-dev

echo "ASUS Fan Control: System prepared"
EOF

chmod +x /usr/local/bin/asus-fan-prepare.sh

# Create systemd service
cat > /etc/systemd/system/asus-fan-prepare.service << EOF
[Unit]
Description=Prepare ASUS Fan Control
Before=display-manager.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/asus-fan-prepare.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable asus-fan-prepare.service

echo "✓ Startup service created"

echo "[7/8] Installing Desktop Integration..."

# Create installation directory
INSTALL_DIR="/opt/asus-tuf-fan-control"
mkdir -p "$INSTALL_DIR"

# Copy polkit policy
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/org.asus.fancontrol.policy" ]; then
    cp "$SCRIPT_DIR/org.asus.fancontrol.policy" /usr/share/polkit-1/actions/
    echo "✓ Polkit policy installed"
fi

# Copy desktop file
if [ -f "$SCRIPT_DIR/asus-tuf-fan-control.desktop" ]; then
    cp "$SCRIPT_DIR/asus-tuf-fan-control.desktop" /usr/share/applications/
    echo "✓ Desktop launcher installed"
fi

# Copy app icon
if [ -f "$SCRIPT_DIR/ui/app_icon.png" ]; then
    cp "$SCRIPT_DIR/ui/app_icon.png" "$INSTALL_DIR/"
    echo "✓ Application icon installed"
fi

echo "[8/8] Building Qt application..."

# Note: User should build the Qt app in their project directory
echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Reboot your system: sudo reboot"
echo "2. After reboot, cd to your project directory"
echo "3. Build the application:"
echo "   mkdir build && cd build"
echo "   cmake .."
echo "   make"
echo "4. Install the binary:"
echo "   sudo cp AsusTufFanControl_Linux /opt/asus-tuf-fan-control/"
echo ""
echo "5. Launch from Applications menu or run:"
echo "   /opt/asus-tuf-fan-control/AsusTufFanControl_Linux"
echo ""
echo "To test EC access right now:"
echo "  sudo ec_probe read 0"
echo "  sudo ec_probe read 0xB0"
echo ""
echo "=========================================="