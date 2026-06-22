#!/usr/bin/env bash
set -Eeuo pipefail

# Infrastructure bootstrap script for home-server-iac
# This script runs on the control machine (your workstation) to configure the target server.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

echo "==============================================="
echo "  Homelab Server Bootstrap Initiator"
echo "==============================================="

# 1. Sanity Check: Ansible Installed
if ! command -v ansible-playbook &> /dev/null; then
    echo "[-] Error: 'ansible-playbook' could not be found."
    echo "    Please install Ansible on your machine before running this script."
    echo "    On macOS: brew install ansible"
    echo "    On Ubuntu/Debian: sudo apt install ansible"
    exit 1
fi

# 2. Check for private SSH key configuration
echo "[+] Checking SSH key..."
if [ ! -f ~/.ssh/id_ed25519 ] && [ ! -f ~/.ssh/id_rsa ]; then
    echo "[!] Warning: No default SSH key (id_ed25519 or id_rsa) found in ~/.ssh/."
    echo "    Please ensure you have configured your inventory.ini with the correct private key path."
fi

# 3. Prompt for Tailscale Auth Key (Optional)
read -rsp "[?] Enter Tailscale Auth Key (optional, press Enter to skip): " TS_AUTH_KEY
echo ""

# 4. Execute playbook
cd "$REPO_DIR"

EXTRA_VARS=""
if [ -n "$TS_AUTH_KEY" ]; then
    EXTRA_VARS="tailscale_auth_key=$TS_AUTH_KEY"
    echo "[+] Running Ansible playbook with Tailscale Auth Key..."
    ansible-playbook -i inventory.ini ansible/site.yml --extra-vars "$EXTRA_VARS" --ask-become-pass
else
    echo "[+] Running Ansible playbook..."
    ansible-playbook -i inventory.ini ansible/site.yml --ask-become-pass
fi

echo "==============================================="
echo "[+] Provisioning execution finished!"
echo "    If Tailscale was not auto-authenticated, SSH into your server"
echo "    and run: sudo tailscale up --ssh"
echo "==============================================="
