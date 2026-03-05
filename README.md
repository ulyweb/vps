# vps



## Do not forget to add this ports

````
sudo iptables -I INPUT -p tcp --dport 3478 -j ACCEPT
sudo iptables -I INPUT -p udp --dport 3478 -j ACCEPT
sudo ufw status
sudo ufw allow 3478/tcp
sudo ufw allow 3478/udp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 81/tcp
sudo ufw allow 22/tcp
sudo ufw 
sudo ufw enable
sudo ufw reload
````
