#!/bin/bash
set -e

# Murassikh VPS Automated Setup Script
# Run this script on a fresh Ubuntu 22.04/24.04 server

DOMAIN=${1:-"murassikh.example.com"}
EMAIL=${2:-"admin@example.com"}

echo "====================================="
echo "   Murassikh Server Setup Started    "
echo "====================================="

# 1. Update system and install dependencies
echo ">> Updating system..."
sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get install -y curl wget git ufw certbot

# 2. Setup Firewall
echo ">> Configuring Firewall..."
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable

# 3. Install Docker and Docker Compose
if ! command -v docker &> /dev/null; then
    echo ">> Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
else
    echo ">> Docker is already installed."
fi

# 4. Generate SSL Certificates (Let's Encrypt)
echo ">> Setting up SSL Certificates for $DOMAIN..."
mkdir -p deploy/certs
if [ "$DOMAIN" != "murassikh.example.com" ]; then
    sudo certbot certonly --standalone -d $DOMAIN --non-interactive --agree-tos -m $EMAIL
    sudo cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem deploy/certs/fullchain.pem
    sudo cp /etc/letsencrypt/live/$DOMAIN/privkey.pem deploy/certs/privkey.pem
    sudo chown $USER:$USER deploy/certs/*.pem
else
    echo "Using dummy self-signed certificates for testing domain."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout deploy/certs/privkey.pem -out deploy/certs/fullchain.pem -subj "/CN=$DOMAIN"
fi

# 5. Environment File
if [ ! -f ".env" ]; then
    echo ">> Creating .env file..."
    SECRET_KEY=$(openssl rand -hex 32)
    cat <<ENV_EOF > .env
ENVIRONMENT=production
POSTGRES_USER=murassikh
POSTGRES_PASSWORD=$(openssl rand -base64 16)
POSTGRES_DB=murassikh_db
SECRET_KEY=$SECRET_KEY
CORS_ORIGINS=https://$DOMAIN
HTTP_PORT=80
HTTPS_PORT=443
GEMINI_API_KEY=your_gemini_api_key_here
ENV_EOF
    echo "!! Please edit .env to set your real GEMINI_API_KEY !!"
fi

echo "====================================="
echo "Setup Complete!"
echo "Next steps:"
echo "1. Nano .env and add your GEMINI_API_KEY."
echo "2. Run: docker compose -f docker-compose.production.yml up -d"
echo "====================================="
