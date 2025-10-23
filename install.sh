#!/bin/bash
# CloudLab Merox - One-line installer
# Usage: curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/cloudlab-merox/main/install.sh | bash

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}CloudLab Merox - Quick Installer${NC}"
echo ""

# Check prerequisites
command -v git >/dev/null 2>&1 || { 
    echo -e "${RED}git is required but not installed.${NC}"
    echo "Install with: sudo apt install git"
    exit 1
}

# Clone repo
REPO_URL="https://github.com/meroxdotdev/cloudlab-merox.git"
TARGET_DIR="${1:-cloudlab-merox}"

if [ -d "$TARGET_DIR" ]; then
    echo -e "${RED}Directory $TARGET_DIR already exists!${NC}"
    exit 1
fi

echo "Cloning repository..."
git clone "$REPO_URL" "$TARGET_DIR"
cd "$TARGET_DIR"

echo ""
echo -e "${GREEN}Repository cloned!${NC}"
echo ""
echo -e "\n\033[1;36mNext steps:\033[0m"
echo -e "  \033[1;33m1.\033[0m cd \$TARGET_DIR"
echo -e "  \033[1;33m2.\033[0m Edit \033[1;37minventories/production/hosts\033[0m (add your server IPs)"
echo -e "  \033[1;33m3.\033[0m Create vault: \033[1;37mansible-vault create inventories/production/group_vars/all/vault.yml\033[0m"
echo -e "     Inside the vault, include the following values:\n"
echo -e "       \033[1;32mvault_tailscale_auth_key:\033[0m \"tskey-auth-\"    \033[2m# check https://tailscale.com/kb/1085/auth-keys\033[0m"
echo -e "       \033[1;32mcloudflare_api_token:\033[0m \"\"                   \033[2m# check https://developers.cloudflare.com/fundamentals/api/get-started/create-token/\033[0m"
echo -e "       \033[1;32mcloudflare_email:\033[0m \"your-cloudflare@email.com\""
echo -e "       \033[1;32mtraefik_dashboard_credentials:\033[0m \"\"          \033[2m# Basic auth (user:hashedpassword) — use 'htpasswd -nb user password'\033[0m"
echo -e "       \033[1;32mpihole_webpassword:\033[0m \"webpassword\"          \033[2m# Password for Pi-hole web interface\033[0m"
echo -e "  \033[1;33m4.\033[0m Run bootstrap: \033[1;37m./bootstrap.sh\033[0m\n"
