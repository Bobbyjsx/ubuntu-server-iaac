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
