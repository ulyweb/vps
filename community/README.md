# VPS Community Installer

A single-command self-hosted homelab stack deployer for Ubuntu 22.04 / 24.04 VPS.

No config files to edit. No YAML to write. Just answer the prompts and walk away.

---

## Quick Start

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ulyweb/vps/refs/heads/main/community/vps-community-install.sh)
```

---

## What It Installs

**Nginx Proxy Manager** is always installed — it is the SSL gateway and reverse proxy that routes all your subdomains. Every other service is optional.

| Service | Description |
|---------|-------------|
| **Nginx Proxy Manager** | SSL termination + reverse proxy for all subdomains (required) |
| **Nextcloud AIO** | Self-hosted Google Drive — file storage, calendar, contacts |
| **Vaultwarden** | Self-hosted Bitwarden — password manager compatible with all Bitwarden apps |
| **Immich** | Self-hosted Google Photos — photo and video backup with AI features |
| **FileBrowser** | Web-based file manager for your VPS storage |
| **Portainer** | Docker container management dashboard |

---

## Before You Run

1. **Get a VPS** running Ubuntu 22.04 or 24.04 (non-root sudo user required)
2. **Point your DNS** — create A records for each subdomain you want, all pointing to your VPS IP
   - Easiest: use a wildcard record `*.yourdomain.com → VPS IP`
   - Wait 5–30 minutes for DNS to propagate before running the script
3. **Run the one-liner** above — the wizard will ask for everything it needs

---

## What the Wizard Asks

- Your VPS public IP address
- Your base domain (e.g. `example.com`)
- Which services to install
- Subdomain names for each service (defaults provided)
- Email for Let's Encrypt SSL certificates
- NPM admin login credentials

All services are deployed on a shared Docker network (`npm_default`) with Let's Encrypt SSL handled automatically through NPM.

---

## Security

- UFW firewall configured (only ports 80, 443, 81, 22 open)
- Fail2Ban installed with Docker-aware rules (SSH + web brute force protection)
- All containers use `expose` only — nothing is directly reachable from the internet except through NPM's SSL proxy

---

## Adding a Service Later

Any Docker image can be added to the stack using this pattern:

```yaml
services:
  myservice:
    image: some/image:latest
    container_name: myservice
    restart: unless-stopped
    expose:
      - "PORT"
    networks:
      - npm_net

networks:
  npm_net:
    external: true
    name: npm_default
```

Then add a proxy host in NPM pointing to the container name and port.

---

## Requirements

- Ubuntu 22.04 or 24.04
- A domain with DNS you control
- Run as a non-root sudo user (not root)
