# Security Architecture & Access Model

This document explains the security design implemented by the automation playbooks and configuration choices in this repository.

---

## 1. SSH Hardening

SSH is the gateway to the host operating system. The `security` role locks down the OpenSSH daemon config in `/etc/ssh/sshd_config` with these settings:

- **PasswordAuthentication no:** Forces the use of cryptographic key-based authentication. Passwords cannot be brute-forced.
- **PermitRootLogin no:** Prevents root access directly over SSH. Administrators must log in as the target non-root user (e.g., `ubuntu`) and escalate privileges via `sudo`.
- **PubkeyAuthentication yes:** Explicitly enforces ssh-key exchange.

### Intrusion Prevention with Fail2ban
Fail2ban is installed and configured via `/etc/fail2ban/jail.local`. It monitors `/var/log/auth.log` and automatically bans IP addresses that show signs of malicious login attempts (5 failed attempts within 10 minutes leads to a 24-hour ban).

---

## 2. Firewall Policy (UFW)

The system enforces a **Default Deny Incoming** policy.

```
Incoming: DENY (Default)
Outgoing: ALLOW (Default)
```

### Tailscale Trust
The firewall allows all traffic on the `tailscale0` virtual interface:
```bash
sudo ufw allow in on tailscale0
```
This ensures that any machine authenticated on your Tailscale network has seamless access to the server, while machines on the local LAN or public WAN are blocked.

### The Docker Firewall Bypass Trap
By default, Docker manipulates `iptables` directly to expose ports, bypassing standard UFW rules. This means exposing `80:80` in a `docker-compose.yml` makes that port public even if UFW has a default deny rule.

**Mitigation:** 
To prevent public exposure, all administrative dashboards in this repository bind their ports to the loopback interface (`127.0.0.1`):
```yaml
ports:
  - "127.0.0.1:9443:9443"
```
Because the container binds to localhost, the host kernel refuses to route packets arriving from external interfaces (like `eth0`) to these ports, providing absolute isolation.

---

## 3. How to Connect Securely

Since admin panels (Portainer, Grafana, Coolify) bind to `127.0.0.1`, you cannot access them directly by typing the Tailscale IP in a browser. You must connect using one of two patterns:

### Option A: SSH Local Port Forwarding (Recommended)
Establish an SSH tunnel over Tailscale:
```bash
ssh -L 9443:127.0.0.1:9443 ubuntu@<your-tailscale-ip>
```
You can then open `https://127.0.0.1:9443` on your local workstation to access Portainer.

### Option B: Tailscale Serve / Funnel (For Dashboard Sharing)
Tailscale includes a built-in reverse proxy tool called `tailscale serve`. You can configure Tailscale to proxy traffic from the Tailnet to local ports. For example, to share Grafana within your Tailnet on port `443` (HTTPS):
```bash
tailscale serve https:443 / http://127.0.0.1:3000
```
This is fully secure, managed by Tailscale, and doesn't require modifying firewall rules.
