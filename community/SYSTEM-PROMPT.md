# SYSTEM PROMPT — VPS Homelab Stack Builder
> Paste this entire file at the start of a new AI conversation.
> It gives your AI full context about your VPS setup so you never
> have to re-explain the architecture, the rules, or the lessons learned.

---

## What I Am Building

I run a self-hosted homelab on a VPS (Ubuntu 22.04 / 24.04) with a custom domain.
I use **Nginx Proxy Manager (NPM)** as my SSL gateway and reverse proxy for all services.
All services run as Docker containers. I manage everything myself.

My goal is to keep adding self-hosted services to this stack over time — each one gets
its own subdomain, its own SSL certificate (Let's Encrypt via NPM), and runs as a
Docker container on a shared internal network.

---

## The Golden Rule — Docker Networking

Every container I run MUST join the shared Docker network named **`npm_default`**.
This is the only way NPM can route traffic to it by container name.

**Every docker-compose.yml I write uses this exact pattern:**

```yaml
services:
  myservice:
    image: some/image:latest
    container_name: myservice
    restart: unless-stopped
    expose:
      - "PORT"          # ALWAYS expose, NEVER ports — NPM handles external access
    networks:
      - npm_net

networks:
  npm_net:
    external: true
    name: npm_default   # This name must be exact — never change it
```

**Never use `ports:` on any container except NPM itself.** Using `ports:` would expose
the container directly to the internet, bypassing NPM and SSL. Always use `expose:`.

---

## Architecture Overview

```
Internet
    ↓
DNS: *.mydomain.com → VPS IP
    ↓
UFW Firewall (ports 80, 443, 81, 22 only)
    ↓
Nginx Proxy Manager (NPM) — SSL + routing hub
    ↓  routes by subdomain  ↓
Docker Network: npm_default
    ├── service1.mydomain.com → container:PORT
    ├── service2.mydomain.com → container:PORT
    └── ...
```

**NPM Proxy Host settings for every service:**
- Scheme: `http`
- Forward Hostname: **container name** (never IP address)
- Forward Port: the container's internal port
- SSL: Let's Encrypt, Force SSL ON, HTTP/2 ON, Block Common Exploits ON
- WebSocket: ON for most services

---

## Current Services Installed

| Service | Subdomain | Container Name | Port |
|---------|-----------|----------------|------|
| Nginx Proxy Manager | npm.mydomain.com | npm | 80/81/443 |
| Nextcloud AIO | nc.mydomain.com | nextcloud-aio-mastercontainer | 11000 |
| Vaultwarden | vault.mydomain.com | vaultwarden | 80 |
| Immich | photos.mydomain.com | immich-server | 2283 |
| FileBrowser | files.mydomain.com | filebrowser-community | 80 |
| Portainer | portainer.mydomain.com | portainer | 9000 |

*(Replace `mydomain.com` with your actual domain)*

---

## Security Setup

- **UFW firewall**: only ports 22 (SSH), 80, 443, 81 (NPM admin) are open
- **Fail2Ban**: installed with Docker-aware iptables rules, monitors SSH + NPM logs
- **No container except NPM** has direct internet exposure — all traffic goes through NPM's SSL proxy

---

## How I Installed Everything

I used a single automated bash installer script that:
1. Prompts for all configuration upfront (domain, subdomains, credentials)
2. Installs Docker, UFW, Fail2Ban
3. Creates the `npm_default` Docker network
4. Deploys NPM and seeds the admin user via SQLite (NPM v2 does not auto-create a user)
5. Creates all proxy hosts + SSL certificates via the NPM API
6. Deploys each selected service
7. Configures Fail2Ban with Docker-aware rules

**One-liner to install on a fresh VPS:**
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ulyweb/vps/refs/heads/main/community/vps-community-install.sh)
```

---

## Critical Known Issues (Hard-Won Lessons)

### 1. NPM v2 does not auto-create an admin user
NPM v2 requires a manual SQLite seed after startup. Three tables must be inserted:
`user`, `auth`, and `user_permission`. Missing `user_permission` causes the JWT to have
wrong scope and `/users/1` returns 404. The database is root-owned — use `sudo sqlite3`.

### 2. Use `docker rm -f` not `docker stop`
`docker stop` waits 10 seconds per container for graceful shutdown and can hang
indefinitely on containers in bad states. Always use `docker rm -f` when re-deploying.

### 3. Never run the installer as root
Hostinger VPS defaults to root login. Create a regular user first:
```bash
adduser myuser && usermod -aG sudo myuser && usermod -aG docker myuser
```
Then log in as that user and run the installer.

### 4. Immich service naming (v2.6.3+)
Immich requires the internal Postgres service to be named `database` and Redis to be
named `redis` (not `immich-postgres` or `immich-redis`). Use:
- `ghcr.io/immich-app/postgres:14-vectorchord0.3.0-pgvectors0.2.0`
- `valkey/valkey:8-bookworm` (not plain redis)

### 5. Nextcloud AIO has one unavoidable manual step
Nextcloud AIO setup requires a browser visit to `http://VPS_IP:8080` to complete
initial configuration. This cannot be automated. Everything else is automated.

### 6. If a container gets a 502 Bad Gateway through NPM
The container is probably not on the `npm_default` network. Fix:
```bash
docker network connect npm_default CONTAINER_NAME
docker network inspect npm_default --format '{{range .Containers}}{{.Name}}{{"\n"}}{{end}}'
```

### 7. apt-get upgrade is slow and unnecessary on a fresh VPS
Skip `apt-get upgrade`. Just run `apt-get update` with timeout flags:
```bash
sudo apt-get update -q -o Acquire::http::Timeout=30 -o Acquire::Retries=2
```

---

## How to Add a New Service

This is the exact pattern. Follow it every time:

**Step 1 — Create the directory and docker-compose.yml**
```bash
mkdir ~/myservice && cd ~/myservice
```

**Step 2 — Write docker-compose.yml**
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
    environment:
      - ANY_REQUIRED_ENV_VARS=value
    volumes:
      - ./data:/data   # if persistent storage is needed

networks:
  npm_net:
    external: true
    name: npm_default
```

**Step 3 — Start the container**
```bash
docker compose up -d
docker compose logs -f myservice
```

**Step 4 — Add proxy host in NPM**
- Go to: `https://npm.mydomain.com`
- Proxy Hosts → Add Proxy Host
- Domain: `myservice.mydomain.com`
- Scheme: `http`
- Forward Hostname: `myservice` (the container name — never IP)
- Forward Port: `PORT`
- WebSocket Support: ON
- SSL tab: Request Let's Encrypt cert, Force SSL ON, HTTP/2 ON, Block Common Exploits ON

**Step 5 — If you get 502 Bad Gateway**
```bash
docker network connect npm_default myservice
```

---

## Rules for the AI Working With Me

1. **Always use the `npm_default` network pattern** — never deviate from it
2. **Always use `expose:` not `ports:`** — except for NPM itself
3. **Always use container names** as forward hostnames in NPM — never IPs
4. **Diagnose before building** — read existing files, find root cause before writing code
5. **Use `docker rm -f`** not `docker stop` when redeploying
6. **Never run anything as root** — always as a regular sudo user
7. **When adding a service with a database**, generate a random password:
   `openssl rand -hex 16`
8. **Check `node --check`** on any JavaScript files before deploying
9. **Verify** that new containers joined `npm_default` after deploying:
   `docker network inspect npm_default --format '{{range .Containers}}{{.Name}}{{"\n"}}{{end}}'`
10. **The full architecture is in the Artifact document** — reference it before suggesting anything

---

## What to Say to Start a Session

> "I have a self-hosted VPS homelab running Docker + Nginx Proxy Manager.
> I want to add [SERVICE NAME] to my stack. My domain is [DOMAIN].
> Here is my full system context: [paste ARTIFACT.md]"
