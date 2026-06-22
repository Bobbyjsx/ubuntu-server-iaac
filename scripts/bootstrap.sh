#!/usr/bin/env bash
set -Eeuo pipefail

# Infrastructure bootstrap script for home-server-iac
# This script runs on the control machine (your workstation) to configure the target server.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

echo "==============================================="
echo "  Homelab Server Bootstrap Initiator"
echo "==============================================="

# 1. Load environment variables
if [ -f "$REPO_DIR/.env" ]; then
    echo "[+] Loading environment from .env..."
    # Read variables, ignoring comments and empty lines
    while IFS= read -r line || [ -n "$line" ]; do
        # Ignore comments and empty lines
        if [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "$line" ]]; then
            continue
        fi
        # Export the variable
        export "$line"
    done < "$REPO_DIR/.env"
else
    echo "[-] Error: .env file not found at $REPO_DIR/.env"
    echo "    Please create it (copying from .env.example) and try again."
    exit 1
fi

# 2. Validate required environment variables
for var in SERVER_IP SERVER_USER SSH_KEY_PATH; do
    if [ -z "${!var:-}" ]; then
        echo "[-] Error: Required environment variable $var is not set in .env."
        exit 1
    fi
done

# 3. Sanity Check: Ansible Installed
if ! command -v ansible-playbook &> /dev/null; then
    echo "[-] Error: 'ansible-playbook' could not be found."
    echo "    Please install Ansible on your machine before running this script."
    echo "    On macOS: brew install ansible"
    echo "    On Ubuntu/Debian: sudo apt install ansible"
    exit 1
fi

# 4. Check for private SSH key configuration
echo "[+] Checking SSH key..."
REAL_SSH_KEY_PATH="${SSH_KEY_PATH/#\~/$HOME}"
if [ ! -f "$REAL_SSH_KEY_PATH" ]; then
    echo "[!] Warning: SSH private key not found at $SSH_KEY_PATH"
    echo "    Please ensure you have configured your .env with the correct private key path."
fi

# 5. Prompt for Tailscale Auth Key if not already in env
TS_KEY="${TAILSCALE_AUTH_KEY:-}"
if [ -z "$TS_KEY" ]; then
    read -rsp "[?] Enter Tailscale Auth Key (optional, press Enter to skip): " TS_KEY
    echo ""
    if [ -n "$TS_KEY" ]; then
        export TAILSCALE_AUTH_KEY="$TS_KEY"
    fi
fi

# 6. Check if target user is root or has passwordless sudo
IS_ROOT=false
if [ "$SERVER_USER" = "root" ]; then
    IS_ROOT=true
fi

# Determine if we should ask for become password
ASK_BECOME=${ASK_BECOME_PASS:-}
if [ -z "$ASK_BECOME" ]; then
    if [ "$IS_ROOT" = true ]; then
        ASK_BECOME="false"
    else
        ASK_BECOME="true"
    fi
fi

# 7. Execute playbook
cd "$REPO_DIR"

echo ""
echo "==============================================="
echo "  Provisioning Plan & Information"
echo "==============================================="
echo "[+] The Ansible playbook will configure the following on the remote server:"
echo "    - Base setup (installing curl, git, ufw, etc.)"
echo "    - Security configuration (hardening SSH, configuring fail2ban, and setting up UFW)"
echo "    - Docker setup (installing Docker, Docker Compose, and setting up docker user group)"
echo "    - Tailscale setup (installing Tailscale, joining the mesh network, and enabling SSH over Tailscale)"
echo "    - Service directories preparation under /opt/docker (postgres, redis, portainer, coolify, etc.)"
echo ""
if [ "$ASK_BECOME" = "false" ]; then
    echo "[+] Skipping privilege escalation password prompt (configured or user is root)."
else
    echo "[!] IMPORTANT: Ansible will prompt you for the 'BECOME password'."
    echo "    --> This is the sudo/root password of the remote target server."
    echo "    --> It is required so Ansible can run setup tasks with administrative privileges."
fi
echo "==============================================="
echo ""

PLAYBOOK_ARGS=("-i" "inventory.ini" "ansible/site.yml")

if [ "$ASK_BECOME" = "true" ]; then
    PLAYBOOK_ARGS+=("--ask-become-pass")
fi

echo "[+] Running Ansible playbook..."
ansible-playbook "${PLAYBOOK_ARGS[@]}"

echo "==============================================="
echo "[+] Provisioning execution finished!"
echo "    If Tailscale was not auto-authenticated, SSH into your server"
echo "    and run: sudo tailscale up --ssh"
echo "==============================================="
