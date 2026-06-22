# Architecture Design

This document details the systems architecture, networking configuration, and container topology of the homelab home server.

## Overview

The home server architecture leverages **Tailscale** as an overlay network, ensuring that admin interfaces are never exposed to the public internet. Internally, services are containerized via **Docker Compose** stacks, communicating via dedicated Docker networks and binding admin dashboard ports exclusively to the loopback interface (`127.0.0.1`).

```mermaid
graph TD
    subgraph Workstation / Client
        Client[Workstation Client]
        TSTunnel[Tailscale Client / SSH Tunnel]
    end

    subgraph Home Server (Ubuntu 24.04)
        subgraph OS / Network Layer
            UFW[UFW Firewall]
            TS[Tailscale Daemon]
            DockerDaemon[Docker Engine]
        end

        subgraph Docker Bridge Networks
            subgraph "monitoring-net (Internal)"
                Prom[Prometheus]
                Graf[Grafana]
            end

            subgraph "homelab-net (Internal)"
                Postgres[Core PostgreSQL]
                Redis[Core Redis]
            end

            subgraph "coolify (Internal)"
                Coolify[Coolify Panel]
                Soketi[Soketi Realtime]
                CoolifyDB[(Coolify PG DB)]
                CoolifyRedis[(Coolify Redis Cache)]
            end
        end

        NodeExporter[Node Exporter - Host Network]
    end

    %% Network flows
    Client -->|Public Internet - Blocker| UFW
    TSTunnel -->|Encrypted VPN tunnel| TS
    TS -->|Bypasses UFW filters via tailscale0| DockerDaemon
    
    %% Host and Loopback routing
    TSTunnel -->|Local Port Forwarding| Graf
    TSTunnel -->|Local Port Forwarding| Coolify
    
    %% Monitoring metrics gathering
    Prom -->|Scrapes port 9090| Prom
    Prom -->|Scrapes port 9100| NodeExporter
    Graf -->|Queries| Prom
    
    %% Coolify internals
    Coolify -->|Manages| CoolifyDB
    Coolify -->|Manages| CoolifyRedis
    Coolify -->|Manages| Soketi
    Coolify -->|Orchestrates| DockerDaemon
```

## Security Domains

1. **Public Internet Zone:** All incoming traffic is denied by default by the UFW firewall, except for the SSH port 22 (for bootstrapping backup).
2. **Tailnet Zone:** Users connected to the Tailscale VPN have access to the server. The UFW firewall permits all traffic originating from the `tailscale0` network interface.
3. **Loopback Zone (`127.0.0.1`):** High-privilege admin dashboards (Portainer, Coolify, Prometheus, Grafana) bind their ports specifically to localhost. They are not exposed to the Tailscale subnet directly, requiring an SSH tunnel or a reverse proxy. This prevents accidental exposure within the Tailnet.
4. **Docker Network Isolation:** Docker networks are separated by stack (`monitoring-net`, `homelab-net`, `coolify`). Containers on `monitoring-net` cannot access `homelab-net` databases directly, minimizing the blast radius in the event of a container compromise.

---

## Configuration & Tooling Architecture

The provisioning and orchestration tooling utilizes a workstation-to-server deployment flow controlled entirely by local environment variables and a Makefile:

```mermaid
graph LR
    Env[.env File] -->|Feeds| Make[Makefile]
    Make -->|Triggers| Bootstrap[Bootstrap Script]
    Env -->|Loads into environment| Bootstrap
    Bootstrap -->|Generates| Inv[inventory.ini]
    Bootstrap -->|Executes| Ansible[Ansible Playbook]
    Inv -->|Targets| Remote[Remote Target Server]
    Ansible -->|Provisions| Remote
```

1. **Environment Variables (.env):** All target server parameters (IP address, SSH connection username, SSH key path, and optional Tailscale auth keys) are declared in a local, Git-ignored `.env` file. This centralizes configurations and prevents committing credentials.
2. **Makefile Entry Point:** Serves as a standard, vendor-neutral interface for administrators to execute common tasks (`make setup`, `make bootstrap`, `make ssh`).
3. **Dynamic Inventory Generation:** To avoid maintaining duplicate settings, the bootstrap script reads the `.env` variables and dynamically writes out the `inventory.ini` file before calling `ansible-playbook`.
4. **Adaptive Privilege Escalation:** The provisioning script detects whether the target connection user is `root`. If it is, the script disables the `--ask-become-pass` flag and avoids prompting for a sudo password, optimizing the connection workflow for root-only setups.
