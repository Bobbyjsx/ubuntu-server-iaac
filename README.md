# Home Server Infrastructure as Code (IaC)

A production-ready, fully automated Infrastructure-as-Code repository to provision and manage a personal homelab server running **Ubuntu Server 24.04+**.

---

## Architecture Overview

This repository automates host configuration and launches a Docker-based homelab suite. It is designed around the **Zero Public Exposure** security model:

- **Host Hardening:** Disables password authentication, enforces SSH keys, and configures UFW firewall + fail2ban.
- **Tailscale Overlay:** Encrypts and tunnels management traffic. The server is accessed exclusively via your private Tailnet.
- **Port Isolation:** High-privilege management dashboards (Portainer, Coolify, Prometheus, Grafana) bind directly to `127.0.0.1` inside Docker, completely immune to port-scanner discovery and firewall bypass exploits.

```
                  +-----------------------------------+
                  |     Control Machine (Workstation) |
                  +-----------------------------------+
                                    |
                           SSH Key + Ansible
                                    v
                  +-----------------------------------+
                  |  Home Server Host (Ubuntu 24.04)  |
                  |                                   |
                  |   +---------------------------+   |
                  |   |  Firewall (UFW + Fail2ban)|   |
                  |   +---------------------------+   |
                  |                 |                 |
                  |      Allows traffic via:          |
                  |                 v                 |
                  |   +---------------------------+   |
                  |   |   Tailscale (tailscale0)  |   |
                  |   +---------------------------+   |
                  |                 |                 |
                  |                 v                 |
                  |   +---------------------------+   |
                  |   | Docker Engine & Stacks    |   |
                  |   | (Portainer, Coolify,      |   |
                  |   |  PG, Redis, Monitoring)   |   |
                  |   +---------------------------+   |
                  +-----------------------------------+
```

---

## Directory Structure

```text
home-server-iac/
├── README.md               # Repository overview and quickstart
├── inventory.ini           # Ansible host configuration (root convenience copy)
├── ansible/
│   ├── site.yml            # Main playbook running all roles
│   └── roles/
│       ├── base/           # Installs core utilities & establishes directory structures
│       ├── docker/         # Configures Docker Engine & Docker Compose plugin
│       ├── security/       # SSH hardening, UFW firewall & fail2ban configurations
│       └── tailscale/      # Registers and authenticates Tailscale overlay daemon
├── docker/
│   ├── coolify/            # Coolify platform compose stack
│   ├── monitoring/         # Prometheus, Grafana, and Node Exporter compose stack
│   ├── portainer/          # Portainer CE dashboard compose stack
│   ├── postgres/           # Core production PostgreSQL container
│   └── redis/              # Core production Redis container
├── docs/
│   ├── architecture.md     # Detailed architecture schema
│   ├── recovery.md         # Disaster recovery plans and backup policies
│   ├── security.md         # Security hardening & port-forwarding access methods
│   ├── services.md         # Full catalog of deployed containers and endpoints
│   └── setup.md            # Step-by-step setup guide
├── inventory/
│   └── hosts.ini           # Target host inventory
└── scripts/
    └── bootstrap.sh        # Automates workstation Ansible executions
```

---

## Bootstrapping a New Server

A new, clean Ubuntu server can be fully provisioned in **two steps**:

### 1. Execute Workstation Bootstrap
Clone the repository, customize `inventory.ini` with your target server's IP, and execute the bootstrap script on your machine:
```bash
git clone <your-repo-url> home-server-iac
cd home-server-iac

# Edit inventory.ini with target IP and user
./scripts/bootstrap.sh
```
*Provide your Tailscale Auth Key when prompted for a fully automated setup.*

### 2. Connect via Tailscale and Up Docker Compose Stacks
SSH into your server over Tailscale:
```bash
ssh ubuntu@<your-tailscale-ip>
```
Run `docker compose up -d` in the service directories of your choice under `/opt/docker/`:
```bash
cd /opt/docker/postgres && docker compose up -d
cd /opt/docker/redis && docker compose up -d
cd /opt/docker/portainer && docker compose up -d
cd /opt/docker/coolify && docker compose up -d
cd /opt/docker/monitoring && docker compose up -d
```

---

## Documentation Index

For detailed guidelines, view the specific markdown sheets:
- [Setup & Installation Guide](file:///Users/bobby/Documents/Workspace/home-server/home-server-iaac/docs/setup.md)
- [Architecture Details](file:///Users/bobby/Documents/Workspace/home-server/home-server-iaac/docs/architecture.md)
- [Security & Access Guide](file:///Users/bobby/Documents/Workspace/home-server/home-server-iaac/docs/security.md)
- [Disaster Recovery & Rebuilding](file:///Users/bobby/Documents/Workspace/home-server/home-server-iaac/docs/recovery.md)
- [Service Catalog](file:///Users/bobby/Documents/Workspace/home-server/home-server-iaac/docs/services.md)
