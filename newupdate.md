Your Hostinger Self-Hosted VPS ArchitectureBelow is the visual map of how your server currently operates. 

It shows how traffic flows from the outside internet, through your security layers, into your proxy, and finally to your individual Docker containers.(Note: Most modern markdown viewers support Mermaid. 

If you copy/paste this code block below into a Mermaid Live Editor or GitHub, it will instantly generate the visual diagram!)

```mermaid
graph TD
    %% Define Styling
    classDef internet fill:#0ea5e9,stroke:#0284c7,stroke-width:2px,color:#fff
    classDef proxy fill:#f59e0b,stroke:#d97706,stroke-width:2px,color:#fff
    classDef app fill:#10b981,stroke:#059669,stroke-width:2px,color:#fff
    classDef db fill:#6366f1,stroke:#4f46e5,stroke-width:2px,color:#fff
    classDef security fill:#ef4444,stroke:#dc2626,stroke-width:2px,color:#fff

    User["👤 You (Web Browser / Phone Apps)"]:::internet
    DNS["🌐 Custom Domain DNS (ulyhome.cloud)"]:::internet

    subgraph Hostinger_VPS ["Hostinger Ubuntu VPS Engine"]
        UFW["🛡️ UFW Firewall\n(Ports 80, 443, 81, 22, 3478)"]:::security
        Fail2Ban["🚨 Fail2Ban\n(Brute Force Protection)"]:::security

        NPM["🔄 Nginx Proxy Manager\n(SSL Certificates & Routing)"]:::proxy

        subgraph Docker_Environment ["🐳 Secure Docker Network"]
            Nextcloud["☁️ Nextcloud AIO\nPort 11000"]:::app
            Vaultwarden["🔐 Vaultwarden\nPort 8222"]:::app
            Immich["📸 Immich\nPort 2283"]:::app
            Wealthfolio["📈 Wealthfolio\nPort 8088"]:::app
            Sure["💰 Sure Finance\nPort 3030"]:::app
            Firefox["🦊 Firefox Browser\nPort 5800"]:::app
            Linkwarden["🔖 Linkwarden\nPort 3040"]:::app
            Filebrowser["📁 Filebrowser Quantum\nPort 3010"]:::app

            NC_DB[("Nextcloud Data\nPostgres & Redis")]:::db
            Sure_DB[("Sure Data\nPostgres & Redis")]:::db
            Immich_DB[("Immich Data\nPostgres & Machine Learning")]:::db
            LW_DB[("Linkwarden Data\nPostgres 16")]:::db
        end
    end

    %% Traffic Flow
    User -->|"Types URL"| DNS
    DNS -->|"Resolves to VPS IP"| UFW
    Fail2Ban -.->|"Bans Bad IPs"| UFW
    UFW -->|"Port 443 (Secure HTTPS)"| NPM

    %% Proxy Routing
    NPM -->|"nc.ulyhome.cloud"| Nextcloud
    NPM -->|"vault.ulyhome.cloud"| Vaultwarden
    NPM -->|"pic.ulyhome.cloud"| Immich
    NPM -->|"wealth.ulyhome.cloud"| Wealthfolio
    NPM -->|"sure.ulyhome.cloud"| Sure
    NPM -->|"web.ulyhome.cloud"| Firefox
    NPM -->|"link.ulyhome.cloud"| Linkwarden
    NPM -->|"share.ulyhome.cloud"| Filebrowser

    %% Database Connections
    Nextcloud --- NC_DB
    Sure --- Sure_DB
    Immich --- Immich_DB
    Linkwarden --- LW_DB
```

🗺️ The Setup Timeline (How We Built It)If you ever need to rebuild this Hostinger server or reference how your applications are configured, here is the exact chronological order of your engineering, including the pivots we made along the way:Phase 1: The Foundation & SecurityProvisioned VPS: Spun up a fresh Ubuntu machine on Hostinger.UFW Firewall: Locked down the server so only specific doors are open (22, 80, 443, 81, 3478).Fail2Ban: Installed a security guard tailored for Docker that watches logs and permanently blocks any IP address exhibiting malicious behavior or scanning.Phase 2: The Core InfrastructureDocker: Installed the Docker engine to act as our containerized operating system.Nginx Proxy Manager (NPM): Deployed our "Traffic Cop" on ports 80 and 443. NPM catches all incoming traffic, checks the ulyhome.cloud subdomain, applies a free Let's Encrypt SSL certificate, and securely routes it to the right app.Phase 3: The Application LayerNextcloud AIO: Deployed the master container on port 8080, which then automatically downloaded and configured Apache, PostgreSQL, Redis, and Nextcloud Talk. Routed via nc.ulyhome.cloud on port 11000.Vaultwarden: Deployed the lightweight Rust port of Bitwarden, enabling Websockets for real-time syncing to browser extensions. Routed via vault.ulyhome.cloud on port 8222.Immich: Deployed the high-performance Google Photos replacement, complete with a dedicated Postgres database, Redis cache, and Machine Learning container for facial recognition. Routed via pic.ulyhome.cloud on port 2283.Wealthfolio: Deployed a fast, secure net-worth tracker, using Argon2 to cryptographically hash your login password. Routed via wealth.ulyhome.cloud on port 8088.Sure Finance: Downloaded official templates, injected a 64-character secret key, and successfully mapped/imported cleaned Gemini CSV data. Routed via sure.ulyhome.cloud on port 3030.Firefox Cloud Browser: Deployed a completely isolated browser running inside your server, secured with Nginx Proxy Manager's multi-user Access Lists to allow discrete logins. Routed via web.ulyhome.cloud on port 5800.Linkwarden: Deployed a robust bookmark manager with automated webpage archiving (PDF/screenshot backups). Booted alongside a dedicated Postgres 16 database and secured via NextAuth secret tokens. Routed via link.ulyhome.cloud on port 3040.Phase 4: App Migrations & AdjustmentsRemoved Pingvin Share: Originally deployed on share.ulyhome.cloud, but decided a root-level file manager was more useful.Attempted & Removed CryptPad: Attempted to deploy on pad.ulyhome.cloud. Hit extreme Docker permission barriers required by the app's zero-knowledge architecture. Decided to wipe it and pivot.Deployed FileBrowser Quantum: Deployed a blazing-fast web-based file manager fork with modern UI. Mapped the container directly to the host OS root directory (/) to provide full administrative file access via the web UI. Routed via share.ulyhome.cloud on port 3010.🛠️ The Automated Deployment ScriptsBelow are the exact bash scripts used to deploy the environment. You can deploy these by creating .sh files on your Ubuntu server, pasting the code below into them, and running them via bash filename.sh.1. Core Infrastructure & Nextcloud (The Master Script)Sets up System Updates, Docker, UFW Firewall, Fail2ban, Nginx Proxy Manager, and Nextcloud AIO.<details><summary><b>Click to expand <code>nc-master-install.sh</code></b></summary>#!/bin/bash

clear
echo "================================================================="
echo "   ULTIMATE NEXTCLOUD AIO + NPM + SECURITY INSTALLER             "
echo "================================================================="
echo ""
echo "Before we begin, I need some information about this VPS:"
read -p "1. Enter your VPS Public IP Address (e.g., 45.137.x.x): " VPS_IP
read -p "2. Enter your Custom Subdomain (e.g., nc.ulyhome.cloud): " DOMAIN
read -p "3. Enter your 2-letter Country Code (e.g., US, UK, DE): " COUNTRY_CODE
echo ""
echo "Thank you! Starting automated deployment for $DOMAIN..."
sleep 3

# ==========================================
# Phase 1: System Updates & Docker
# ==========================================
echo -e "\n---> [1/8] Updating System & Installing Docker..."
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install -y ca-certificates curl gnupg ufw fail2ban iptables
curl -fsSL [https://get.docker.com](https://get.docker.com) -o get-docker.sh
sudo sh get-docker.sh

# ==========================================
# Phase 2: Firewall Setup (UFW & Iptables)
# ==========================================
echo -e "\n---> [2/8] Configuring UFW Firewall and Iptables..."
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp      # SSH
sudo ufw allow 80/tcp      # HTTP
sudo ufw allow 443/tcp     # HTTPS
sudo ufw allow 81/tcp      # NPM Admin
sudo ufw allow 8080/tcp    # Nextcloud AIO Setup
sudo ufw allow 3478/tcp    # Nextcloud Talk (TCP)
sudo ufw allow 3478/udp    # Nextcloud Talk (UDP)
sudo ufw --force enable

sudo iptables -I INPUT -p tcp --dport 3478 -j ACCEPT
sudo iptables -I INPUT -p udp --dport 3478 -j ACCEPT

# ==========================================
# Phase 3: Nginx Proxy Manager (NPM)
# ==========================================
echo -e "\n---> [3/8] Deploying Nginx Proxy Manager..."
mkdir -p ~/npm && cd ~/npm

cat << EOF > docker-compose.yml
services:
  npm:
    image: 'jc21/nginx-proxy-manager:latest'
    container_name: npm
    restart: unless-stopped
    ports:
      - '80:80'
      - '81:81'
      - '443:443'
    volumes:
      - ./data:/data
      - ./letsencrypt:/etc/letsencrypt
EOF

sudo docker compose up -d

# ==========================================
# Phase 4: Pause for NPM Configuration
# ==========================================
echo ""
echo "=========================================================================="
echo " PAUSE 1: NGINX PROXY MANAGER & SSL SETUP                                 "
echo "=========================================================================="
echo "1. Go to: http://$VPS_IP:81"
echo "2. Log in with: admin@example.com / changeme"
echo "3. Add Let's Encrypt Cert for $DOMAIN using standard HTTP Challenge."
echo "   (Make sure your A Record for $DOMAIN points to $VPS_IP first!)"
echo "4. Create Proxy Host for $DOMAIN -> $VPS_IP:11000 (Enable Websockets)."
echo "=========================================================================="
read -p "Press [Enter] ONLY AFTER you have saved the Proxy Host..."

# ==========================================
# Phase 5: Nextcloud AIO Master Container
# ==========================================
echo -e "\n---> [5/8] Deploying Nextcloud AIO Master Container..."
mkdir -p ~/nextcloud-aio && cd ~/nextcloud-aio

cat << EOF > docker-compose.yml
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
EOF

sudo docker compose up -d

# ==========================================
# Phase 6: Pause for Nextcloud Web Setup
# ==========================================
echo ""
echo "=========================================================================="
echo " PAUSE 2: NEXTCLOUD AIO INITIALIZATION                                    "
echo "=========================================================================="
echo "1. Go to: https://$DOMAIN:8080"
echo "2. Enter your domain: $DOMAIN and start containers."
echo "CRITICAL: Wait until the screen says 'Initial setup is complete'."
echo "=========================================================================="
read -p "Press [Enter] ONLY AFTER Nextcloud is fully installed and running..."

# ==========================================
# Phase 7: Post-Install OCC Fixes
# ==========================================
echo -e "\n---> [7/8] Applying Nextcloud Region & Mimetype Fixes..."
sudo docker exec --user www-data nextcloud-aio-nextcloud php occ config:system:set default_phone_region --value="$COUNTRY_CODE"
sudo docker exec --user www-data nextcloud-aio-nextcloud php occ maintenance:repair --include-expensive

# ==========================================
# Phase 8: Fail2ban & Docker Security
# ==========================================
echo -e "\n---> [8/8] Configuring Docker-Aware Fail2ban..."

cat << 'EOF' | sudo tee /etc/fail2ban/action.d/docker-action.conf
[Definition]
actionstart = iptables -N f2b-<name>
              iptables -A f2b-<name> -j RETURN
              iptables -I INPUT -j f2b-<name>
              iptables -I DOCKER-USER -j f2b-<name>
actionstop = iptables -D DOCKER-USER -j f2b-<name>
             iptables -D INPUT -j f2b-<name>
             iptables -F f2b-<name>
             iptables -X f2b-<name>
actioncheck = iptables -n -L INPUT | grep -q 'f2b-<name>[ \t]'
actionban = iptables -I f2b-<name> 1 -s <ip> -j DROP
actionunban = iptables -D f2b-<name> -s <ip> -j DROP
EOF

cat << 'EOF' | sudo tee /etc/fail2ban/filter.d/npm-docker.conf
[Definition]
failregex = ^<HOST> .+ "(GET|POST|HEAD) .+ HTTP/.*" (400|401|403|404|444) .+$
ignoreregex =
EOF

cat << 'EOF' | sudo tee /etc/fail2ban/jail.local
[DEFAULT]
bantime = 86400
findtime = 600
maxretry = 3
banaction = docker-action

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3

[npm-docker]
enabled = true
port = http,https
filter = npm-docker
logpath = /root/npm/data/logs/proxy-host-*_access.log
maxretry = 15
EOF

sudo systemctl enable fail2ban
sudo systemctl restart fail2ban

echo "=========================================================================="
echo "                        INSTALLATION COMPLETE!                            "
echo "=========================================================================="
</details>2. Vaultwarden & ImmichDeploys the password manager and Google Photos alternative.<details><summary><b>Click to expand <code>install-extras.sh</code></b></summary>#!/bin/bash

echo "======================================================="
echo "   DEPLOYING VAULTWARDEN (Password Manager)            "
echo "======================================================="
mkdir -p ~/vaultwarden
cd ~/vaultwarden

# Create Vaultwarden docker-compose file
cat << 'EOF' > docker-compose.yml
services:
  vaultwarden:
    image: vaultwarden/server:latest
    container_name: vaultwarden
    restart: always
    environment:
      - WEBSOCKET_ENABLED=true # Required for live syncing to browser extensions
    volumes:
      - ./vw-data:/data
    ports:
      - "8222:80"
EOF

sudo docker compose up -d

echo ""
echo "======================================================="
echo "   DEPLOYING IMMICH (Self-Hosted Photo Backup)         "
echo "======================================================="
mkdir -p ~/immich
cd ~/immich

echo "Downloading official Immich configuration files..."
wget -q -O docker-compose.yml [https://github.com/immich-app/immich/releases/latest/download/docker-compose.yml](https://github.com/immich-app/immich/releases/latest/download/docker-compose.yml)
wget -q -O .env [https://github.com/immich-app/immich/releases/latest/download/example.env](https://github.com/immich-app/immich/releases/latest/download/example.env)

# Configure the .env file automatically
sed -i 's|UPLOAD_LOCATION=.*|UPLOAD_LOCATION=./immich-data|g' .env
DB_PASS=$(openssl rand -hex 16)
sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=$DB_PASS|g" .env
sed -i 's|TZ=Etc/UTC|TZ=America/Los_Angeles|g' .env

sudo docker compose up -d

echo ""
echo "======================================================="
echo "   EXTRA SERVICES ARE NOW RUNNING!                     "
echo "======================================================="
</details>3. WealthfolioAn alternative personal finance and net-worth tracker.<details><summary><b>Click to expand <code>install-wealthfolio.sh</code></b></summary>#!/bin/bash

clear
echo "======================================================="
echo "   DEPLOYING WEALTHFOLIO (Finance Tracker)             "
echo "======================================================="

# 1. Install argon2 if it's not already on the system
echo "Installing required hashing tools..."
sudo apt-get update -qq
sudo apt-get install -y argon2 -qq

# 2. Ask user for their desired login password
echo ""
read -s -p "Enter the password you want to use to log into Wealthfolio: " WF_PASS
echo ""
read -s -p "Confirm your password: " WF_PASS_CONFIRM
echo ""

if [ "$WF_PASS" != "$WF_PASS_CONFIRM" ]; then
    echo "Passwords do not match. Please run the script again."
    exit 1
fi

# 3. Generate the cryptographic keys
echo "Generating secure keys..."
SECRET_KEY=$(openssl rand -base64 32)
RAW_HASH=$(echo -n "$WF_PASS" | argon2 $(openssl rand -hex 8) -e)
SAFE_HASH=$(echo "$RAW_HASH" | sed 's/\$/\$\$/g')

# 4. Create the Docker Compose directory and file
echo "Creating Docker Compose configuration..."
mkdir -p ~/wealthfolio
cd ~/wealthfolio

cat << EOF > docker-compose.yml
services:
  wealthfolio:
    image: afadil/wealthfolio:latest
    container_name: wealthfolio
    restart: always
    environment:
      - WF_DB_PATH=/data/wealthfolio.db
      - WF_SECRET_KEY=$SECRET_KEY
      - WF_AUTH_PASSWORD_HASH=$SAFE_HASH
    ports:
      - "8088:8088"
    volumes:
      - ./wealthfolio-data:/data
EOF

# 5. Start the container
echo "Starting Wealthfolio container..."
sudo docker compose up -d

echo ""
echo "======================================================="
echo "   WEALTHFOLIO IS RUNNING ON PORT 8088                 "
echo "======================================================="
</details>4. Sure FinanceThe primary personal finance app.<details><summary><b>Click to expand <code>install-sure.sh</code></b></summary>#!/bin/bash

clear
echo "======================================================="
echo "   DEPLOYING SURE (Personal Finance Tool)              "
echo "======================================================="

mkdir -p ~/sure
cd ~/sure

# 1. Download official template files
echo "Downloading official Docker Compose and Environment files..."
curl -s -o compose.yml [https://raw.githubusercontent.com/we-promise/sure/main/compose.example.yml](https://raw.githubusercontent.com/we-promise/sure/main/compose.example.yml)
curl -s -o .env [https://raw.githubusercontent.com/we-promise/sure/main/.env.example](https://raw.githubusercontent.com/we-promise/sure/main/.env.example)

# 2. Generate secure keys
echo "Generating secure database password and application secret..."
DB_PASS=$(openssl rand -hex 24)
SECRET_KEY=$(openssl rand -hex 64)

# 3. Inject variables into the .env file
sed -i "s|^SECRET_KEY_BASE=.*|SECRET_KEY_BASE=\"$SECRET_KEY\"|g" .env
sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=\"$DB_PASS\"|g" .env

# 4. Modify the compose.yml for our Reverse Proxy Architecture
echo "Configuring SSL Proxy settings and Ports..."
sed -i 's|RAILS_ASSUME_SSL: "false"|RAILS_ASSUME_SSL: "true"|g' compose.yml

# We change the default host port from 3000 to 3030 to avoid conflicts
sed -i 's/3000:3000/3030:3000/g' compose.yml

# 5. Start the containers
echo "Pulling images and starting the Sure application..."
sudo docker compose up -d

echo ""
echo "======================================================="
echo "   SURE IS NOW BOOTING UP ON PORT 3030                 "
echo "======================================================="
</details>5. Docker Firefox (Multi-User Secured)A cloud-based Firefox browser completely isolated from your local machine.<details><summary><b>Click to expand <code>install-firefox.sh</code></b></summary>#!/bin/bash

clear
echo "======================================================="
echo "   DEPLOYING DOCKER FIREFOX (Browser in a Browser)     "
echo "======================================================="

mkdir -p ~/firefox
cd ~/firefox

# 1. Create Docker Compose configuration
echo "Creating Docker Compose configuration..."
cat << EOF > docker-compose.yml
services:
  firefox:
    image: jlesage/firefox:latest
    container_name: firefox
    restart: unless-stopped
    ports:
      - "5800:5800"
    environment:
      # Set to California time zone
      - TZ=America/Los_Angeles 
      - KEEP_APP_RUNNING=1
      # Enables a dark mode UI wrapper
      - DARK_MODE=1
      # Default resolution (can be resized in browser)
      - DISPLAY_WIDTH=1920
      - DISPLAY_HEIGHT=1080
    volumes:
      - ./firefox-data:/config:rw
EOF

# 2. Start the container
echo "Starting Docker Firefox container..."
sudo docker compose up -d

echo ""
echo "======================================================="
echo "   FIREFOX IS RUNNING ON PORT 5800                     "
echo "======================================================="
echo "To set up MULTI-USER authentication (Usernames & Passwords):"
echo "1. Log into Nginx Proxy Manager (:81)"
echo "2. Go to 'Access Lists' -> 'Add Access List'"
echo "3. Name it 'Firefox Users'"
echo "4. Go to the 'Authorization' tab and add your Usernames and Passwords."
echo "5. CRITICAL: Go to the 'Access' tab, click 'Add Rule', set it to 'allow', and type 'all'."
echo "6. Click Save."
echo ""
echo "Next Step: Secure it with the Proxy Host!"
echo "1. Create your Custom domain proxy (e.g., web.ulyhome.cloud)"
echo "2. Create a Proxy Host in NPM pointing to port 5800"
echo "3. Under the 'Details' tab, change 'Access List' to 'Firefox Users'"
echo "4. Ensure 'Websockets Support' is ENABLED"
echo "5. Ensure 'Block Common Exploits' is DISABLED (it can block the browser stream)"
echo "======================================================="
</details>6. LinkwardenAdvanced offline bookmark and webpage archive manager.<details><summary><b>Click to expand <code>install-linkwarden.sh</code></b></summary>#!/bin/bash

clear
echo "======================================================="
echo "   DEPLOYING LINKWARDEN (Advanced Bookmark Manager)    "
echo "======================================================="

mkdir -p ~/linkwarden
cd ~/linkwarden

# 1. Generate highly secure, randomized passwords automatically
echo "Generating secure database credentials and NextAuth secrets..."
DB_PASS=$(openssl rand -hex 16)
NEXTAUTH_SECRET=$(openssl rand -base64 32)

# 2. Create the Docker Compose configuration
echo "Creating Docker Compose configuration..."
cat << EOF > docker-compose.yml
services:
  postgres:
    image: postgres:16-alpine
    container_name: linkwarden-postgres
    restart: always
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=$DB_PASS
      - POSTGRES_DB=linkwarden
    volumes:
      - ./pgdata:/var/lib/postgresql/data

  linkwarden:
    image: ghcr.io/linkwarden/linkwarden:latest
    container_name: linkwarden
    restart: always
    environment:
      - DATABASE_URL=postgresql://postgres:$DB_PASS@postgres:5432/linkwarden
      - NEXTAUTH_URL=[https://link.ulyhome.cloud/api/v1/auth](https://link.ulyhome.cloud/api/v1/auth)
      - NEXTAUTH_SECRET=$NEXTAUTH_SECRET
    ports:
      - "3040:3000"
    depends_on:
      - postgres
    volumes:
      - ./data:/data/data
EOF

# 3. Start the containers
echo "Starting Linkwarden and Postgres containers..."
sudo docker compose up -d

echo ""
echo "======================================================="
echo "   LINKWARDEN IS NOW BOOTING UP!                       "
echo "======================================================="
echo "Linkwarden is listening internally on port: 3040"
</details>7. FileBrowser Quantum (Root Access)The modernized FileBrowser fork. Maps directly to your server root (/) for total administration control.<details><summary><b>Click to expand <code>install-filebrowser.sh</code></b></summary>#!/bin/bash

clear
echo "======================================================="
echo "   DEPLOYING FILEBROWSER QUANTUM (Root File Manager)   "
echo "======================================================="
echo "WARNING: This container will have access to your ENTIRE"
echo "Hostinger VPS root filesystem. Use a strong password!"
echo "======================================================="

# Since FileBrowser Quantum is a specialized fork, we need the exact image name
echo ""
echo "Please check [https://filebrowserquantum.com/en/](https://filebrowserquantum.com/en/) for the official"
echo "Docker image name (e.g., ghcr.io/username/filebrowser-quantum:latest)."
read -p "Enter the exact Docker image name: " FB_IMAGE

if [ -z "$FB_IMAGE" ]; then
    echo "Error: Image name cannot be empty. Aborting."
    exit 1
fi

mkdir -p ~/filebrowser
cd ~/filebrowser

# Clean up previous standard FileBrowser deployment
echo "Cleaning up any broken containers..."
sudo docker stop filebrowser 2>/dev/null || true
sudo docker rm filebrowser 2>/dev/null || true
sudo docker stop filebrowser-quantum 2>/dev/null || true
sudo docker rm filebrowser-quantum 2>/dev/null || true

# Wipe the old database to prevent Quantum schema conflicts
rm -f filebrowser.db settings.json docker-compose.yml

# Pre-create the database file so Docker doesn't 
# accidentally create it as a directory
touch filebrowser.db

# Create the Docker Compose configuration using the Quantum image
echo "Creating Docker Compose configuration..."
cat << EOF > docker-compose.yml
services:
  filebrowser:
    image: $FB_IMAGE
    container_name: filebrowser-quantum
    restart: unless-stopped
    # We must run this as root inside the container so it has 
    # permission to read/write to your host's root folders
    user: "0:0"
    ports:
      - "3010:80"
    volumes:
      # THE MAGIC LINE: Maps the Host OS Root to /srv inside Filebrowser
      - /:/srv
      # Map the database file for persistence
      - ./filebrowser.db:/database/filebrowser.db
    environment:
      - FB_DATABASE=/database/filebrowser.db
EOF

# Start the container
echo "Starting FileBrowser Quantum container..."
sudo docker compose up -d

echo ""
echo "======================================================="
echo "   FILEBROWSER QUANTUM IS NOW BOOTING UP!              "
echo "======================================================="
echo "FileBrowser Quantum is listening internally on port: 3010"
echo ""
echo "Next Step: Add it to Nginx Proxy Manager!"
echo "1. Go to your Nginx Proxy Manager dashboard (:81)"
echo "2. Edit your Proxy Host for: share.ulyhome.cloud"
echo "3. Forward it to port: 3010"
echo "4. Under 'Details', ensure 'Websockets Support' is ENABLED"
echo "5. Under 'SSL', ensure 'Force SSL' is ENABLED"
echo ""
echo "Once saved, visit [https://share.ulyhome.cloud](https://share.ulyhome.cloud)"
echo "Default Login: admin / admin"
echo "CRITICAL: Change your password immediately after logging in!"
echo "======================================================="
</details>🗑️ Teardown & Migration ScriptsOver the course of the project, we pivoted away from several apps. Keep these scripts on hand if you ever need to clean up resources or completely nuke the server environment.A. Remove Pingvin Share<details><summary><b>Click to expand <code>remove-pingvin.sh</code></b></summary>#!/bin/bash

clear
echo "======================================================="
echo "   REMOVING PINGVIN SHARE COMPLETELY                   "
echo "======================================================="

# Stop and remove the container
echo "Stopping Pingvin Share container..."
sudo docker stop pingvin-share 2>/dev/null || true

echo "Removing Pingvin Share container..."
sudo docker rm pingvin-share 2>/dev/null || true

# Clean up Docker volumes to ensure no hidden data is left behind
echo "Cleaning up orphaned Docker volumes..."
sudo docker volume prune -f 2>/dev/null || true

# Delete the physical folder and all files
echo "Wiping all Pingvin data and configuration files..."
cd ~
sudo rm -rf ~/pingvin

echo ""
echo "======================================================="
echo "   PINGVIN SHARE HAS BEEN COMPLETELY REMOVED           "
echo "======================================================="
</details>B. Remove CryptPad<details><summary><b>Click to expand <code>remove-cryptpad.sh</code></b></summary>#!/bin/bash

clear
echo "======================================================="
echo "   REMOVING CRYPTPAD COMPLETELY                        "
echo "======================================================="

# Stop and remove the container
echo "Stopping CryptPad container..."
sudo docker stop cryptpad 2>/dev/null || true

echo "Removing CryptPad container..."
sudo docker rm cryptpad 2>/dev/null || true

# Clean up Docker volumes to ensure no hidden data is left behind
echo "Cleaning up orphaned Docker volumes..."
sudo docker volume prune -f 2>/dev/null || true

# Delete the physical folder and all files
echo "Wiping all CryptPad data and configuration files..."
cd ~
sudo rm -rf ~/cryptpad

echo ""
echo "======================================================="
echo "   CRYPTPAD HAS BEEN COMPLETELY REMOVED                "
echo "======================================================="
</details>C. The Ultimate Cleanup "Nuke" ScriptSafely wipes your core Docker environment (Nextcloud/NPM) without reformatting the OS.<details><summary><b>Click to expand <code>nc-master-uninstall.sh</code></b></summary>#!/bin/bash

clear
echo "================================================================="
echo "   DANGER: TOTAL NEXTCLOUD & NPM ANNIHILATION SCRIPT             "
echo "================================================================="
echo "This script will PERMANENTLY DELETE:"
echo " - All Nextcloud AIO containers and data"
echo " - Nginx Proxy Manager (NPM) containers and data"
echo " - All unused Docker Volumes and Images"
echo " - The custom Fail2ban security configurations"
echo " - The ~/npm and ~/nextcloud-aio directories"
echo "================================================================="
read -p "Are you ABSOLUTELY sure you want to wipe everything? (Type YES to continue): " CONFIRM

if [ "$CONFIRM" != "YES" ]; then
    echo "Aborting. Nothing was deleted."
    exit 1
fi

echo -e "\n---> [1/5] Stopping Nextcloud and NPM Containers..."
sudo docker stop $(sudo docker ps -a -q --filter name=nextcloud --filter name=npm) 2>/dev/null || true

echo -e "\n---> [2/5] Removing Containers and Networks..."
sudo docker rm $(sudo docker ps -a -q --filter name=nextcloud --filter name=npm) 2>/dev/null || true
sudo docker container prune -f
sudo docker network rm nextcloud-aio 2>/dev/null || true

echo -e "\n---> [3/5] Nuking Docker Volumes and Images..."
sudo docker volume prune -f --filter all=1
sudo docker image prune -a -f

echo -e "\n---> [4/5] Deleting Physical Data Directories..."
sudo rm -rf ~/npm
sudo rm -rf ~/nextcloud-aio

echo -e "\n---> [5/5] Reverting Fail2ban Security Configs..."
sudo rm -f /etc/fail2ban/action.d/docker-action.conf
sudo rm -f /etc/fail2ban/filter.d/npm-docker.conf
sudo rm -f /etc/fail2ban/jail.local
sudo systemctl restart fail2ban 2>/dev/null || true

echo ""
echo "================================================================="
echo "   CLEANUP COMPLETE!                                             "
echo "================================================================="
</details>
