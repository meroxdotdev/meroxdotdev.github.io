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
echo "Next steps:"
echo "  1. cd \$TARGET_DIR"
echo "  2. Edit inventories/production/hosts (add your server IPs)"
echo "  3. Create vault: ansible-vault create inventories/production/group_vars/all/vault.yml"
echo "     Inside the vault, include the following values:"
echo "       vault_tailscale_auth_key: \"tskey-auth-\"    # check https://tailscale.com/kb/1085/auth-keys"
echo "       cloudflare_api_token: \"\"                   # check https://developers.cloudflare.com/fundamentals/api/get-started/create-token/"
echo "       cloudflare_email: \"your-cloudflare@email.com\""
echo "       traefik_dashboard_credentials: \"\"          # Basic auth (user:hashedpassword) — generate via: htpasswd -nb user password"
echo "       pihole_webpassword: \"webpassword\"          # Password for Pi-hole web interface"
echo "  4. Run bootstrap: ./bootstrap.sh"
echo ""
