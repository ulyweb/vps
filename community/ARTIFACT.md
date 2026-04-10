# ARTIFACT — VPS Homelab Stack Blueprint
> This is the complete technical reference for your self-hosted VPS stack.
> Paste this alongside SYSTEM-PROMPT.md when starting a new AI conversation.
> Keep it updated as you add new services.

---

## Your VPS Identity

| Field | Value |
|-------|-------|
| **OS** | Ubuntu 22.04 / 24.04 |
| **Domain** | `mydomain.com` ← replace with yours |
| **Docker network** | `npm_default` |
| **User** | Regular sudo user (NOT root) |
| **Installer** | `bash <(curl -fsSL https://raw.githubusercontent.com/ulyweb/vps/refs/heads/main/community/vps-community-install.sh)` |

---

## How This Was Built — The Full Story

### Phase 1: Why We Built It
The goal was a personal self-hosted homelab — all your data, on your own server,
accessible from anywhere via secure HTTPS subdomains. No monthly subscriptions to
cloud services. No vendor lock-in. Full control.

### Phase 2: The Architecture Decision
We chose **Nginx Proxy Manager (NPM)** as the central routing hub because:
- It handles Let's Encrypt SSL automatically — zero manual cert renewal
- It routes traffic by subdomain to any container using just the container name
- It has a clean web UI so you never touch nginx config files manually
- It's the proven pattern for Docker-based homelab stacks

All containers join one shared Docker network (`npm_default`). NPM sits on that
network and can reach every container by name. The internet only ever talks to NPM.

### Phase 3: The Installer
Rather than manually writing docker-compose files and configuring NPM by hand for
each service, we built a single automated bash installer that:
- Prompts for all configuration once (domain, subdomains, credentials)
- Shows a confirmation screen before doing anything
- Deploys all selected services
- Seeds the NPM admin account automatically (solving the NPM v2 user-creation gap)
- Creates all proxy hosts + SSL certs via the NPM REST API
- Configures UFW firewall and Fail2Ban in one pass
- Logs everything to a timestamped file for debugging

### Phase 4: The Lessons (Every Hard Problem We Solved)
Every major obstacle we hit is documented in the System Prompt under
"Critical Known Issues." The biggest surprises were:
- NPM v2 needing manual SQLite seeding (3 tables, root-owned db)
- Immich requiring specific service names (`database`, `redis`) in v2.6.3+
- `docker stop` hanging — `docker rm -f` is always safer
- 502 errors always meaning "container not on npm_default network"

---

## Full Infrastructure Map

```
Internet
    ↓
DNS: *.mydomain.com → YOUR_VPS_IP
    ↓
UFW Firewall
  Open: 22 (SSH), 80 (HTTP), 443 (HTTPS), 81 (NPM Admin)
    ↓
Nginx Proxy Manager — npm_default network
    ↓ routes by subdomain ↓
┌─────────────────────────────────────────────────────────────┐
│                  Docker: npm_default                        │
│                                                             │
│  npm.mydomain.com       → npm                  :80/81/443  │
│  nc.mydomain.com        → nextcloud-aio        :11000      │
│  vault.mydomain.com     → vaultwarden          :80         │
│  photos.mydomain.com    → immich-server        :2283       │
│  files.mydomain.com     → filebrowser-community:80         │
│  portainer.mydomain.com → portainer            :9000       │
└─────────────────────────────────────────────────────────────┘
```

---

## Service Blueprints

### Nginx Proxy Manager
```yaml
# ~/npm/docker-compose.yml
services:
  npm:
    image: jc21/nginx-proxy-manager:2
    container_name: npm
    restart: unless-stopped
    ports:
      - "80:80"
      - "81:81"
      - "443:443"
    volumes:
      - ./data:/data
      - ./letsencrypt:/etc/letsencrypt
    networks:
      - npm_net

networks:
  npm_net:
    external: true
    name: npm_default
```
**Notes:**
- NPM is the ONLY container that uses `ports:` — it must be directly accessible
- Admin panel at `http://VPS_IP:81`
- Default credentials must be seeded via SQLite (see NPM Seeding section below)

---

### Vaultwarden (Bitwarden-compatible password manager)
```yaml
# ~/vaultwarden/docker-compose.yml
services:
  vaultwarden:
    image: vaultwarden/server:latest
    container_name: vaultwarden
    restart: unless-stopped
    environment:
      - WEBSOCKET_ENABLED=true
      - DOMAIN=https://vault.mydomain.com
    volumes:
      - ./vw-data:/data
    expose:
      - "80"
    networks:
      - npm_net

networks:
  npm_net:
    external: true
    name: npm_default
```
**NPM proxy:** forward to `vaultwarden` port `80`, WebSocket ON

---

### Immich (self-hosted Google Photos)
```yaml
# ~/immich/.env
UPLOAD_LOCATION=./immich-data
DB_DATA_LOCATION=./postgres
TZ=America/New_York
IMMICH_VERSION=release
DB_PASSWORD=RANDOM_HEX_HERE
DB_USERNAME=postgres
DB_DATABASE_NAME=immich
DB_HOSTNAME=database
```
```yaml
# ~/immich/docker-compose.yml
services:
  immich-server:
    image: ghcr.io/immich-app/immich-server:${IMMICH_VERSION:-release}
    container_name: immich-server
    volumes:
      - ${UPLOAD_LOCATION}:/usr/src/app/upload
      - /etc/localtime:/etc/localtime:ro
    env_file: .env
    expose:
      - "2283"
    depends_on:
      redis:
        condition: service_healthy
      database:
        condition: service_healthy
    restart: unless-stopped
    networks:
      - npm_net
      - immich_internal

  immich-machine-learning:
    image: ghcr.io/immich-app/immich-machine-learning:${IMMICH_VERSION:-release}
    container_name: immich-machine-learning
    volumes:
      - model-cache:/cache
    env_file: .env
    restart: unless-stopped
    networks:
      - immich_internal

  redis:
    image: docker.io/valkey/valkey:8-bookworm
    container_name: immich-redis
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "valkey-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 10
    networks:
      - immich_internal

  database:
    image: ghcr.io/immich-app/postgres:14-vectorchord0.3.0-pgvectors0.2.0
    container_name: immich-postgres
    environment:
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_USER: ${DB_USERNAME}
      POSTGRES_DB: ${DB_DATABASE_NAME}
      POSTGRES_INITDB_ARGS: '--data-checksums'
    volumes:
      - ${DB_DATA_LOCATION}:/var/lib/postgresql/data
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USERNAME} -d ${DB_DATABASE_NAME}"]
      interval: 10s
      timeout: 5s
      retries: 10
      start_period: 30s
    networks:
      - immich_internal

networks:
  npm_net:
    external: true
    name: npm_default
  immich_internal:
    internal: true

volumes:
  model-cache:
```
**NPM proxy:** forward to `immich-server` port `2283`, WebSocket ON
**Critical:** Internal services MUST be named `database` and `redis` (Immich v2.6.3+)

---

### FileBrowser (web file manager)
```yaml
# ~/filebrowser/docker-compose.yml
services:
  filebrowser:
    image: gtstef/filebrowser:stable
    container_name: filebrowser-community
    restart: unless-stopped
    user: "0:0"
    expose:
      - "80"
    volumes:
      - /root:/srv
      - ./filebrowser.db:/database/filebrowser.db
    environment:
      - FB_DATABASE=/database/filebrowser.db
    networks:
      - npm_net

networks:
  npm_net:
    external: true
    name: npm_default
```
**NPM proxy:** forward to `filebrowser-community` port `80`, WebSocket ON
**Default login:** admin / admin — change immediately on first login

---

### Portainer (Docker management UI)
```yaml
# ~/portainer/docker-compose.yml
services:
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: unless-stopped
    expose:
      - "9000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data
    networks:
      - npm_net

networks:
  npm_net:
    external: true
    name: npm_default

volumes:
  portainer_data:
```
**NPM proxy:** forward to `portainer` port `9000`, WebSocket ON

---

### Nextcloud AIO (self-hosted cloud storage)
```yaml
# ~/nextcloud-aio/docker-compose.yml
services:
  nextcloud-aio-mastercontainer:
    image: nextcloud/all-in-one:latest
    init: true
    restart: always
    container_name: nextcloud-aio-mastercontainer
    volumes:
      - nextcloud_aio_mastercontainer:/mnt/docker-aio-config
      - /var/run/docker.sock:/var/run/docker.sock:ro
    ports:
      - 8080:8080
    environment:
      - APACHE_PORT=11000
      - APACHE_IP_BINDING=0.0.0.0

volumes:
  nextcloud_aio_mastercontainer:
    name: nextcloud_aio_mastercontainer
```
**NPM proxy:** forward to `VPS_IP` port `11000` (not container name — AIO binds to host), WebSocket ON
**Manual step required:** visit `http://VPS_IP:8080` to complete initial setup
**Post-install fix:**
```bash
docker exec --user www-data nextcloud-aio-nextcloud \
  php occ config:system:set default_phone_region --value="US"
docker exec --user www-data nextcloud-aio-nextcloud \
  php occ maintenance:repair --include-expensive
```

---

## NPM Admin User — SQLite Seeding (Critical)

NPM v2 does not auto-create a default admin. Must seed manually after startup.

```bash
NPM_DB="$HOME/npm/data/database.sqlite"

# Wait for migrations to finish first
for i in {1..20}; do
  sudo sqlite3 "$NPM_DB" "SELECT COUNT(*) FROM user;" &>/dev/null && break
  sleep 3
done

NOW=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")
NPM_HASH=$(python3 -c "import bcrypt; print(bcrypt.hashpw(b'changeme', bcrypt.gensalt(10)).decode())")

sudo sqlite3 "$NPM_DB" \
  "INSERT INTO user (created_on,modified_on,is_deleted,email,name,nickname,avatar,roles,is_disabled)
   VALUES ('$NOW','$NOW',0,'admin@example.com','Administrator','Admin','','[\"admin\"]',0);"

USER_ID=$(sudo sqlite3 "$NPM_DB" "SELECT id FROM user WHERE email='admin@example.com';")

sudo sqlite3 "$NPM_DB" \
  "INSERT INTO auth (created_on,modified_on,is_deleted,user_id,type,secret,meta)
   VALUES ('$NOW','$NOW',0,$USER_ID,'password','$NPM_HASH','{}');"

# CRITICAL — without this, JWT has wrong scope and /users/1 returns 404
sudo sqlite3 "$NPM_DB" \
  "INSERT INTO user_permission (created_on,modified_on,user_id,visibility,proxy_hosts,redirection_hosts,dead_hosts,streams,access_lists,certificates)
   VALUES ('$NOW','$NOW',$USER_ID,'all','manage','manage','manage','manage','manage','manage');"
```

Then use the NPM API to update credentials:
```bash
# Get token
TOKEN=$(curl -sf -X POST http://localhost:81/api/tokens \
  -H "Content-Type: application/json" \
  -d '{"identity":"admin@example.com","secret":"changeme"}' | jq -r '.token')

# Update email
curl -sf -X PUT http://localhost:81/api/users/1 \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"email":"your@email.com","nickname":"Admin"}'

# Update password
curl -sf -X PUT http://localhost:81/api/users/1/auth \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"type":"password","current":"changeme","secret":"NEWPASSWORD"}'
```

---

## NPM API — Create a Proxy Host Automatically

```bash
TOKEN=$(curl -sf -X POST http://localhost:81/api/tokens \
  -H "Content-Type: application/json" \
  -d "{\"identity\":\"admin@example.com\",\"secret\":\"PASSWORD\"}" | jq -r '.token')

curl -sf -X POST http://localhost:81/api/nginx/proxy-hosts \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "domain_names": ["myservice.mydomain.com"],
    "forward_scheme": "http",
    "forward_host": "myservice",
    "forward_port": 8080,
    "allow_websocket_upgrade": true,
    "access_list_id": 0,
    "certificate_id": "new",
    "ssl_forced": true,
    "http2_support": true,
    "block_exploits": true,
    "meta": {
      "letsencrypt_email": "your@email.com",
      "letsencrypt_agree": true,
      "dns_challenge": false
    }
  }'
```

---

## Security Configuration

### UFW Firewall
```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 81/tcp
sudo ufw --force enable
```

### Fail2Ban (Docker-aware)
```bash
# /etc/fail2ban/action.d/docker-action.conf
# /etc/fail2ban/filter.d/npm-docker.conf
# /etc/fail2ban/jail.local
# All three are written by the installer — see vps-community-install.sh
```

Check status:
```bash
sudo fail2ban-client status
sudo fail2ban-client status sshd
```

---

## Day-to-Day VPS Commands

```bash
# See all running containers
docker ps

# See logs for a service
docker compose logs -f CONTAINER_NAME

# Restart a service
cd ~/SERVICE_FOLDER && docker compose restart

# Redeploy a service (pull latest image)
cd ~/SERVICE_FOLDER && docker compose pull && docker compose up -d

# Check which containers are on npm_default
docker network inspect npm_default --format '{{range .Containers}}{{.Name}}{{"\n"}}{{end}}'

# Connect a container to npm_default (fix for 502)
docker network connect npm_default CONTAINER_NAME

# Remove and redeploy (clean restart)
docker rm -f CONTAINER_NAME
cd ~/SERVICE_FOLDER && docker compose up -d

# Check a container's networks
docker inspect CONTAINER_NAME --format '{{json .NetworkSettings.Networks}}'

# Generate a random DB password
openssl rand -hex 16
```

---

## Template: Adding a New Service (Copy-Paste Starter)

```yaml
# ~/SERVICENAME/docker-compose.yml
services:
  SERVICENAME:
    image: DOCKER_IMAGE:latest
    container_name: SERVICENAME
    restart: unless-stopped
    expose:
      - "PORT"
    volumes:
      - ./data:/data
    environment:
      - KEY=VALUE
    networks:
      - npm_net

networks:
  npm_net:
    external: true
    name: npm_default
```

```bash
# Deploy
mkdir ~/SERVICENAME && cd ~/SERVICENAME
# paste docker-compose.yml above
docker compose up -d
docker compose logs -f SERVICENAME

# Then in NPM: add proxy host
# Domain:    SERVICENAME.mydomain.com
# Host:      SERVICENAME
# Port:      PORT
# WebSocket: ON
# SSL:       Let's Encrypt, Force SSL ON
```

---

## How to Use This Document With an AI

**Starting a new conversation to add a service:**

> "I have a self-hosted VPS homelab. I want to add [SERVICE] to my stack.
> My domain is [DOMAIN]. Here is my full system context:
> [paste this entire ARTIFACT.md file]
> Please follow the rules in my system prompt: [paste SYSTEM-PROMPT.md]"

**The AI now knows:**
- Your exact architecture
- Every service already running and their configs
- The Docker networking rules
- All the lessons learned and gotchas
- The exact template to follow for new services

---

## Changelog

| Date | Change |
|------|--------|
| Initial build | NPM + Nextcloud AIO + Vaultwarden + Immich + FileBrowser + Portainer deployed |
| | Add rows here as you add new services |
