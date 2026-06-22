# Server Setup Guide

This guide describes how to bootstrap and provision the home server using this Infrastructure-as-Code repository.

## Prerequisites

1. **Target Machine:** A clean installation of Ubuntu Server 24.04+ with SSH enabled.
2. **Control Machine:** Your workstation (macOS/Linux) with Ansible installed.
3. **SSH Key:** An SSH public key configured on the target server (e.g., in `~/.ssh/authorized_keys` for the setup user).
4. **Tailscale Account:** Access to the Tailscale admin console to generate a pre-authorization key.

---

## Step 1: Pre-requisites & Local Inventory Configuration

1. Clone this repository to your workstation:
   ```bash
   git clone <your-repo-url> home-server-iac
   cd home-server-iac
   ```

2. Edit the inventory file at `inventory.ini` (or `inventory/hosts.ini`):
   ```ini
   [home_servers]
   home-server ansible_host=192.168.1.100 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_ed25519
   ```
   *Modify `ansible_host` to match your server's current local IP, and verify the `ansible_user` and SSH key path.*

---

## Step 2: Provisioning with Ansible

To automate the initial packages, Docker installation, security hardening, firewall configuration, and Tailscale setup, run the bootstrap script:

```bash
./scripts/bootstrap.sh
```

The script will:
- Check for local Ansible installations.
- Prompt you for an optional Tailscale Auth Key (recommended for headless execution).
- Run the Ansible playbook.

### Manual Tailscale Authentication (If Auth Key was Skipped)
If you did not provide a Tailscale Auth Key during bootstrap, SSH into the server using your local IP and run:
```bash
sudo tailscale up --ssh
```
Log in via the printed URL to authenticate the server on your Tailnet.

---

## Step 3: Launching Docker Stacks

Once Ansible has finished provisioning, the firewall will block external access to ports. To launch the services, SSH into the machine over Tailscale:

```bash
ssh ubuntu@<your-tailscale-ip>
```

Navigate to the docker directories (pre-created by Ansible under `/opt/docker`) and launch the services:

### 1. PostgreSQL (Core DB)
```bash
cd /opt/docker/postgres
# Copy docker-compose file if not already done, configure variables in a local .env, then:
docker compose up -d
```

### 2. Redis (Core Cache)
```bash
cd /opt/docker/redis
docker compose up -d
```

### 3. Portainer
```bash
cd /opt/docker/portainer
docker compose up -d
```
Access Portainer securely via SSH port forwarding or your Tailnet at `https://127.0.0.1:9443` (tunneling to localhost).

### 4. Coolify
```bash
cd /opt/docker/coolify
docker compose up -d
```
Access Coolify at `http://127.0.0.1:8000`.

### 5. Monitoring Stack
```bash
cd /opt/docker/monitoring
docker compose up -d
```
- **Prometheus:** Access at `http://127.0.0.1:9090`
- **Grafana:** Access at `http://127.0.0.1:3000`

---

## Verified Commands

To check the status of your containers, run:
```bash
docker ps
```
To verify that UFW is enabled and blocking public access:
```bash
sudo ufw status verbose
```
You should see that the Tailscale interface (`tailscale0`) is fully allowed, while standard public access is denied (except for bootstrap SSH port 22).
