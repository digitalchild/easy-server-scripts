# Secure Server Setup Script

A comprehensive bash script for securing Ubuntu servers using industry best practices. This script automates the process of implementing essential security measures to protect your server from common threats and vulnerabilities.

## 🛡️ Features

### SSH Hardening

- Custom SSH port configuration (default: 1337)
- Disabled root login
- SSH key-only authentication (password authentication disabled)
- Limited authentication attempts
- Disabled X11 and TCP forwarding

### Firewall Configuration

- UFW (Uncomplicated Firewall) setup
- Default deny incoming traffic
- Default allow outgoing traffic
- Only essential ports opened:
  - Custom SSH port
  - HTTP (80)
  - HTTPS (443)

### Intrusion Prevention

- Fail2ban installation and configuration
- Ban time: 1 hour
- Maximum retry attempts: 3 within 10 minutes
- Automatic IP blocking for failed SSH attempts

### Malware Protection

- ClamAV antivirus installation and setup
- Rootkit Hunter (rkhunter) installation
- Daily automated malware scans
- Scan logs stored in `/var/log/clamav/`

### Automatic Updates

- Unattended security updates
- Regular system updates
- Automatic package cleanup
- Configurable update settings

### Additional Security Measures

- Secured shared memory configuration
- System logging and monitoring
- Comprehensive error checking
- Backup of original configurations

## 📋 Prerequisites

- Ubuntu Server (recommended: 20.04 LTS or newer)
- Root or sudo privileges
- SSH access to the server
- SSH key pair (required for secure access)
- A non-root user with sudo privileges (see setup instructions below)

### Creating a Sudo User

Before running the security script, create a new user with sudo privileges:

1. Create a new user:
   ```bash
   sudo adduser your_username
   ```

2. Add the user to sudo group:
   ```bash
   sudo usermod -aG sudo your_username
   ```

3. Switch to the new user:
   ```bash
   su - your_username
   ```

4. Verify sudo access:
   ```bash
   sudo whoami
   ```
   This should return "root"

5. Set up SSH key for the new user:
   ```bash
   mkdir -p ~/.ssh
   chmod 700 ~/.ssh
   nano ~/.ssh/authorized_keys
   # Paste your public SSH key here
   chmod 600 ~/.ssh/authorized_keys
   ```

## 🚀 Installation

1. Clone this repository or download the script:

   ```bash
   git clone <repository-url>
   cd server-setup
   ```

2. Make the script executable:

   ```bash
   chmod +x secure-server.sh
   ```

3. Run the script as root:

   ```bash
   sudo ./secure-server.sh [custom_ssh_port]
   ```

   Replace `[custom_ssh_port]` with your desired SSH port number (optional, defaults to 1337)

## ⚠️ Important Notes

1. **BEFORE RUNNING THE SCRIPT:**
   - Create a new user with sudo privileges (see Prerequisites section)
   - Ensure you have SSH key access configured for the new user
   - Keep a backup of your SSH private key
   - Test your SSH key login works with the new user
   - Verify sudo privileges work correctly for the new user

2. **AFTER RUNNING THE SCRIPT:**
   - Update your SSH client configuration with the new port
   - Test the new SSH connection before closing existing sessions
   - Verify all security measures are active
   - Test logging in with your new sudo user
   - Verify you can execute sudo commands

3. **SECURITY MEASURES:**
   - Root login will be disabled
   - Password authentication will be disabled
   - Only SSH key authentication will be allowed
   - UFW firewall will be enabled
   - Fail2ban will be active
   - Root account direct access will be blocked

## 🔍 Verification

After running the script, you can verify the security measures:

1. Check SSH configuration:

   ```bash
   sudo sshd -T
   ```

2. Verify UFW status:

   ```bash
   sudo ufw status verbose
   ```

3. Check Fail2ban status:

   ```bash
   sudo fail2ban-client status
   ```

4. Verify ClamAV installation:

   ```bash
   clamscan --version
   ```

5. Verify your sudo user access:

   ```bash
   sudo -l
   ```

## 📝 Logs

- Fail2ban logs: `/var/log/fail2ban.log`
- ClamAV scan logs: `/var/log/clamav/daily-scan.log`
- SSH logs: `/var/log/auth.log`
- UFW logs: `/var/log/ufw.log`

## 🔧 Customization

The script includes default configurations that can be modified:

- SSH port (default: 1337)
- Fail2ban settings in `/etc/fail2ban/jail.local`
- UFW rules
- Unattended upgrade settings in `/etc/apt/apt.conf.d/50unattended-upgrades`

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## ⚡ Support

For issues, questions, or contributions, please open an issue in the repository.

## 🔒 Security Best Practices

Remember to:

- Regularly monitor system logs
- Keep the system updated
- Periodically review and update security configurations
- Maintain secure backups
- Monitor for suspicious activities
- Keep SSH keys secure and protected
- Regularly audit user accounts and their permissions
- Never share sudo passwords or SSH keys
- Use strong passwords for all accounts
