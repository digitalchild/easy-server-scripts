# Easy Server Scripts

This repository contains scripts to help with the setup and management of servers.

## Setup N8N

This will install n8n and proxy it with nginx. It supports SSL via certbot and via cloudflare. If you're are using cloudflare, please follow the checklist below to setup the SSL/TLS settings.

### Cloudflare SSL Setup Checklist

#### 1. SSL/TLS Settings

- [ ] Go to SSL/TLS tab
- [ ] Set SSL/TLS encryption mode to "Full (Strict)"
- [ ] Set Minimum TLS Version to 1.2
- [ ] Enable TLS 1.3

#### 2. Origin Certificate

- [ ] Navigate to SSL/TLS > Origin Server
- [ ] Click "Create Certificate"
- [ ] Select RSA as private key type
- [ ] Set certificate validity to 15 years
- [ ] Save both Origin Certificate and Private Key

#### 3. DNS Settings

- [ ] Verify A record points to your server IP
- [ ] Ensure orange cloud is enabled (proxied)

#### 4. Additional Security

- [ ] Enable Automatic HTTPS Rewrites
- [ ] Enable Opportunistic Encryption

#### During Installation

When the script prompts for certificate files:

- Paste the Origin Certificate when requested
- Paste the Private Key when requested

Copy the script to your server and make it executable.

```bash
chmod +x install-n8n.sh
```

Run the script.

```bash
./install-n8n.sh
```
