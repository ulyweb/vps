# VPS Homelab Stack — Architecture & Traffic Flow

A self-hosted homelab running on Ubuntu VPS with Docker containers behind Nginx Proxy Manager. All services are accessible via secure HTTPS subdomains — no service is directly exposed to the internet.

---

## Architecture Diagram

The diagram below shows how traffic flows from the outside internet through the security layers, through Nginx Proxy Manager, and down to each individual Docker container.

```mermaid
graph TD
    %% Styles
    classDef internet  fill:#0ea5e9,stroke:#0284c7,stroke-width:2px,color:#fff
    classDef security  fill:#ef4444,stroke:#dc2626,stroke-width:2px,color:#fff
    classDef proxy     fill:#f59e0b,stroke:#d97706,stroke-width:2px,color:#fff
    classDef app       fill:#10b981,stroke:#059669,stroke-width:2px,color:#fff
    classDef db        fill:#6366f1,stroke:#4f46e5,stroke-width:2px,color:#fff
    classDef mgmt      fill:#8b5cf6,stroke:#7c3aed,stroke-width:2px,color:#fff

    User["👤 User\n(Browser / Mobile Apps)"]:::internet
    DNS["🌐 Custom Domain DNS\n(*.yourdomain.com → VPS IP)"]:::internet

    subgraph VPS ["☁️ Ubuntu VPS"]

        subgraph Security ["🔒 Security Layer"]
            UFW["🛡️ UFW Firewall\nOpen: 80 · 443 · 81 · 22"]:::security
            Fail2Ban["🚨 Fail2Ban\nBrute Force Protection\n(SSH + Web)"]:::security
        end

        NPM["🔄 Nginx Proxy Manager\nSSL Termination · Let's Encrypt\nReverse Proxy Routing"]:::proxy

        subgraph Docker ["🐳 Docker Network: npm_default"]

            subgraph Storage ["Storage & Files"]
                Nextcloud["☁️ Nextcloud AIO\nnc.yourdomain.com\nPort 11000"]:::app
                FileBrowser["📁 FileBrowser\nfiles.yourdomain.com\nPort 80"]:::app
            end

            subgraph Security2 ["Security & Privacy"]
                Vaultwarden["🔐 Vaultwarden\nvault.yourdomain.com\nPort 80"]:::app
            end

            subgraph Media ["Media"]
                Immich["📸 Immich\nphotos.yourdomain.com\nPort 2283"]:::app
            end

            subgraph Management ["Management"]
                Portainer["🐋 Portainer\nportainer.yourdomain.com\nPort 9000"]:::mgmt
            end

            NC_DB[("Nextcloud Data\nPostgres + Redis\n(internal)")]:::db
            Immich_DB[("Immich Data\nPostgres + Valkey\n+ ML Model Cache\n(internal)")]:::db
        end

    end

    %% Traffic Flow — Internet to VPS
    User -->|"Types URL in browser"| DNS
    DNS -->|"Resolves to VPS IP"| UFW
    Fail2Ban -.->|"Bans malicious IPs"| UFW
    UFW -->|"Port 443 HTTPS"| NPM
    UFW -->|"Port 81 Admin"| NPM

    %% NPM Routing to Containers
    NPM -->|"nc.yourdomain.com"| Nextcloud
    NPM -->|"vault.yourdomain.com"| Vaultwarden
    NPM -->|"photos.yourdomain.com"| Immich
    NPM -->|"files.yourdomain.com"| FileBrowser
    NPM -->|"portainer.yourdomain.com"| Portainer

    %% Internal DB Connections
    Nextcloud --- NC_DB
    Immich --- Immich_DB
```

---

## How It Works

| Layer | Component | Role |
|-------|-----------|------|
| **DNS** | Your domain registrar | Wildcard A record `*.yourdomain.com` points to VPS IP |
| **Firewall** | UFW | Only ports 22, 80, 443, 81 open — everything else blocked |
| **Brute Force** | Fail2Ban | Auto-bans IPs that fail SSH or web login repeatedly |
| **Proxy / SSL** | Nginx Proxy Manager | Routes subdomains to containers, manages Let's Encrypt certs |
| **Containers** | Docker (`npm_default`) | All services run isolated, only reachable through NPM |

---

## Services

| Service | Subdomain | Purpose |
|---------|-----------|---------|
| **Nginx Proxy Manager** | `npm.yourdomain.com` | SSL gateway and routing hub — admin panel |
| **Nextcloud AIO** | `nc.yourdomain.com` | Self-hosted Google Drive — files, calendar, contacts |
| **Vaultwarden** | `vault.yourdomain.com` | Self-hosted Bitwarden — password manager |
| **Immich** | `photos.yourdomain.com` | Self-hosted Google Photos — photo & video backup |
| **FileBrowser** | `files.yourdomain.com` | Web-based file manager for your VPS storage |
| **Portainer** | `portainer.yourdomain.com` | Docker container management dashboard |

---

## The Golden Rule

Every container joins the `npm_default` Docker network and uses `expose:` (never `ports:`).
NPM is the only entry point from the internet — no container is directly reachable externally.

```yaml
networks:
  npm_net:
    external: true
    name: npm_default   # must be this exact name
```

---

## Quick Deploy

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ulyweb/vps/refs/heads/main/community/vps-community-install.sh)
```

> Requires Ubuntu 22.04 / 24.04 · Non-root sudo user · DNS records pointing to your VPS IP
