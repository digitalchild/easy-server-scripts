# Telegram MTProto Proxy

An automated shell script for setting up a Telegram MTProto proxy server on Ubuntu VPS using the **official Telegram Docker image**. This proxy allows users to connect to Telegram when direct access is restricted or blocked.

## Features

- **Official Docker Image**: Uses the reliable `telegrammessenger/proxy:latest` image
- **Automated Installation**: Shell script setup with minimal user interaction
- **Random Padding Support**: Enhanced stealth capabilities to avoid ISP detection
- **Daily Config Updates**: Automatic Telegram configuration updates via cron job
- **Automatic Configuration**: Generates secure secrets and handles firewall setup
- **QR Code Support**: Displays connection QR code for easy mobile setup
- **Persistent Configuration**: Saves settings for easy management
- **Firewall Integration**: Automatically configures UFW firewall rules

## Prerequisites

- Ubuntu/Debian-based Linux VPS
- Root access or sudo privileges
- Internet connection
- Public IP address

## Installation

1. **SSH into your Ubuntu VPS and download the script:**
   ```bash
   wget https://raw.githubusercontent.com/digitalchild/easy-server-scripts/main/telegram-proxy/install-mtproxy.sh
   chmod +x install-mtproxy.sh
   ```

2. **Run the installation script:**
   ```bash
   sudo ./install-mtproxy.sh
   ```

3. **Follow the prompts:**
   - Choose proxy port (default: 14443)
   - Confirm or regenerate MTProto secret

4. **Use the provided connection link or QR code to connect from Telegram**

## What the Script Does

### Automatic Setup
- Installs Docker and Docker Compose if not present
- Creates installation directory at `/opt/apps/telegram-proxy`
- **Downloads official Telegram MTProxy Docker image**
- Generates secure MTProto secret (32 character hex)
- Configures firewall rules (UFW)
- Sets up daily configuration updates via cron job
- Creates and starts Docker container

### Generated Files
- **`/opt/apps/telegram-proxy/.env`** - Contains configuration (port, secret)
- **`/opt/apps/telegram-proxy/docker-compose.yml`** - Container definition
- **`/opt/apps/telegram-proxy/update-proxy.sh`** - Daily update script
- **`/opt/apps/telegram-proxy/stats/`** - Optional stats directory

## Configuration

### Default Settings
- **Port**: 14443 (commonly unblocked port)
- **Image**: Official `telegrammessenger/proxy:latest`
- **Restart Policy**: Always restart on failure
- **Daily Updates**: Automatic via cron at 4 AM

### Environment Variables
The `.env` file contains:
```bash
PROXY_PORT=14443
MTPROTO_SECRET=your_32_character_hex_secret
```

## Usage

### Connecting to the Proxy

#### Method 1: Regular Connection

Use the generated `tg://proxy?server=...` link provided after installation.

#### Method 2: Stealth Connection (Random Padding)

Use the `dd` prefixed secret link for better stealth against ISP detection:

```
tg://proxy?server=YOUR_IP&port=14443&secret=ddYOUR_SECRET
```

#### Method 3: QR Code

Scan the QR code displayed in the terminal with Telegram mobile app.

#### Method 4: Manual Configuration

In Telegram settings:

- Go to Settings → Data and Storage → Proxy Settings
- Add Proxy → MTProto
- Enter your server IP, port, and secret

### Managing the Service

#### View Service Status

```bash
cd /opt/apps/telegram-proxy
docker compose ps
```

#### View Logs

```bash
cd /opt/apps/telegram-proxy
docker compose logs -f
```

#### Stop Service

```bash
cd /opt/apps/telegram-proxy
docker compose down
```

#### Start Service

```bash
cd /opt/apps/telegram-proxy
docker compose up -d
```

#### Restart Service

```bash
cd /opt/apps/telegram-proxy
docker compose restart
```

#### Update Image (for updates)

```bash
cd /opt/apps/telegram-proxy
docker compose pull
docker compose up -d
```

## Daily Maintenance

### Automatic Updates

The script sets up a cron job that runs daily at 4 AM to:

- Restart the container to refresh Telegram configuration
- Ensure the proxy stays compatible with Telegram's infrastructure

### Manual Update Check

```bash
cd /opt/apps/telegram-proxy
./update-proxy.sh
```

## Firewall Configuration

The script automatically configures UFW firewall:

- Allows SSH (port 22) - **Important for maintaining access**
- Allows your chosen proxy port (default 14443)
- Enables UFW if not already active

### Manual Firewall Setup
If you need to configure UFW manually:
```bash
sudo ufw allow 14443/tcp comment "Telegram MTProxy"
sudo ufw reload
```

## Troubleshooting

### Connection Issues

1. **Check if service is running:**

   ```bash
   cd /opt/apps/telegram-proxy
   docker compose ps
   ```

2. **Check container logs:**

   ```bash
   cd /opt/apps/telegram-proxy
   docker compose logs --tail=50
   ```

3. **Check firewall rules:**

   ```bash
   sudo ufw status verbose
   ```

4. **Verify port accessibility:**

   ```bash
   netstat -tlnp | grep :14443
   ```

### Secret Issues

- **Regenerate secret:** Re-run the installer and choose to generate a new secret
- **Check secret format:** Must be 32 hexadecimal characters
- **Test with padding:** Try the `dd` prefixed version for stealth

## Security Considerations

- **Port Selection**: Port 14443 is recommended as it's commonly allowed through firewalls
- **Secret Security**: The MTProto secret is automatically generated using OpenSSL for security
- **Random Padding**: Use `dd` prefix for enhanced stealth against ISP detection
- **Firewall**: Always ensure your firewall is configured to protect other services
- **Updates**: The custom image can be rebuilt for security patches

## Performance

### Resource Usage
- **RAM**: ~50-100MB per container
- **CPU**: Minimal under normal load
- **Network**: Depends on user traffic
- **Disk**: ~200MB for image

### Scaling
For high traffic, consider:
- Running multiple proxy instances on different ports
- Using a load balancer
- Upgrading server resources

## Uninstallation

To completely remove the proxy:

```bash
# Stop and remove containers
cd /opt/apps/telegram-proxy
docker compose down

# Remove installation directory
sudo rm -rf /opt/apps/telegram-proxy

# Remove firewall rule (if using UFW)
sudo ufw delete allow 14443/tcp

# Remove system cron job
sudo rm -f /etc/cron.d/telegram-proxy-update

# Optional: Remove Docker if not needed for other services
# sudo apt remove docker-ce docker-ce-cli containerd.io
```