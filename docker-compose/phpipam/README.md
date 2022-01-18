# PHP-IPAM

PHP-IPAM is an open-source web IP address management application (IPAM). Its goal is to provide light, modern and useful IP address management. It is a php-based application with a MySQL database backend (MariaDB). The full set of features are listed here;

https://phpipam.net/

**GETTING STARTED**

SSH to your intended host VM, then run the following;

```
mkdir ~/docker-compose
mkdir ~/docker-compose/php-ipam
cd ~/docker-compose/php-ipam
nano docker-compose.yml				
nano .env
```
Remember to change the values in .env to REDACTED prior to checking into source control.

With both our Compose file (docker-compose.yml) and environment variable values (.env) sat in their own project directory, we can use docker-compose to bring our services up.

---

**RUNNING THE APPLICATION**

We spin up the application with the single **docker-compose up** command. This does everything to get it running, including setting up the network backing so each service container can converse with one another. The **-d** flag starts the containers in the background and leaves them running whilst **-p** aids the naming convention of the seperate containers;

```
docker-compose -p phpIPAM up -d
```

---

**TESTING**

Aside from the usual checks, it's also a good idea to test the root MySQL password we set via the **MYSQL_ROOT_PASSWORD** variable in Docker Compose;

```
docker ps
docker logs {CONTAINER}

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
