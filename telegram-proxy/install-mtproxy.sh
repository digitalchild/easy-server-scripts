#!/bin/bash

# Exit on any error
set -e
# Treat unset variables as an error
set -u
# Pipefail
set -o pipefail

# --- Configuration ---
APP_NAME="telegram-proxy"
BASE_INSTALL_DIR="/opt/apps"
INSTALL_DIR="${BASE_INSTALL_DIR}/${APP_NAME}"
COMPOSE_FILE="${INSTALL_DIR}/docker-compose.yml"
ENV_FILE="${INSTALL_DIR}/.env"
DOCKERFILE="${INSTALL_DIR}/Dockerfile"
DEFAULT_PROXY_PORT="14443"
CUSTOM_IMAGE_NAME="custom-mtproxy"

# --- Helper Functions ---
log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
}

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log_error "This script must be run as root or with sudo."
        exit 1
    fi
}

install_dependencies() {
    log_info "Updating package list..."
    apt-get update -qq

    log_info "Checking for Docker and Docker Compose..."
    NEEDS_INSTALL=false
    if ! command -v docker &> /dev/null; then
        log_info "Docker not found. Preparing to install..."
        NEEDS_INSTALL=true
    else
        log_info "Docker is already installed."
    fi

    if ! docker compose version &> /dev/null && ! docker-compose version &> /dev/null ; then
        log_info "Docker Compose (plugin or standalone) not found. Preparing to install plugin..."
        NEEDS_INSTALL=true # Docker Compose plugin often comes with Docker CE, but good to ensure
    else
        log_info "Docker Compose (plugin or standalone) is already installed."
    fi

    if [ "$NEEDS_INSTALL" = true ]; then
        log_info "Installing Docker prerequisites..."
        apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg
        
        log_info "Adding Docker GPG key..."
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        chmod a+r /etc/apt/keyrings/docker.gpg

        log_info "Adding Docker repository..."
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
          $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
          tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        log_info "Updating package list after adding Docker repo..."
        apt-get update -qq
        
        log_info "Installing Docker CE, Docker CE CLI, Containerd.io, and Docker Compose plugin..."
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        
        log_info "Starting and enabling Docker service..."
        systemctl start docker
        systemctl enable docker
        log_info "Docker and Docker Compose plugin installed successfully."
    fi

    if ! command -v qrencode &> /dev/null; then
        log_info "Installing qrencode to display QR code for the proxy link..."
        apt-get install -y qrencode
    fi
}

setup_proxy_files() {
    log_info "Creating installation directory: ${INSTALL_DIR}"
    mkdir -p "${INSTALL_DIR}"

    if [ -f "${ENV_FILE}" ]; then
        log_info "${ENV_FILE} already exists. Using existing configuration or re-generating if prompted."
        # shellcheck source=/dev/null
        source "${ENV_FILE}" # Load existing vars to pre-fill prompts or use directly
    fi

    # Prompt for port
    read -r -p "Enter the port for the proxy to listen on (default: ${PROXY_PORT:-$DEFAULT_PROXY_PORT}): " SELECTED_PORT
    PROXY_PORT="${SELECTED_PORT:-${PROXY_PORT:-$DEFAULT_PROXY_PORT}}" # Use entered, then existing from .env, then default

    # Generate or confirm secret
    if [ -z "${MTPROTO_SECRET:-}" ] || [ ! -f "${ENV_FILE}" ]; then
        log_info "Generating new MTProto secret..."
        MTPROTO_SECRET=$(openssl rand -hex 16)
        log_info "New secret generated."
    else
        read -r -p "An existing secret is found. Do you want to generate a new one? (y/N): " regen_secret
        if [[ "${regen_secret}" =~ ^[Yy]$ ]]; then
            log_info "Generating new MTProto secret..."
            MTPROTO_SECRET=$(openssl rand -hex 16)
            log_info "New secret generated."
        else
            log_info "Using existing MTProto secret."
        fi
    fi

    log_info "Writing configuration to ${ENV_FILE}..."
    echo "PROXY_PORT=${PROXY_PORT}" > "${ENV_FILE}"
    echo "MTPROTO_SECRET=${MTPROTO_SECRET}" >> "${ENV_FILE}"

    log_info "Creating ${COMPOSE_FILE}..."
    cat <<EOF > "${COMPOSE_FILE}"
services:
  mtproxy:
    image: telegrammessenger/proxy:latest
    container_name: ${APP_NAME}
    restart: always
    ports:
      - "\${PROXY_PORT}:443/tcp" # Map external port to internal 443
    environment:
      - SECRET=\${MTPROTO_SECRET} # Official image uses SECRET env var
    volumes:
      - ./stats:/data # For persistent stats
EOF
    log_info "${COMPOSE_FILE} created using official Telegram proxy image."
}

configure_firewall() {
    # shellcheck source=/dev/null
    source "${ENV_FILE}" # Ensure PROXY_PORT is loaded

    if command -v ufw &> /dev/null; then
        log_info "Configuring UFW firewall for port ${PROXY_PORT}/tcp..."
        if ufw status | grep -qw active; then
            ufw allow "${PROXY_PORT}/tcp" comment "Telegram MTProto Proxy"
            ufw reload
            log_info "UFW rule added and reloaded."
        else
            log_info "UFW is inactive. Enabling UFW and allowing port ${PROXY_PORT}/tcp."
            ufw allow ssh # IMPORTANT: Ensure SSH is allowed before enabling UFW
            ufw allow "${PROXY_PORT}/tcp" comment "Telegram MTProto Proxy"
            echo "y" | ufw enable # Auto-confirm enabling UFW
            log_info "UFW enabled and rule added."
        fi
        ufw status verbose
    else
        log_info "UFW is not installed. Please configure your firewall manually to allow TCP traffic on port ${PROXY_PORT}."
    fi
}

setup_daily_update_cron() {
    log_info "Setting up daily configuration update..."
    
    # Create a script to update and restart the proxy
    cat <<EOF > "${INSTALL_DIR}/update-proxy.sh"
#!/bin/bash
# Daily MTProxy configuration update script
cd ${INSTALL_DIR}
docker compose restart
EOF
    chmod +x "${INSTALL_DIR}/update-proxy.sh"
    
    # Create cron job file in /etc/cron.d/
    CRON_FILE="/etc/cron.d/telegram-proxy-update"
    
    log_info "Creating system cron job for daily updates..."
    
    # Create the cron.d file
    cat <<EOF > "${CRON_FILE}"
# Daily MTProxy configuration update
# Updates Telegram configuration and restarts proxy at 4 AM
0 4 * * * root ${INSTALL_DIR}/update-proxy.sh >/dev/null 2>&1
EOF
    
    # Verify the cron file was created
    if [ -f "${CRON_FILE}" ]; then
        log_info "System cron job created: ${CRON_FILE}"
        log_info "Daily configuration updates scheduled for 4 AM."
    else
        log_error "Failed to create cron job file."
        log_info "You can manually create it with:"
        log_info "  echo '0 4 * * * root ${INSTALL_DIR}/update-proxy.sh >/dev/null 2>&1' | sudo tee /etc/cron.d/telegram-proxy-update"
    fi
}

start_proxy_service() {
    # shellcheck source=/dev/null
    source "${ENV_FILE}" # Ensure variables are loaded for docker-compose

    log_info "Starting Telegram proxy service using official Docker image..."
    cd "${INSTALL_DIR}"
    docker compose up -d
    log_info "Telegram proxy service started."
    docker compose ps
}

display_connection_info() {
    # shellcheck source=/dev/null
    source "${ENV_FILE}" # Load PROXY_PORT and MTPROTO_SECRET

    SERVER_IP=$(curl -s4 ifconfig.me || hostname -I | awk '{print $1}')
    if [ -z "${SERVER_IP}" ]; then
        log_error "Could not automatically determine public IP address."
        log_info "Please find your VPS public IP address manually."
        SERVER_IP="YOUR_VPS_IP_ADDRESS"
    fi

    PROXY_LINK="tg://proxy?server=${SERVER_IP}&port=${PROXY_PORT}&secret=${MTPROTO_SECRET}"
    PADDED_PROXY_LINK="tg://proxy?server=${SERVER_IP}&port=${PROXY_PORT}&secret=dd${MTPROTO_SECRET}"

    log_info "------------------------------------------------------"
    log_info "Telegram MTProxy Setup Complete!"
    log_info "------------------------------------------------------"
    log_info "Connect to your proxy using this link:"
    echo ""
    log_info "${PROXY_LINK}"
    echo ""
    log_info "For random padding (better stealth), use this link:"
    log_info "${PADDED_PROXY_LINK}"
    echo ""
    if command -v qrencode &> /dev/null; then
        log_info "Or scan this QR code in Telegram:"
        qrencode -t ansiutf8 "${PROXY_LINK}"
    else
        log_info "Install 'qrencode' (sudo apt install qrencode) to display a QR code."
    fi
    log_info "------------------------------------------------------"
    log_info "Manual configuration details:"
    log_info "Server: ${SERVER_IP}"
    log_info "Port: ${PROXY_PORT}"
    log_info "Secret: ${MTPROTO_SECRET}"
    log_info "Secret (with padding): dd${MTPROTO_SECRET}"
    log_info "Type: MTProto"
    log_info "------------------------------------------------------"
    log_info "Service Management Commands:"
    log_info "View logs: cd ${INSTALL_DIR} && docker compose logs -f"
    log_info "Stop service: cd ${INSTALL_DIR} && docker compose down"
    log_info "Start service: cd ${INSTALL_DIR} && docker compose up -d"
    log_info "Update image: cd ${INSTALL_DIR} && docker compose pull && docker compose up -d"
    log_info "------------------------------------------------------"
    log_info "Features of this installation:"
    log_info "- Uses official Telegram MTProxy Docker image"
    log_info "- Automatic daily configuration updates via cron"
    log_info "- Firewall configuration with UFW"
    log_info "- Random padding support for better stealth"
    log_info "- Persistent configuration and easy management"
    log_info "------------------------------------------------------"
}

# --- Main Script Execution ---
main() {
    check_root
    install_dependencies
    setup_proxy_files
    configure_firewall
    setup_daily_update_cron
    start_proxy_service
    display_connection_info
}

main "$@"