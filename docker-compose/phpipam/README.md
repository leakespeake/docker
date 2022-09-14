# PHP-IPAM

PHP-IPAM is an open-source web IP address management application (IPAM). Its goal is to provide light, modern and useful IP address management. It is a php-based application with a MySQL database backend (MariaDB). The full set of features are listed here;

https://phpipam.net/

This docker-compose project includes the standalone PHP-IPAM stack but I have also added an additional container to perform automated MySQL database backups;

https://hub.docker.com/r/databack/mysql-backup

**GETTING STARTED**

SSH to your intended host VM, then run the following;

```
mkdir ~/docker-compose
mkdir ~/docker-compose/php-ipam
cd ~/docker-compose/php-ipam
nano docker-compose.yml				
nano .env
```
Remember to change the values in .env to REDACTED prior to checking into source control. Note that these variables influence the settings in **config.dist.php**

With both our Compose file (docker-compose.yml) and environment variable values (.env) sat in their own project directory, we can use docker-compose to bring our services up.

---

**RUNNING THE APPLICATION**

We spin up the application with the single **docker-compose up -d** command. This does everything to get it running, including setting up the network backing so each service container can converse with one another. The **-d** flag starts the containers in the background and leaves them running whilst **-p** aids the naming convention of the seperate containers;

```
docker-compose -p phpIPAM up -d
```

---

**TESTING**

Aside from the usual checks, it's also a good idea to test the root MySQL password we set via the **MYSQL_ROOT_PASSWORD** variable in Docker Compose;

```
docker ps
docker logs {CONTAINER} -n 40
docker volume ls
docker network ls

docker exec -it {MARIADB_CONTAINER} /bin/sh
mysql -u root -p
show databases;
quit
exit

http://{URL}/phpipam
```

---

**INSTALL CONFIGURATION**

Upon first launching the PHP-PAM console at http://{URL}/phpipam - there will be an installation wizard - choose the following;

- Automatic database installation

Then populate your desired **MySQL username** and **MySQL password** - leave the other default values then select install!

The default creds for the console are 'admin' 'ipamadmin' but you will be prompted to change this at logon. 

---

**POST INSTALL CONFIGURATION**

There are a few manual configuration steps we need to take to tailor PHP-IPAM to our own environment. Logon to the console as 'admin' - then;

- Administration -> IP related management -> Sections -> Create a new section... add subnet name and description

- Administration -> IP related management -> Nameservers -> Add nameserver set... add your internal nameserver then associate it with the new "Section"

- Administration -> IP related management -> Subnets -> Add subnet... make sure that scan agent is 'localhost' and that 'hosts check', 'discover new hosts' and 'resolve dns names' are ON

---

**SUBNET SCANNING**

Click into each new subnet -> Actions -> Click to add to favourites (so we can easily access them via the main dashboard)

Click into each new subnet -> Actions -> Scan subnet for new hosts -> Ping scan

Post scan, the IPs will populate the tables and pie chart. Each subnet will thereafter be scanned automatically every hour, on the hour. Nice.

---

**FINAL MYSQL TEST**

First, reboot the host VM then check that all containers have restarted successfully and that the data has persisted - i.e. the console populated the right data. Then;

```
docker exec -it {MARIADB_CONTAINER} /bin/sh
mysql -u root -p
show databases;
use phpipam;
select * from vlans;
quit
exit
```

**CRON**

The hourly automatic network scans are controlled by the **SCAN_INTERVAL** value - the actual .php scripts being ran from the following directories;

```
docker exec -it {CRON_CONTAINER} /bin/sh
cat /etc/crontabs/apache
0 * * * * /usr/bin/php /phpipam/functions/scripts/discoveryCheck.php
0 * * * * /usr/bin/php /phpipam/functions/scripts/pingCheck.php
0 * * * * /usr/bin/php /phpipam/functions/scripts/resolveIPaddresses.php
```

**MYSQL-BACKUP**

Notable configuration tweaks made to the Compose file;

```
user: "0"
DB_DUMP_TARGET=smb://ubuntu:REDACTED@{NAS IP address}/backups /db
```
Firstly, **user: "0"** will force the backup job to run as root (default is 'appuser') to avoid any permissions issues on local directories, seen in 'docker logs'

The **smb://** target is an SMB share on a NAS device, pre-configured with the 'ubuntu' user for read/write permissions on the /backups share. Simply pass these creds in the target path as shown.

On the host VM level, we need to mount the SMB share. Note that, for SMB use, this host VM requires **sudo apt install smbclient cifs-utils** in order for the `cifs` entry in /etc/fstab to work.

```
sudo mkdir /media/backups
sudo mount -v -t cifs -o username=ubuntu //{NAS IP address}/backups /media/backups
```
To make the mount persistent, we'll need a credentials file that can be referenced in fstab for the 'ubuntu' account;
```
sudo umount /media/backups
nano ~/.smbcredentials
username=ubuntu
password=REDACTED
chmod 600 ~/.smbcredentials
sudo nano /etc/fstab
//{NAS IP address}/backups /media/backups cifs credentials=/home/ubuntu/.smbcredentials,iocharset=utf8 0 0		
sudo mount -a
```
Also note that we are backing up the database to a second location as well, indicated by the whitespace prior to **/db**. This /db directory is a part of our volume mount for the backup service - allowing a backup to be made locally but outside of the container. Post backup, we can view both from the host VM;

Local
```
sudo ls /var/lib/docker/volumes/phpipam_phpipam-db-backups/_data
```
Remote
```
ls /media/backups/
```

**HAPROXY**

Native SSL support can be achieved by use of HAProxy as a reverse HTTPS proxy for phpIPAM. Port binding for `0.0.0.0:80` and `0.0.0.0:443` is reserved for HAProxy (80 requests redirected to 443), whilst the phpIPAM web backend can be set to `0.0.0.0:8081` or similar. Ensure only necessary ports are opened on the firewall, i.e. tcp/8081 is denied;

```
sudo ufw allow http
sudo ufw allow https
sudo ufw status numbered
```
We specify `"8081:80"` for our phpIPAM web backend ports to ensure HAProxy can pass requests to port 80 *internally* using the Docker-compose network backing - on the **172.18.0.0/16** subnet. Source the internal IP for the web container (to state in **haproxy.cfg**) via;

```
docker network ls
docker network inspect php-ipam_default
curl -v 172.18.0.5:80
```
Assuming use of Lets Encrypt and Certbot for your SSL/TLS certificates, `fullchain.pem` and `privkey.pem` will be generated for you. These need to be combined in order for HAProxy to read them properly. Cat them together, then use OpenSSL to display all bundled certs in the file for confirmation;
```
cat ~/docker-compose/php-ipam/{fullchain.pem,privkey.pem} > ~/docker-compose/php-ipam/mycompany.com.pem
while openssl x509 -text; do :; done < mycompany.com.pem
openssl x509 -in mycompany.com.pem -text
```
HAProxy will load your full-chain certificate and key file mounted at `/etc/ssl/certs` inside the container, as per our Docker volumes. Just ensure you have copied the combined .pem file to the mountpoint on the host VM - in this case *"Mountpoint": "/var/lib/docker/volumes/php-ipam_phpipam-haproxy-ssl/_data"*, sourced via;

```
docker volume ls
docker volume inspect php-ipam_phpipam-haproxy-ssl
```
The `haproxy.cfg` is set to be automatically copied to the container mount point via its own volume. Usual troubleshoting provided via;
```
docker restart {HAPROXY_CONTAINER}
docker container logs {HAPROXY_CONTAINER}
```
