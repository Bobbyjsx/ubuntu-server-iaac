# Service Catalog & Configurations

This document catalogs the services deployed on the home server, explaining their roles, internal architectures, volumes, and ports.

---

## 1. Administrative Services

### Portainer CE
- **Role:** Web GUI for managing Docker containers, images, volumes, and networks.
- **Port Bindings:** `127.0.0.1:9443` (HTTPS) & `127.0.0.1:9000` (HTTP).
- **Persistent Data:** Named volume `portainer_data` mapped to `/data` in the container.
- **Internal Access:** Directly mounts `/var/run/docker.sock` to control the host Docker engine.

### Coolify
- **Role:** An open-source, self-hosted Heroku/Netlify alternative. It automates build packs, database provisioning, SSL certificates, and Git integrations.
- **Port Bindings:** `127.0.0.1:8000` (HTTP).
- **Internal Services:**
  - `coolify`: The PHP Laravel application core.
  - `postgres` (`coolify-db`): Dedicated Postgres instance for Coolify metadata.
  - `redis` (`coolify-redis`): Dedicated Redis instance for queuing and caching.
  - `soketi` (`coolify-realtime`): WebSockets server for real-time deployment logs.
- **Persistent Data:** Subdirectories inside `/data/coolify/` mapping configuration databases, SSH keys, application logs, and service templates.

---

## 2. Core Databases & Caching

### Core PostgreSQL
- **Role:** General-purpose relational database for external applications and custom services.
- **Port Bindings:** `127.0.0.1:5432`.
- **Persistent Data:** Named volume `pgdata_core` mapped to `/var/lib/postgresql/data`.
- **Isolation:** Placed inside the `homelab-net` Docker network, preventing access from unauthorized stacks.

### Core Redis
- **Role:** Key-value store for caching, job queues, and sessions.
- **Port Bindings:** `127.0.0.1:6379`.
- **Persistent Data:** Named volume `redisdata_core` mapped to `/data`.
- **Authentication:** Enforces password-based authentication via command flag `--requirepass`.

---

## 3. Monitoring & Analytics

### Prometheus
- **Role:** Time-series database designed to collect and store metric values.
- **Port Bindings:** `127.0.0.1:9090`.
- **Persistent Data:** Named volume `prometheus_data` mapped to `/prometheus`.
- **Scrape Strategy:** Automatically scrapes metrics from itself and Node Exporter via the Docker network gateway interface.

### Grafana
- **Role:** Visual dashboard builder querying Prometheus database metrics.
- **Port Bindings:** `127.0.0.1:3000`.
- **Persistent Data:** Named volume `grafana_data` mapped to `/var/lib/grafana`.
- **Access Setup:** Preconfigured to disable public signup. Relies on the default administrator user.

### Node Exporter
- **Role:** System-level exporter developed by Prometheus to measure OS resource metrics (CPU, RAM, Disk, Network).
- **Port Bindings:** Exposes port `9100` on the host network (`network_mode: host`).
- **Isolation Level:** Operates inside the host network namespace to accurately monitor real hardware metrics rather than container-level namespaces.
