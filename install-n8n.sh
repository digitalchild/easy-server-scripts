#!/bin/bash

# Exit on error
set -e

# Function to get server's public IP
get_server_ip() {
    # Try to get IPv4 address first
    PUBLIC_IPV4=$(curl -4 -s ifconfig.me || curl -4 -s icanhazip.com || curl -4 -s ipecho.net/plain)
    
    if [ -z "$PUBLIC_IPV4" ]; then
        echo "Warning: Could not determine server's IPv4 address"
        exit 1
    fi
    echo $PUBLIC_IPV4
}

# Function to check if domain uses Cloudflare
check_cloudflare() {
    local domain=$1
    local nameservers=$(dig +short NS ${domain})
    
    if echo "$nameservers" | grep -q "cloudflare.com"; then
        return 0 # Is Cloudflare
    else
        return 1 # Not Cloudflare
    fi
}

# Function to check domain DNS
check_domain_dns() {
    local domain=$1
    local server_ip=$2
    
    echo "Checking DNS configuration for ${domain}..."
    
    # First check if domain uses Cloudflare
    if check_cloudflare "$domain"; then
        echo "Detected Cloudflare nameservers for ${domain}"
        echo "Note: SSL certificate will be handled differently for Cloudflare domains"
        return 0  # Allow Cloudflare domains to proceed
    fi
    
    # If not Cloudflare, proceed with normal DNS check
    local domain_ips=$(dig +short A ${domain} | grep -v "\.$" || true)
    
    if [ -z "$domain_ips" ]; then
        echo "Error: Domain ${domain} does not resolve to any IP address"
        return 1
    fi
    
    if echo "$domain_ips" | grep -q "^${server_ip}$"; then
        echo "Success: Domain ${domain} correctly resolves to this server (${server_ip})"
        return 0
    else
        echo "Warning: Domain ${domain} resolves to different IP(s):"
        echo "$domain_ips"
        echo "Expected IP: ${server_ip}"
        
        # Since we detected Cloudflare IPs, we'll ask if they want to proceed
        read -p "These appear to be Cloudflare IPs. Do you want to proceed anyway? (y/n): " proceed
        if [[ $proceed =~ ^[Yy]$ ]]; then
            return 0
        else
            return 1
        fi
    fi
}

# Function to configure Nginx for Cloudflare
configure_nginx_cloudflare() {
    local domain=$1
    local cert_path=$2
    local key_path=$3
    
    cat > /etc/nginx/sites-available/${domain}.conf <<EOF
server {
    listen 443 ssl http2;
    server_name ${domain};

    ssl_certificate ${cert_path};
    ssl_certificate_key ${key_path};
    ssl_protocols TLSv1.2 TLSv1.3;
    
    # Recommended Cloudflare SSL settings
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    
    location / {
        proxy_pass http://127.0.0.1:5678;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Upgrade \$http_upgrade;
        proxy_http_version 1.1;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Host \$host;
    }
}

server {
    listen 80;
    server_name ${domain};
    return 301 https://\$host\$request_uri;
}
EOF

    nginx -t
    systemctl restart nginx
}

# Function to setup SSL
setup_ssl() {
    local domain=$1
    local email=$2
    
    if check_cloudflare "$domain"; then
        echo "Cloudflare domain detected. Please choose SSL option:"
        echo "1. Use Cloudflare Origin Certificate (recommended)"
        echo "2. Use Let's Encrypt (requires temporarily disabling Cloudflare proxy)"
        read -p "Enter choice (1 or 2): " ssl_choice
        
        case $ssl_choice in
            1)
                echo "Please follow these steps:"
                echo "1. Go to Cloudflare Dashboard > SSL/TLS > Origin Server"
                echo "2. Create new certificate (15 years validity recommended)"
                echo "3. Copy the Certificate and Private Key"
                echo "Enter path to save certificate files:"
                read -p "Certificate path (e.g., /etc/nginx/ssl/${domain}.pem): " cert_path
                read -p "Private key path (e.g., /etc/nginx/ssl/${domain}.key): " key_path
                
                # Create directory if it doesn't exist
                sudo mkdir -p $(dirname "$cert_path")
                
                # Prompt for certificate contents
                echo "Paste the Certificate content (CTRL+D when done):"
                sudo tee "$cert_path" > /dev/null
                echo "Paste the Private Key content (CTRL+D when done):"
                sudo tee "$key_path" > /dev/null
                
                # Update Nginx config for Cloudflare
                configure_nginx_cloudflare "$domain" "$cert_path" "$key_path"
                ;;
            2)
                echo "Please disable Cloudflare proxy (grey cloud) before continuing"
                read -p "Press Enter when ready..."
                certbot --nginx -d ${domain} --non-interactive --agree-tos --email ${email}
                echo "You can now re-enable Cloudflare proxy"
                ;;
        esac
    else
        # Standard Let's Encrypt for non-Cloudflare domains
        certbot --nginx -d ${domain} --non-interactive --agree-tos --email ${email}
    fi
}

# Function to prompt for variables
prompt_variables() {
    # Get server IP first
    SERVER_IP=$(get_server_ip)
    echo "Server public IP: ${SERVER_IP}"

    # Domain name with DNS check
    while true; do
        read -p "Enter your domain name (e.g., n8n.example.com): " DOMAIN
        if [[ -n "$DOMAIN" && "$DOMAIN" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            if check_domain_dns "$DOMAIN" "$SERVER_IP"; then
                break
            else
                echo "Please update your DNS records and try again"
                read -p "Would you like to try another domain? (y/n): " retry
                if [[ ! $retry =~ ^[Yy]$ ]]; then
                    echo "Exiting installation..."
                    exit 1
                fi
            fi
        else
            echo "Please enter a valid domain name"
        fi
    done

    # Timezone
    while true; do
        read -p "Enter timezone (default: Europe/Berlin): " TIMEZONE
        TIMEZONE=${TIMEZONE:-"Europe/Berlin"}
        if [ -f "/usr/share/zoneinfo/$TIMEZONE" ]; then
            break
        else
            echo "Invalid timezone. Please enter a valid timezone (e.g., Europe/Berlin, America/New_York)"
        fi
    done

    # Email for SSL certificate
    while true; do
        read -p "Enter email address for SSL certificate: " EMAIL
        if [[ "$EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            break
        else
            echo "Please enter a valid email address"
        fi
    done

    # Confirm settings
    echo -e "\nPlease confirm your settings:"
    echo "Domain: $DOMAIN"
    echo "Server IP: $SERVER_IP"
    echo "Timezone: $TIMEZONE"
    echo "Email: $EMAIL"
    
    read -p "Are these settings correct? (y/n): " CONFIRM
    if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
        echo "Let's try again..."
        prompt_variables
    fi
}

# Main installation function
install_n8n() {
    echo "Starting installation with the following settings:"
    echo "Domain: $DOMAIN"
    echo "Server IP: $SERVER_IP"
    echo "Timezone: $TIMEZONE"
    echo "Email: $EMAIL"

    # Update system and install basic packages
    echo "Updating system and installing basic packages..."
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y curl wget git nginx certbot python3-certbot-nginx htop dnsutils

    # Install Docker
    echo "Installing Docker..."
    sudo apt-get install -y ca-certificates curl gnupg

    # Add Docker's official GPG key
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    # Add the repository to Apt sources
    echo \
      "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Update package list and install Docker
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-compose

    # Add current user to docker group
    sudo usermod -aG docker $USER

    # Create n8n directory structure
    echo "Creating n8n directory structure..."
    sudo mkdir -p /opt/projects/n8n

    # Create initial nginx configuration
    echo "Creating nginx configuration..."
    cat > /etc/nginx/sites-available/${DOMAIN}.conf <<EOF
server {
    server_name ${DOMAIN};
    location / {
        proxy_pass http://127.0.0.1:5678;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Upgrade \$http_upgrade;
        proxy_http_version 1.1;
    }
}
EOF

    # Enable nginx site
    ln -sf /etc/nginx/sites-available/${DOMAIN}.conf /etc/nginx/sites-enabled/
    # Remove default nginx site if it exists
    rm -f /etc/nginx/sites-enabled/default
    nginx -t
    systemctl restart nginx

    # Setup SSL
    echo "Setting up SSL certificate..."
    setup_ssl "$DOMAIN" "$EMAIL"

    # Create docker-compose.yml
    cat > /opt/projects/n8n/docker-compose.yml <<EOF
version: '3'

services:
  n8n:
    image: n8nio/n8n
    restart: unless-stopped
    ports:
      - 5678:5678
    volumes:
      - n8n-data:/home/node/.n8n
    environment:
      - N8N_HOST=${DOMAIN}
      - N8N_PORT=5678
      - N8N_ENV=production
      - N8N_PROTOCOL=https
      - WEBHOOK_URL=https://${DOMAIN}
      - GENERIC_TIMEZONE=${TIMEZONE}
      - NODE_FUNCTION_ALLOW_EXTERNAL=axios

volumes:
  n8n-data:
EOF

    # Start n8n
    cd /opt/projects/n8n
    docker-compose up -d

    echo -e "\n=== Installation Complete! ===\n"
    echo "Please note the following important information:"
    echo "1. Your n8n instance is available at: https://${DOMAIN}"
    echo "2. Docker containers are configured to restart automatically"
    echo "3. Data is persisted in a Docker volume"
    echo "4. SSL certificate is configured"
    echo -e "\nYou may need to log out and back in for docker group membership to take effect."
    echo -e "\nInstallation complete! You can now access n8n at https://${DOMAIN}\n"
}

# Main script execution
echo "Welcome to n8n Installation Script"
echo "==================================="
prompt_variables
read -p "Ready to begin installation? (y/n): " START
if [[ $START =~ ^[Yy]$ ]]; then
    install_n8n
else
    echo "Installation cancelled"
    exit 1
fi