# Disaster Recovery & Host Rebuild Guide

This guide outlines how to restore your home server from scratch in the event of hardware failure, operating system corruption, or data loss.

---

## 1. Backup Strategy

To support full recovery, you must back up the following data directories on a regular schedule (e.g., via cron job to an external drive or S3 bucket):

| Service | Data to Back Up | Location on Host | Backup Method |
| :--- | :--- | :--- | :--- |
| **PostgreSQL** | Database cluster files or SQL dumps | `/opt/docker/postgres/data` | `pg_dumpall` (recommended) or file backup |
| **Redis** | Redis RDB database file | `/opt/docker/redis/data/dump.rdb` | Copy `dump.rdb` after executing `BGSAVE` |
| **Coolify** | SSH keys, settings, backup configs | `/data/coolify` | Tarball backup of `/data/coolify` |
| **Portainer** | User credentials, registry configs | Docker volume `portainer_data` | Tarball backup of `/var/lib/docker/volumes/portainer_data` |
| **Grafana** | Dashboard configurations, user data | Docker volume `grafana_data` | Tarball backup of `/var/lib/docker/volumes/grafana_data` |

### Recommended Automated Backup Script Example
```bash
#!/usr/bin/env bash
# Run pg_dumpall to backup core database
docker exec -t core-postgres pg_dumpall -U admin > /backups/postgres_core_$(date +%F).sql

# Compress docker directories
tar -czf /backups/docker_opt_$(date +%F).tar.gz /opt/docker
tar -czf /backups/coolify_$(date +%F).tar.gz /data/coolify
```

---

## 2. Server Rebuild Steps

Follow these steps to reconstruct the server from a clean OS install:

### Step 1: Base System Prep
1. Install a fresh copy of **Ubuntu Server 24.04 LTS**.
2. Add your SSH public key to the default user's `~/.ssh/authorized_keys` file.
3. Determine the server's local network IP address.

### Step 2: Restore Core Directories
Before running Ansible, restore the backup files to the target directories. If you have backup tarballs:
1. Create the directories:
   ```bash
   sudo mkdir -p /opt/docker /data/coolify
   ```
2. Extract the backups to their respective locations:
   ```bash
   sudo tar -xzf docker_opt_backup.tar.gz -C /opt/docker
   sudo tar -xzf coolify_backup.tar.gz -C /data/coolify
   ```
3. Set correct directory ownership:
   ```bash
   sudo chown -R ubuntu:ubuntu /opt/docker
   ```

### Step 3: Run the IaC Provisioning Playbook
On your workstation:
1. Ensure `inventory.ini` contains the target server's IP.
2. Run the bootstrap script:
   ```bash
   ./scripts/bootstrap.sh
   ```
3. Provide your Tailscale Auth Key when prompted.

### Step 4: Bring Services Back Up
Ansible will automatically install Docker, UFW, Tailscale, and other dependencies.
Log back into the server via Tailscale and run:
```bash
# Start Core PostgreSQL and verify data
cd /opt/docker/postgres && docker compose up -d
# Start Core Redis
cd /opt/docker/redis && docker compose up -d
# Start Portainer
cd /opt/docker/portainer && docker compose up -d
# Start Coolify
cd /opt/docker/coolify && docker compose up -d
# Start Monitoring
cd /opt/docker/monitoring && docker compose up -d
```
All dashboards will compile back to their state prior to failure, using the restored persistent volumes.
