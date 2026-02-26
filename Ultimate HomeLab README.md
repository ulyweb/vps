# **🚀 Self-Hosted VPS HomeLab Architecture**

Welcome to my complete self-hosted ecosystem\! This repository contains the architecture, automated deployment scripts, and troubleshooting documentation for a secure, containerized VPS that replaces Google Drive, Google Photos, Bitwarden, Mint/Simplifi, and provides an isolated cloud browser.

## **🗺️ Architecture Diagram**

Below is the visual map of how the server operates, showing traffic flow from the outside internet, through the security layers and Nginx Proxy Manager, down to the individual Docker containers.

```mermaid
graph TD  
    %% Define Styling  
    classDef internet fill:\#0ea5e9,stroke:\#0284c7,stroke-width:2px,color:\#fff  
    classDef proxy fill:\#f59e0b,stroke:\#d97706,stroke-width:2px,color:\#fff  
    classDef app fill:\#10b981,stroke:\#059669,stroke-width:2px,color:\#fff  
    classDef db fill:\#6366f1,stroke:\#4f46e5,stroke-width:2px,color:\#fff  
    classDef security fill:\#ef4444,stroke:\#dc2626,stroke-width:2px,color:\#fff

    User\["👤 You (Web Browser / Phone Apps)"\]:::internet  
    DuckDNS\["🌐 DuckDNS (Domain Resolution)"\]:::internet

    subgraph Contabo\_VPS \["Contabo Ubuntu VPS Engine"\]  
        UFW\["🛡️ UFW Firewall\\n(Ports 80, 443, 81, 22, 3478)"\]:::security  
        Fail2Ban\["🚨 Fail2Ban\\n(Brute Force Protection)"\]:::security

        NPM\["🔄 Nginx Proxy Manager\\n(SSL Certificates & Routing)"\]:::proxy

        subgraph Docker\_Environment \["🐳 Secure Docker Network"\]  
            Nextcloud\["☁️ Nextcloud AIO\\nPort 11000"\]:::app  
            Vaultwarden\["🔐 Vaultwarden\\nPort 8222"\]:::app  
            Immich\["📸 Immich\\nPort 2283"\]:::app  
            Wealthfolio\["📈 Wealthfolio\\nPort 8088"\]:::app  
            Sure\["💰 Sure Finance\\nPort 3000"\]:::app  
            Firefox\["🦊 Firefox (Cloud Browser)\\nPort 5800"\]:::app

            NC\_DB\[("Nextcloud Data\\nPostgres & Redis")\]:::db  
            Sure\_DB\[("Sure Data\\nPostgres & Redis")\]:::db  
            Immich\_DB\[("Immich Data\\nPostgres & Machine Learning")\]:::db  
        end  
    end

    %% Traffic Flow  
    User \--\>|"Types URL"| DuckDNS  
    DuckDNS \--\>|"Resolves to VPS IP"| UFW  
    Fail2Ban \-.-\>|"Bans Bad IPs"| UFW  
    UFW \--\>|"Port 443 (Secure HTTPS)"| NPM

    %% Proxy Routing  
    NPM \--\>|"cloudvps.duckdns.org"| Nextcloud  
    NPM \--\>|"vaultvps.duckdns.org"| Vaultwarden  
    NPM \--\>|"picvps.duckdns.org"| Immich  
    NPM \--\>|"wealthvps.duckdns.org"| Wealthfolio  
    NPM \--\>|"surevps.duckdns.org"| Sure  
    NPM \--\>|"webvps.duckdns.org"| Firefox

    %% Database Connections  
    Nextcloud \--- NC\_DB  
    Sure \--- Sure\_DB  
    Immich \--- Immich\_DB
```

## **🛠️ The Setup Timeline & Automated Scripts**

This environment is built in sequential phases. You can deploy these by creating .sh files on your Ubuntu server, pasting the code below into them, and running them via bash filename.sh.

### **Phase 1: Core Infrastructure & Nextcloud (The Master Script)**

*Sets up System Updates, Docker, UFW Firewall, Fail2ban, Nginx Proxy Manager, and Nextcloud AIO.*

* **Script Name:** nc-master-install.sh

\<details\>

\<summary\>\<b\>Click to expand the full \<code\>nc-master-install.sh\</code\> code\</b\>\</summary\>

\#\!/bin/bash

clear  
echo "================================================================="  
echo "   ULTIMATE NEXTCLOUD AIO \+ NPM \+ SECURITY INSTALLER             "  
echo "================================================================="  
echo ""  
echo "Before we begin, I need some information about this VPS:"  
read \-p "1. Enter your VPS Public IP Address (e.g., 45.137.x.x): " VPS\_IP  
read \-p "2. Enter your DuckDNS Subdomain (e.g., myname.duckdns.org): " DOMAIN  
read \-p "3. Enter your DuckDNS Token: " DUCK\_TOKEN  
read \-p "4. Enter your 2-letter Country Code (e.g., US, UK, DE): " COUNTRY\_CODE  
echo ""  
echo "Thank you\! Starting automated deployment for $DOMAIN..."  
sleep 3

\# \==========================================  
\# Phase 1: System Updates & Docker  
\# \==========================================  
echo \-e "\\n---\> \[1/8\] Updating System & Installing Docker..."  
export DEBIAN\_FRONTEND=noninteractive  
sudo apt-get update && sudo apt-get upgrade \-y  
sudo apt-get install \-y ca-certificates curl gnupg ufw fail2ban iptables  
curl \-fsSL \[https://get.docker.com\](https://get.docker.com) \-o get-docker.sh  
sudo sh get-docker.sh

\# \==========================================  
\# Phase 2: Firewall Setup (UFW & Iptables)  
\# \==========================================  
echo \-e "\\n---\> \[2/8\] Configuring UFW Firewall and Iptables..."  
sudo ufw default deny incoming  
sudo ufw default allow outgoing  
sudo ufw allow 22/tcp      \# SSH  
sudo ufw allow 80/tcp      \# HTTP  
sudo ufw allow 443/tcp     \# HTTPS  
sudo ufw allow 81/tcp      \# NPM Admin  
sudo ufw allow 8080/tcp    \# Nextcloud AIO Setup  
sudo ufw allow 3478/tcp    \# Nextcloud Talk (TCP)  
sudo ufw allow 3478/udp    \# Nextcloud Talk (UDP)  
sudo ufw \--force enable

sudo iptables \-I INPUT \-p tcp \--dport 3478 \-j ACCEPT  
sudo iptables \-I INPUT \-p udp \--dport 3478 \-j ACCEPT

\# \==========================================  
\# Phase 3: Nginx Proxy Manager (NPM)  
\# \==========================================  
echo \-e "\\n---\> \[3/8\] Deploying Nginx Proxy Manager..."  
mkdir \-p \~/npm && cd \~/npm

cat \<\< EOF \> docker-compose.yml  
services:  
  npm:  
    image: 'jc21/nginx-proxy-manager:latest'  
    container\_name: npm  
    restart: unless-stopped  
    ports:  
      \- '80:80'  
      \- '81:81'  
      \- '443:443'  
    volumes:  
      \- ./data:/data  
      \- ./letsencrypt:/etc/letsencrypt  
EOF

sudo docker compose up \-d

\# \==========================================  
\# Phase 4: Pause for NPM Configuration  
\# \==========================================  
echo ""  
echo "=========================================================================="  
echo " PAUSE 1: NGINX PROXY MANAGER & SSL SETUP                                 "  
echo "=========================================================================="  
echo "1. Go to: http://$VPS\_IP:81"  
echo "2. Log in with: admin@example.com / changeme"  
echo "3. Add Let's Encrypt Cert for $DOMAIN using DuckDNS DNS Challenge."  
echo "4. Create Proxy Host for $DOMAIN \-\> $VPS\_IP:11000 (Enable Websockets)."  
echo "=========================================================================="  
read \-p "Press \[Enter\] ONLY AFTER you have saved the Proxy Host..."

\# \==========================================  
\# Phase 5: Nextcloud AIO Master Container  
\# \==========================================  
echo \-e "\\n---\> \[5/8\] Deploying Nextcloud AIO Master Container..."  
mkdir \-p \~/nextcloud-aio && cd \~/nextcloud-aio

cat \<\< EOF \> docker-compose.yml  
services:  
  nextcloud-aio-mastercontainer:  
    image: nextcloud/all-in-one:latest  
    init: true  
    restart: always  
    container\_name: nextcloud-aio-mastercontainer  
    volumes:  
      \- nextcloud\_aio\_mastercontainer:/mnt/docker-aio-config  
      \- /var/run/docker.sock:/var/run/docker.sock:ro  
    ports:  
      \- 8080:8080  
    environment:  
      \- APACHE\_PORT=11000  
      \- APACHE\_IP\_BINDING=0.0.0.0  
volumes:  
  nextcloud\_aio\_mastercontainer:  
    name: nextcloud\_aio\_mastercontainer  
EOF

sudo docker compose up \-d

\# \==========================================  
\# Phase 6: Pause for Nextcloud Web Setup  
\# \==========================================  
echo ""  
echo "=========================================================================="  
echo " PAUSE 2: NEXTCLOUD AIO INITIALIZATION                                    "  
echo "=========================================================================="  
echo "1. Go to: https://$DOMAIN:8080"  
echo "2. Enter your domain: $DOMAIN and start containers."  
echo "CRITICAL: Wait until the screen says 'Initial setup is complete'."  
echo "=========================================================================="  
read \-p "Press \[Enter\] ONLY AFTER Nextcloud is fully installed and running..."

\# \==========================================  
\# Phase 7: Post-Install OCC Fixes  
\# \==========================================  
echo \-e "\\n---\> \[7/8\] Applying Nextcloud Region & Mimetype Fixes..."  
sudo docker exec \--user www-data nextcloud-aio-nextcloud php occ config:system:set default\_phone\_region \--value="$COUNTRY\_CODE"  
sudo docker exec \--user www-data nextcloud-aio-nextcloud php occ maintenance:repair \--include-expensive

\# \==========================================  
\# Phase 8: Fail2ban & Docker Security  
\# \==========================================  
echo \-e "\\n---\> \[8/8\] Configuring Docker-Aware Fail2ban..."

cat \<\< 'EOF' | sudo tee /etc/fail2ban/action.d/docker-action.conf  
\[Definition\]  
actionstart \= iptables \-N f2b-\<name\>  
              iptables \-A f2b-\<name\> \-j RETURN  
              iptables \-I INPUT \-j f2b-\<name\>  
              iptables \-I DOCKER-USER \-j f2b-\<name\>  
actionstop \= iptables \-D DOCKER-USER \-j f2b-\<name\>  
             iptables \-D INPUT \-j f2b-\<name\>  
             iptables \-F f2b-\<name\>  
             iptables \-X f2b-\<name\>  
actioncheck \= iptables \-n \-L INPUT | grep \-q 'f2b-\<name\>\[ \\t\]'  
actionban \= iptables \-I f2b-\<name\> 1 \-s \<ip\> \-j DROP  
actionunban \= iptables \-D f2b-\<name\> \-s \<ip\> \-j DROP  
EOF

cat \<\< 'EOF' | sudo tee /etc/fail2ban/filter.d/npm-docker.conf  
\[Definition\]  
failregex \= ^\<HOST\> .+ "(GET|POST|HEAD) .+ HTTP/.\*" (400|401|403|404|444) .+$  
ignoreregex \=  
EOF

cat \<\< 'EOF' | sudo tee /etc/fail2ban/jail.local  
\[DEFAULT\]  
bantime \= 86400  
findtime \= 600  
maxretry \= 3  
banaction \= docker-action

\[sshd\]  
enabled \= true  
port \= ssh  
filter \= sshd  
logpath \= /var/log/auth.log  
maxretry \= 3

\[npm-docker\]  
enabled \= true  
port \= http,https  
filter \= npm-docker  
logpath \= /root/npm/data/logs/proxy-host-\*\_access.log  
maxretry \= 15  
EOF

sudo systemctl enable fail2ban  
sudo systemctl restart fail2ban

echo "=========================================================================="  
echo "                        INSTALLATION COMPLETE\!                            "  
echo "=========================================================================="

\</details\>

### **Phase 2: Deploying Vaultwarden & Immich**

*Deploys the password manager and Google Photos alternative.*

* **Script Name:** install-extras.sh

\<details\>

\<summary\>\<b\>Click to expand the full \<code\>install-extras.sh\</code\> code\</b\>\</summary\>

\#\!/bin/bash

echo "======================================================="  
echo "   DEPLOYING VAULTWARDEN (Password Manager)            "  
echo "======================================================="  
mkdir \-p \~/vaultwarden  
cd \~/vaultwarden

\# Create Vaultwarden docker-compose file  
cat \<\< 'EOF' \> docker-compose.yml  
services:  
  vaultwarden:  
    image: vaultwarden/server:latest  
    container\_name: vaultwarden  
    restart: always  
    environment:  
      \- WEBSOCKET\_ENABLED=true \# Required for live syncing to browser extensions  
    volumes:  
      \- ./vw-data:/data  
    ports:  
      \- "8222:80"  
EOF

sudo docker compose up \-d

echo ""  
echo "======================================================="  
echo "   DEPLOYING IMMICH (Self-Hosted Photo Backup)         "  
echo "======================================================="  
mkdir \-p \~/immich  
cd \~/immich

echo "Downloading official Immich configuration files..."  
wget \-q \-O docker-compose.yml \[https://github.com/immich-app/immich/releases/latest/download/docker-compose.yml\](https://github.com/immich-app/immich/releases/latest/download/docker-compose.yml)  
wget \-q \-O .env \[https://github.com/immich-app/immich/releases/latest/download/example.env\](https://github.com/immich-app/immich/releases/latest/download/example.env)

\# Configure the .env file automatically  
sed \-i 's|UPLOAD\_LOCATION=.\*|UPLOAD\_LOCATION=./immich-data|g' .env  
DB\_PASS=$(openssl rand \-hex 16\)  
sed \-i "s|DB\_PASSWORD=.\*|DB\_PASSWORD=$DB\_PASS|g" .env  
sed \-i 's|TZ=Etc/UTC|TZ=America/Los\_Angeles|g' .env

sudo docker compose up \-d

echo ""  
echo "======================================================="  
echo "   EXTRA SERVICES ARE NOW RUNNING\!                     "  
echo "======================================================="

\</details\>

### **Phase 3A: Deploying Wealthfolio**

*An alternative personal finance and net-worth tracker.*

* **Script Name:** install-wealthfolio.sh

\<details\>

\<summary\>\<b\>Click to expand the full \<code\>install-wealthfolio.sh\</code\> code\</b\>\</summary\>

\#\!/bin/bash

clear  
echo "======================================================="  
echo "   DEPLOYING WEALTHFOLIO (Finance Tracker)             "  
echo "======================================================="

\# 1\. Install argon2 if it's not already on the system  
echo "Installing required hashing tools..."  
sudo apt-get update \-qq  
sudo apt-get install \-y argon2 \-qq

\# 2\. Ask user for their desired login password  
echo ""  
read \-s \-p "Enter the password you want to use to log into Wealthfolio: " WF\_PASS  
echo ""  
read \-s \-p "Confirm your password: " WF\_PASS\_CONFIRM  
echo ""

if \[ "$WF\_PASS" \!= "$WF\_PASS\_CONFIRM" \]; then  
    echo "Passwords do not match. Please run the script again."  
    exit 1  
fi

\# 3\. Generate the cryptographic keys  
echo "Generating secure keys..."  
SECRET\_KEY=$(openssl rand \-base64 32\)  
RAW\_HASH=$(echo \-n "$WF\_PASS" | argon2 $(openssl rand \-hex 8\) \-e)  
SAFE\_HASH=$(echo "$RAW\_HASH" | sed 's/\\$/\\$\\$/g')

\# 4\. Create the Docker Compose directory and file  
echo "Creating Docker Compose configuration..."  
mkdir \-p \~/wealthfolio  
cd \~/wealthfolio

cat \<\< EOF \> docker-compose.yml  
services:  
  wealthfolio:  
    image: afadil/wealthfolio:latest  
    container\_name: wealthfolio  
    restart: always  
    environment:  
      \- WF\_DB\_PATH=/data/wealthfolio.db  
      \- WF\_SECRET\_KEY=$SECRET\_KEY  
      \- WF\_AUTH\_PASSWORD\_HASH=$SAFE\_HASH  
    ports:  
      \- "8088:8088"  
    volumes:  
      \- ./wealthfolio-data:/data  
EOF

\# 5\. Start the container  
echo "Starting Wealthfolio container..."  
sudo docker compose up \-d

echo ""  
echo "======================================================="  
echo "   WEALTHFOLIO IS RUNNING ON PORT 8088                 "  
echo "======================================================="

\</details\>

### **Phase 3B: Deploying Sure Finance**

*The primary personal finance app (a fork of Maybe Finance).*

* **Script Name:** install-sure.sh

\<details\>

\<summary\>\<b\>Click to expand the full \<code\>install-sure.sh\</code\> code\</b\>\</summary\>

\#\!/bin/bash

clear  
echo "======================================================="  
echo "   DEPLOYING SURE (Personal Finance Tool)              "  
echo "======================================================="

mkdir \-p \~/sure  
cd \~/sure

\# 1\. Download official template files  
echo "Downloading official Docker Compose and Environment files..."  
curl \-s \-o compose.yml \[https://raw.githubusercontent.com/we-promise/sure/main/compose.example.yml\](https://raw.githubusercontent.com/we-promise/sure/main/compose.example.yml)  
curl \-s \-o .env \[https://raw.githubusercontent.com/we-promise/sure/main/.env.example\](https://raw.githubusercontent.com/we-promise/sure/main/.env.example)

\# 2\. Generate secure keys  
echo "Generating secure database password and application secret..."  
DB\_PASS=$(openssl rand \-hex 24\)  
SECRET\_KEY=$(openssl rand \-hex 64\)

\# 3\. Inject variables into the .env file  
sed \-i "s|^SECRET\_KEY\_BASE=.\*|SECRET\_KEY\_BASE=\\"$SECRET\_KEY\\"|g" .env  
sed \-i "s|^POSTGRES\_PASSWORD=.\*|POSTGRES\_PASSWORD=\\"$DB\_PASS\\"|g" .env

\# 4\. Modify the compose.yml for our Reverse Proxy Architecture  
echo "Configuring SSL Proxy settings and Ports..."  
sed \-i 's|RAILS\_ASSUME\_SSL: "false"|RAILS\_ASSUME\_SSL: "true"|g' compose.yml

\# We change the default host port from 3000 to 3030 to avoid conflicts  
\# Bulletproof port replacement regex:  
sed \-i 's/3000:3000/3030:3000/g' compose.yml

\# 5\. Start the containers  
echo "Pulling images and starting the Sure application..."  
sudo docker compose up \-d

echo ""  
echo "======================================================="  
echo "   SURE IS NOW BOOTING UP ON PORT 3030                 "  
echo "======================================================="

\</details\>

### **Phase 3C: Deploying Docker Firefox**

*A cloud-based Firefox browser you can access securely via a web GUI, completely isolated from your local machine.*

* **Script Name:** install-firefox.sh

\<details\>

\<summary\>\<b\>Click to expand the full \<code\>install-firefox.sh\</code\> code\</b\>\</summary\>

\#\!/bin/bash

clear  
echo "======================================================="  
echo "   DEPLOYING DOCKER FIREFOX (Browser in a Browser)     "  
echo "======================================================="

mkdir \-p \~/firefox  
cd \~/firefox

\# 1\. Create Docker Compose configuration  
echo "Creating Docker Compose configuration..."  
cat \<\< EOF \> docker-compose.yml  
services:  
  firefox:  
    image: jlesage/firefox:latest  
    container\_name: firefox  
    restart: unless-stopped  
    ports:  
      \- "5800:5800"  
    environment:  
      \# Set to California time zone  
      \- TZ=America/Los\_Angeles   
      \- KEEP\_APP\_RUNNING=1  
      \# Enables a dark mode UI wrapper  
      \- DARK\_MODE=1  
      \# Default resolution (can be resized in browser)  
      \- DISPLAY\_WIDTH=1920  
      \- DISPLAY\_HEIGHT=1080  
    volumes:  
      \- ./firefox-data:/config:rw  
EOF

\# 2\. Start the container  
echo "Starting Docker Firefox container..."  
sudo docker compose up \-d

echo ""  
echo "======================================================="  
echo "   FIREFOX IS RUNNING ON PORT 5800                     "  
echo "======================================================="  
echo "Next Step: Add it to Nginx Proxy Manager\!"  
echo "1. Create your DuckDNS domain: webvps.duckdns.org"  
echo "2. Create a Proxy Host in NPM pointing to port 5800"  
echo "3. Ensure 'Websockets Support' is ENABLED in NPM"  
echo "======================================================="

\</details\>

### **Phase 4: The "Nuke" Teardown Script**

*A dedicated uninstaller for testing environments that safely wipes all Docker containers, networks, volumes, and Fail2ban configs without formatting the OS.*

* **Script Name:** nc-master-uninstall.sh

\<details\>

\<summary\>\<b\>Click to expand the full \<code\>nc-master-uninstall.sh\</code\> code\</b\>\</summary\>

\#\!/bin/bash

clear  
echo "================================================================="  
echo "   DANGER: TOTAL NEXTCLOUD & NPM ANNIHILATION SCRIPT             "  
echo "================================================================="  
echo "This script will PERMANENTLY DELETE:"  
echo " \- All Nextcloud AIO containers and data"  
echo " \- Nginx Proxy Manager (NPM) containers and data"  
echo " \- All unused Docker Volumes and Images"  
echo " \- The custom Fail2ban security configurations"  
echo " \- The \~/npm and \~/nextcloud-aio directories"  
echo "================================================================="  
read \-p "Are you ABSOLUTELY sure you want to wipe everything? (Type YES to continue): " CONFIRM

if \[ "$CONFIRM" \!= "YES" \]; then  
    echo "Aborting. Nothing was deleted."  
    exit 1  
fi

echo \-e "\\n---\> \[1/5\] Stopping Nextcloud and NPM Containers..."  
sudo docker stop $(sudo docker ps \-a \-q \--filter name=nextcloud \--filter name=npm) 2\>/dev/null || true

echo \-e "\\n---\> \[2/5\] Removing Containers and Networks..."  
sudo docker rm $(sudo docker ps \-a \-q \--filter name=nextcloud \--filter name=npm) 2\>/dev/null || true  
sudo docker container prune \-f  
sudo docker network rm nextcloud-aio 2\>/dev/null || true

echo \-e "\\n---\> \[3/5\] Nuking Docker Volumes and Images..."  
sudo docker volume prune \-f \--filter all=1  
sudo docker image prune \-a \-f

echo \-e "\\n---\> \[4/5\] Deleting Physical Data Directories..."  
sudo rm \-rf \~/npm  
sudo rm \-rf \~/nextcloud-aio

echo \-e "\\n---\> \[5/5\] Reverting Fail2ban Security Configs..."  
sudo rm \-f /etc/fail2ban/action.d/docker-action.conf  
sudo rm \-f /etc/fail2ban/filter.d/npm-docker.conf  
sudo rm \-f /etc/fail2ban/jail.local  
sudo systemctl restart fail2ban 2\>/dev/null || true

echo ""  
echo "================================================================="  
echo "   CLEANUP COMPLETE\!                                             "  
echo "================================================================="

\</details\>

## **⚠️ Troubleshooting & Engineering Gotchas**

During the build process, we encountered several technical hurdles. Here is exactly how we resolved them.

### **1\. Downloading scripts via scp fails with zsh: no matches found**

* **The Issue:** Attempting to download files via SSH using wildcards (scp root@IP:/root/\*.sh ./) failed because the local zsh terminal tried to find \*.sh on the *local* machine before sending the command. Also, scp cannot be run from *inside* the active SSH session.  
* **The Fix:** Open a **new local terminal tab** (do not SSH in). Wrap the remote path in quotes to bypass local zsh wildcard expansion:  
  scp "root@YOUR\_IP:/root/\*.sh" /home/local\_user/target\_folder/

### **2\. Vaultwarden / Wealthfolio Hashing (Docker Compose variable quirks)**

* **The Issue:** Putting a plain text admin password in docker-compose.yml is insecure. We generated Argon2 hashes for Vaultwarden and Wealthfolio to fix this.  
* **The Fix:** Because the generated hash contains $ symbols, Docker treats them as variables and breaks the hash. Every $ in the generated hash must be manually replaced with $$ inside the docker-compose.yml file (which is handled automatically in our shell scripts using sed).

### **3\. Sure Finance: sed Port Replacement Failure**

* **The Issue:** Our automated script originally tried to remap Sure from port 3000 to 3030 using sed \-i 's|- "3000:3000"|- "3030:3000"|g'. It silently failed because the official compose file was written *without* quotes (- 3000:3000).  
* **The Fix:** Made the regex bulletproof by stripping the quote requirements: sed \-i 's/3000:3000/3030:3000/g' compose.yml.

### **4\. Sure Finance: Importing Gemini CSV Transactions Failed**

* **The Issue:** The app crashed when importing a credit card transaction CSV from Gemini. The database schema in Sure requires specific fields, and Gemini leaves payment names completely blank and inverts purchase logic.  
* **The Fix:** 1\. **Pre-clean the CSV:** Open in Excel, find the blank Description of Transaction cells (which are payments), and manually type "Credit Card Payment". Sure will crash on blank names.  
  2\. **Mapping:** Ignore everything except the bare essentials:  
  * Transaction Post Date \-\> **Date**  
  * Description \-\> **Name**  
  * Amount \-\> **Amount**  
  * *Set all other columns to "Ignore".*  
  3. **Invert Logic:** Because Gemini exports purchases as positive numbers, we MUST check the **"Invert Amounts"** box on the final review screen so purchases become negative (money leaving).

### **5\. Nextcloud AIO: Logging Exceptions (QueryNotFoundException)**

* **The Issue:** Nextcloud logs spammed with Could not resolve OCA\\AppAPI... and OCA\\Circles....  
* **The Fix:** The background cron job queued tasks for apps before they were fully initialized during setup. We cleared these orphaned jobs manually via the occ CLI:  
  sudo docker exec \--user www-data nextcloud-aio-nextcloud php occ background-job:delete 'OCA\\AppAPI\\BackgroundJob\\ExAppInitStatusCheckJob'

### **6\. Nextcloud AIO: Constant IMAP Undefined array key "id" Warnings**

* **The Issue:** The built-in Mail app's Horde IMAP client threw constant warnings when trying to sync an external inbox because the email provider sent unexpected response headers.  
* **The Fix:** If not using Nextcloud as a daily email client, simply navigate to Apps \-\> Mail and click **Disable**. This instantly silences the warnings and cleans up the logs.

### **7\. Docker Firefox: Blank screen / Disconnecting**

* **The Issue:** The container loads but the screen is entirely blank or instantly disconnects when routed through NPM.  
* **The Fix:** The Web VNC protocol heavily relies on WebSockets to stream the screen data. You **must** toggle on "Websockets Support" inside the Nginx Proxy Manager configuration for your Firefox proxy host.
