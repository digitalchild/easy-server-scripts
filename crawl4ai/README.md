# Install crawl4ai on an Ubuntu server

This script will install crawl4ai and proxy it with nginx. It supports SSL via certbot and via cloudflare. If you're using cloudflare, please follow the checklist below to setup the SSL/TLS settings.

## Prerequisites

- A server running Ubuntu 22.04 or above
- Domain name pointing to your server
- (Optional) Cloudflare account if using Cloudflare for SSL
- API tokens for the services you want to use:
  - Crawl4AI API token (optional)
  - OpenAI API key (optional)
  - Anthropic API key (optional)

## Cloudflare SSL Setup Checklist (if using Cloudflare)

### 1. SSL/TLS Settings

- [ ] Go to SSL/TLS tab
- [ ] Set SSL/TLS encryption mode to "Full (Strict)"
- [ ] Set Minimum TLS Version to 1.2
- [ ] Enable TLS 1.3

### 2. Origin Certificate

- [ ] Navigate to SSL/TLS > Origin Server
- [ ] Click "Create Certificate"
- [ ] Select RSA as private key type
- [ ] Set certificate validity to 15 years
- [ ] Save both Origin Certificate and Private Key

### 3. DNS Settings

- [ ] Verify A record points to your server IP
- [ ] Ensure orange cloud is enabled (proxied)

### 4. Additional Security

- [ ] Enable Automatic HTTPS Rewrites
- [ ] Enable Opportunistic Encryption

## Installation

1. Make the script executable:

```bash
chmod +x install-crawl4ai.sh
```

2. Run the script:

```bash
./install-crawl4ai.sh
```

3. Follow the prompts to configure:
   - Domain name
   - Email address (for SSL certificate)
   - API tokens (optional)

## Post-Installation

After installation:

1. Your crawl4ai instance will be available at `https://your-domain.com`
2. The service will automatically start on system boot
3. Logs can be viewed with:

```bash
cd /opt/apps/crawl4ai
docker-compose logs -f
```

## Configuration

The installation creates the following structure:

- `/opt/apps/crawl4ai/docker-compose.yml` - Docker configuration
- `/etc/nginx/sites-available/your-domain.conf` - Nginx configuration

### Environment Variables

You can modify these in the docker-compose.yml file:

- `CRAWL4AI_API_TOKEN` - Your Crawl4AI API token
- `MAX_CONCURRENT_TASKS` - Maximum number of concurrent tasks (default: 5)
- `OPENAI_API_KEY` - Your OpenAI API key
- `ANTHROPIC_API_KEY` - Your Anthropic API key

## Troubleshooting

1. Check if the container is running:

```bash
docker ps | grep crawl4ai
```

2. View the logs:

```bash
docker-compose logs -f
```

3. Check nginx configuration:

```bash
nginx -t
```

4. Check SSL certificate:

```bash
certbot certificates
```

## Security Notes

- The script configures SSL/TLS for secure HTTPS access
- API keys are stored as environment variables in docker-compose.yml
- Regular system updates are recommended
- Keep your API keys secure and never share them
