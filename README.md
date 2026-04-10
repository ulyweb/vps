# vps



## Do not forget to add this ports

````firewall
# 1. Remove the manual iptables rules
sudo iptables -D INPUT -p tcp --dport 3478 -j ACCEPT
sudo iptables -D INPUT -p udp --dport 3478 -j ACCEPT

# 2. Reset UFW to wipe all previous configurations
sudo ufw --force reset

# 3. Set the default baseline rules
sudo ufw default deny incoming
sudo ufw default allow outgoing

# 4. Allow SSH (Do not skip this!)
sudo ufw allow 22/tcp

# 5. Allow Web, Proxy Admin, and Nextcloud Talk
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 81/tcp
sudo ufw allow 3478/tcp
sudo ufw allow 3478/udp

# 6. Enable and verify
sudo ufw enable
sudo ufw status verbose
````
