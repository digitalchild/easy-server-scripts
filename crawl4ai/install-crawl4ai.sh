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
    local ips=$(dig +short A ${domain})
    
    echo "Debug: Checking Cloudflare status for ${domain}"
    echo "Debug: Nameservers: ${nameservers}"
    echo "Debug: IPs: ${ips}"
    
    # Check if using Cloudflare nameservers
    if echo "$nameservers" | grep -q "cloudflare.com"; then
        echo "Debug: Detected Cloudflare nameservers"
        return 0 # Is Cloudflare
    fi
    
    # Check if resolving to Cloudflare IPs
    if echo "$ips" | grep -qE "^(172\.67\.|104\.21\.|104\.16\.|104\.17\.|104\.18\.|104\.19\.)"; then
        echo "Debug: Detected Cloudflare proxy (domain resolves to Cloudflare IPs)"
        return 0 # Is Cloudflare
    fi
    
    echo "Debug: Not using Cloudflare"
    return 1 # Not Cloudflare
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
        
        # Get the resolved IPs
        local domain_ips=$(dig +short A ${domain} | grep -v "\.$" || true)
        echo "Domain resolves to Cloudflare IPs:"
        echo "$domain_ips"
        echo "This is expected when using Cloudflare as a proxy"
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
        echo "If you are not using Cloudflare, please update your DNS records"
        return 1
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
        proxy_pass http://127.0.0.1:11235;
        proxy_http_version 1.1;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Host \$host;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
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
    
    echo "Debug: Starting SSL setup for ${domain}"
    
    # Explicitly check Cloudflare status
    if check_cloudflare "$domain"; then
        echo "Debug: Cloudflare detected, showing SSL options"
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
                
                # Create SSL directory
                sudo mkdir -p /etc/nginx/ssl
                
                # Set default paths
                local default_cert="/etc/nginx/ssl/${domain}.pem"
                local default_key="/etc/nginx/ssl/${domain}.key"
                
                # Check if certificates already exist
                local cert_exists=false
                local key_exists=false
                
                if [ -s "$default_cert" ]; then
                    echo "Found existing certificate at ${default_cert}"
                    cert_exists=true
                fi
                
                if [ -s "$default_key" ]; then
                    echo "Found existing private key at ${default_key}"
                    key_exists=true
                fi
                
                if [ "$cert_exists" = true ] && [ "$key_exists" = true ]; then
                    read -p "Certificates already exist. Do you want to replace them? (y/n): " replace_certs
                    if [[ ! $replace_certs =~ ^[Yy]$ ]]; then
                        echo "Using existing certificates..."
                        configure_nginx_cloudflare "$domain" "$default_cert" "$default_key"
                        return
                    fi
                fi
                
                # Prompt for certificate path with default
                read -p "Certificate path [${default_cert}]: " cert_path
                cert_path=${cert_path:-$default_cert}
                
                # Prompt for key path with default
                read -p "Private key path [${default_key}]: " key_path
                key_path=${key_path:-$default_key}
                
                # Create parent directories if they don't exist
                sudo mkdir -p "$(dirname "$cert_path")"
                sudo mkdir -p "$(dirname "$key_path")"
                
                # Prompt for certificate contents
                echo "Paste the Certificate content (CTRL+D when done):"
                sudo touch "$cert_path"
                sudo tee "$cert_path" > /dev/null
                
                echo "Paste the Private Key content (CTRL+D when done):"
                sudo touch "$key_path"
                sudo tee "$key_path" > /dev/null
                
                # Verify files were created and have content
                if [ ! -s "$cert_path" ]; then
                    echo "Error: Certificate file is empty or was not created"
                    exit 1
                fi
                
                if [ ! -s "$key_path" ]; then
                    echo "Error: Private key file is empty or was not created"
                    exit 1
                fi
                
                # Set proper permissions
                sudo chmod 644 "$cert_path"
                sudo chmod 600 "$key_path"
                
                # Update Nginx config for Cloudflare
                configure_nginx_cloudflare "$domain" "$cert_path" "$key_path"
                ;;
            2)
                # Check for existing Let's Encrypt certificate
                if [ -d "/etc/letsencrypt/live/${domain}" ]; then
                    echo "Found existing Let's Encrypt certificate for ${domain}"
                    read -p "Do you want to renew/replace it? (y/n): " replace_le
                    if [[ ! $replace_le =~ ^[Yy]$ ]]; then
                        echo "Using existing Let's Encrypt certificate..."
                        return
                    fi
                fi
                
                echo "Please disable Cloudflare proxy (grey cloud) before continuing"
                read -p "Press Enter when ready..."
                certbot --nginx -d ${domain} --non-interactive --agree-tos --email ${email}
                echo "You can now re-enable Cloudflare proxy"
                ;;
            *)
                echo "Invalid choice. Using Let's Encrypt..."
                certbot --nginx -d ${domain} --non-interactive --agree-tos --email ${email}
                ;;
        esac
    else
        echo "Debug: No Cloudflare detected, using Let's Encrypt"
        # Check for existing Let's Encrypt certificate
        if [ -d "/etc/letsencrypt/live/${domain}" ]; then
            echo "Found existing Let's Encrypt certificate for ${domain}"
            read -p "Do you want to renew/replace it? (y/n): " replace_le
            if [[ ! $replace_le =~ ^[Yy]$ ]]; then
                echo "Using existing Let's Encrypt certificate..."
                return
            fi
        fi
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
        read -p "Enter your domain name (e.g., crawl.example.com): " DOMAIN
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

    # Email for SSL certificate
    while true; do
        read -p "Enter email address for SSL certificate: " EMAIL
        if [[ "$EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            break
        else
            echo "Please enter a valid email address"
        fi
    done

    # API Token
    read -p "Enter your Crawl4AI API token (press Enter to skip): " CRAWL4AI_API_TOKEN

    # OpenAI API Key
    read -p "Enter your OpenAI API key (press Enter to skip): " OPENAI_API_KEY

    # Anthropic API Key
    read -p "Enter your Anthropic API key (press Enter to skip): " ANTHROPIC_API_KEY

    # Confirm settings
    echo -e "\nPlease confirm your settings:"
    echo "Domain: $DOMAIN"
    echo "Server IP: $SERVER_IP"
    echo "Email: $EMAIL"
    echo "Crawl4AI API Token: ${CRAWL4AI_API_TOKEN:-Not set}"
    echo "OpenAI API Key: ${OPENAI_API_KEY:-Not set}"
    echo "Anthropic API Key: ${ANTHROPIC_API_KEY:-Not set}"
    
    read -p "Are these settings correct? (y/n): " CONFIRM
    if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
        echo "Let's try again..."
        prompt_variables
    fi
}

# Main installation function
install_crawl4ai() {
    echo "Starting installation with the following settings:"
    echo "Domain: $DOMAIN"
    echo "Server IP: $SERVER_IP"
    echo "Email: $EMAIL"

    # Update system and install basic packages
    echo "Updating system and installing basic packages..."
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y curl wget git nginx certbot python3-certbot-nginx htop dnsutils

    # Install Docker
    echo "Installing Docker..."
    sudo apt-get install -y ca-certificates curl gnupg

    # Add Docker's official GPG key if not already present
    if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
        echo "Adding Docker's GPG key..."
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg
    else
        echo "Docker GPG key already exists, skipping..."
    fi

    # Add the repository to Apt sources if not already added
    if [ ! -f /etc/apt/sources.list.d/docker.list ]; then
        echo "Adding Docker repository..."
        echo \
          "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
          "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
          sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    else
        echo "Docker repository already configured, skipping..."
    fi

    # Update package list and install Docker
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-compose

    # Add current user to docker group
    sudo usermod -aG docker $USER

    # Create crawl4ai directory structure
    echo "Creating crawl4ai directory structure..."
    sudo mkdir -p /opt/apps/crawl4ai

    # Create docker-compose.yml
    cat > /opt/apps/crawl4ai/docker-compose.yml <<EOF
version: '3.8'

services:
  crawl4ai:
    image: unclecode/crawl4ai:all-amd64
    platform: linux/amd64
    restart: unless-stopped
    ports:
      - "11235:11235"
    environment:
      - CRAWL4AI_API_TOKEN=${CRAWL4AI_API_TOKEN:-}
      - MAX_CONCURRENT_TASKS=5
      - OPENAI_API_KEY=${OPENAI_API_KEY:-}
      - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY:-}
    volumes:
      - /dev/shm:/dev/shm
    deploy:
      resources:
        limits:
          memory: 4G
        reservations:
          memory: 1G

volumes:
  crawl4ai-data:
EOF

    # Create initial nginx configuration
    echo "Creating nginx configuration..."
    cat > /etc/nginx/sites-available/${DOMAIN}.conf <<EOF
server {
    server_name ${DOMAIN};
    location / {
        proxy_pass http://127.0.0.1:11235;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
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

    # Start crawl4ai
    cd /opt/apps/crawl4ai
    docker-compose up -d

    echo -e "\n=== Installation Complete! ===\n"
    echo "Please note the following important information:"
    echo "1. Your crawl4ai instance is available at: https://${DOMAIN}"
    echo "2. Docker containers are configured to restart automatically"
    echo "3. SSL certificate is configured"
    echo "4. Nginx proxy is set up"
    
    if [ -n "$CRAWL4AI_API_TOKEN" ]; then
        echo "5. API token is configured"
    else
        echo "5. No API token set - service is running without authentication"
    fi
    
    echo -e "\nYou may need to log out and back in for docker group membership to take effect."
    
    # Test the installation
    echo -e "\nTesting the installation..."
    sleep 5  # Give the container time to start
    
    if curl -s "http://localhost:11235/health" | grep -q "ok"; then
        echo "✅ crawl4ai is running correctly!"
    else
        echo "⚠️ crawl4ai may not be running correctly. Please check the logs:"
        echo "docker-compose logs -f"
    fi
}

# Main script execution
echo "Welcome to crawl4ai Installation Script"
echo "==================================="
prompt_variables
read -p "Ready to begin installation? (y/n): " START
if [[ $START =~ ^[Yy]$ ]]; then
    install_crawl4ai
else
    echo "Installation cancelled"
    exit 1
fi
