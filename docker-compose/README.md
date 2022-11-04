# Docker Compose

Whilst Docker is a great tool to build images and run isolated services, some applications depend on several services. Orchestrating a multi-container application to start up, communicate, and shut down together can become unwieldy. 

Docker Compose is a tool that allows you to run multi-container application environments based on definitions set in a YAML file. It uses service definitions to build fully customizable environments with multiple containers that can share networks and persistent data via volumes. The Compose file itself is broadly comprised of the following sections;

- **version** - tell Docker Compose which configuration version we’re using
- **services** - states each service that makes up the app - each image, port, environment variable, restart behaviour etc
- **volumes** - creates a shared volume between the host (inside **/var/lib/docker/volume**) and the container (example - host-db-data:**/var/lib/mysql**)- for data to persist between container restarts

Ideally bake Docker Compose into your Packer template (to compliment Docker CE) or otherwise install via;
```
sudo apt install docker-compose
docker-compose --version
```
---

**VERSIONS**

Use the latest version of Docker Compose (1.27 at time of writing) but note that the version of the Compose file we create (**docker-compose.yml**) must be operable with the Docker Engine version - this compatibility matrix can be checked below;

https://docs.docker.com/compose/compose-file/

---

**GETTING STARTED**

Using the php-ipam application as an example, SSH to your intended host VM then run the following;

```
mkdir ~/docker-compose
mkdir ~/docker-compose/php-ipam
cd ~/docker-compose/php-ipam
nano docker-compose.yml				
nano .env
```
The **.env** file must be created in the same directory as our Compose file and is used to state sensitive environment variable values that are used within the Compose file. Variables with string interpolation are declared as ${variable} and Docker parses and sets the values of these environment variables at run time. Note that we can still commit this file to source control - just remember to change the values to REDACTED.

With the 2 files sat in their own project directory, we can then use docker-compose to bring our services up.

---

**RUNNING THE APPLICATION**

We spin up the application with the single **docker-compose up -d** command. This does everything to get it running, including setting up the network backing so each service container can converse with one another. The **-d** flag starts the containers in the background and leaves them running whilst **-p** aids the naming convention of the seperate containers;

```
docker-compose -p phpIPAM up -d
```
---

**AMENDING THE APPLICATION**

If we need to amend a particular container config in docker-compose.yml (or add an additional one), we can do so then re-run the `up` command. Docker Compose will detect which containers are up-to-date and which require creating or re-creating. 

We can also remove a current container entirely and build a new one - this requires bringing the application stack `down` first via;

```
docker-compose down && sudo docker-compose -p phpIPAM up -d
```
If the network is currently in use by a container (e.g. the backup container is writing data to the NAS), you may recieve an error explaining that the docker-compose backing network "has active endpoints". Either wait or if absolutely needed, run the following to inspect the network, note the container names, remove the containers (ensuring volumes are present for data persistence), bring the stack down, amend docker-compose.yml, then finally bring the stack up;
``` 
docker volume ls
docker network ls
docker network inspect {NETWORK}
docker rm -f {CONTAINER}
docker ps -a
docker-compose down
nano docker-compose.yml
docker-compose -p phpIPAM up -d
```
---

**BACKING NETWORK**

If there have been many changes made over time to the services and networks etc, it can be helpful to prune un-used networks and re-create them, especially when you see unusual internal comms issues in the container logs. As per commands above, we can list and inspect our networks to note where our containers sit, then stop them prior to the following;
```
docker network prune
docker-compose up -d --force-recreate
```
Note that `prune` will delete all networks that are not connected to currently active containers.

Also note that container config files that reference other services by their `IPv4Address` as opposed to their `Name` value, will fail when they pick up a different internal Docker IP - these values are sourced via `docker network inspect {NETWORK}`.

---

**TESTING**

```
docker ps
docker logs {CONTAINER} -n 40
docker exec -it {CONTAINER} /bin/sh
docker exec -it {CONTAINER} /bin/ash
docker exec -it {CONTAINER} /bin/bash
docker volume ls
docker network ls
```
---