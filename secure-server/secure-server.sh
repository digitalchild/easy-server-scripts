#!/bin/bash

# Secure Server Setup Script
# This script implements security best practices for Ubuntu servers

# Exit on any error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Function to print colored status messages
print_status() {
    echo -e "${GREEN}[+]${NC} $1"
}

print_error() {
    echo -e "${RED}[!]${NC} $1"
}

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run this script as root"
    exit 1
fi

# Update system packages
print_status "Updating system packages..."
apt update && apt upgrade -y

# Install required packages
print_status "Installing security packages..."
apt install -y ufw fail2ban clamav rkhunter unattended-upgrades

# Configure SSH
print_status "Configuring SSH..."
# Backup original SSH config
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

# Set new SSH port (default: 1337)
NEW_SSH_PORT=${1:-1337}
sed -i "s/#Port 22/Port $NEW_SSH_PORT/" /etc/ssh/sshd_config

# Enhance SSH security
sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/X11Forwarding yes/X11Forwarding no/' /etc/ssh/sshd_config
echo "MaxAuthTries 3" >> /etc/ssh/sshd_config
echo "AllowAgentForwarding no" >> /etc/ssh/sshd_config
echo "AllowTcpForwarding no" >> /etc/ssh/sshd_config

# Configure UFW (Uncomplicated Firewall)
print_status "Configuring firewall..."
ufw default deny incoming
ufw default allow outgoing
ufw allow $NEW_SSH_PORT/tcp
ufw allow 80/tcp
ufw allow 443/tcp
echo "y" | ufw enable

# Configure fail2ban
print_status "Configuring fail2ban..."
cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = $NEW_SSH_PORT
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
EOF

# Configure unattended-upgrades
print_status "Setting up automatic security updates..."
cat > /etc/apt/apt.conf.d/50unattended-upgrades << EOF
Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}-security";
    "\${distro_id}:\${distro_codename}-updates";
};
Unattended-Upgrade::Package-Blacklist {
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::InstallOnShutdown "false";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

cat > /etc/apt/apt.conf.d/20auto-upgrades << EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

# Setup ClamAV
print_status "Configuring antivirus (ClamAV)..."
systemctl stop clamav-freshclam
freshclam
systemctl start clamav-freshclam

# Setup daily malware scans
cat > /etc/cron.daily/malware-scan << EOF
#!/bin/bash
clamscan -r / --exclude-dir=/sys/ --exclude-dir=/proc/ --exclude-dir=/dev/ -l /var/log/clamav/daily-scan.log
rkhunter --check --skip-keypress --report-warnings-only
EOF
chmod +x /etc/cron.daily/malware-scan

# Secure shared memory
echo "tmpfs     /run/shm     tmpfs     defaults,noexec,nosuid     0     0" >> /etc/fstab

# Restart services
print_status "Restarting services..."
systemctl restart fail2ban
systemctl restart ssh

# Final message
print_status "Security setup complete! Please note the following:"
echo "1. SSH port has been changed to: $NEW_SSH_PORT"
echo "2. Root login has been disabled"
echo "3. Password authentication has been disabled"
echo "4. UFW is configured and enabled"
echo "5. fail2ban is configured and running"
echo "6. Automatic security updates are enabled"
echo "7. Daily malware scans are configured"
echo ""
echo "IMPORTANT: Make sure you:"
echo "- Have SSH key access configured before disconnecting"
echo "- Update your SSH client configuration with the new port"
echo "- Keep your SSH private key secure"

# Add warning if SSH key is not detected
if [ ! -f /root/.ssh/authorized_keys ] && [ ! -f /home/*/.ssh/authorized_keys ]; then
    print_error "No SSH keys detected! Make sure to add your SSH public key before disconnecting!"
fi

