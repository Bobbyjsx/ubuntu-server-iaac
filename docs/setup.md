# Server Setup Guide

This guide describes how to bootstrap and provision the home server using this Infrastructure-as-Code repository.

## Prerequisites

1. **SSH Status:** SSH should be set up and active on your server (target machine).
2. **Ansible Status:** Ansible should be installed on the host (control machine).
3. **Target Machine:** A clean installation of Ubuntu Server 24.04+ with SSH enabled.
4. **Control Machine:** Your workstation (macOS/Linux) with Ansible installed.
5. **SSH Key:** An SSH public key configured on the target server (e.g., in `~/.ssh/authorized_keys` for the setup user).
6. **Tailscale Account:** Access to the Tailscale admin console to generate a pre-authorization key.

---

## Step 1: Pre-requisites & Local Configuration

1. Clone this repository to your workstation:
   ```bash
   git clone <your-repo-url> home-server-iac
   cd home-server-iac
   ```

2. Initialize and configure your environment variables:
   Run the following command to generate your local `.env` file:
   ```bash
   make setup
   ```
   Open the newly created `.env` file and configure it with your server's credentials:
   ```env
   SERVER_IP=192.168.1.107
   SERVER_USER=bobbyjsx
   SSH_KEY_PATH=~/.ssh/id_ed25519
   TAILSCALE_AUTH_KEY=
   ```
   * **`SERVER_IP`**: Your target server's current local IP address.
   * **`SERVER_USER`**: The actual username you use to SSH into your server (e.g. `ubuntu`, `bobbyjsx`, or `root`).
   * **`SSH_KEY_PATH`**: The path to the private SSH key on your workstation matching the public key authorized on the target server.
   * **`TAILSCALE_AUTH_KEY`**: An optional Tailscale pre-authorized auth key to connect the server to your Tailnet automatically.

---

## Step 2: Provisioning with Ansible

To automate the initial package installations, Docker installation, security hardening, firewall configuration, and Tailscale setup, run the bootstrap initiator using `make`:

```bash
make bootstrap
```

This command will:
- Check that your `.env` is present.
- Dynamically build the `inventory.ini` file using your `.env` values.
- Check for local Ansible installations.
- Prompt you for a Tailscale Auth Key if not already set in `.env`.
- Run the Ansible playbook with or without root password prompts depending on your target user.

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
