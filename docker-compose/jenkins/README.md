# JENKINS

Jenkins is an automation server you can use to automate just about any task. It’s most often associated with building source code and deploying the results and is synonymous with continuous integration and continuous delivery **(CI/CD)**. Jenkins provides hundreds of **plugins** to support building, deploying and automating any project. More information below;

https://www.jenkins.io/

One of Jenkins’s most powerful features is its ability to distribute jobs across multiple nodes. A Jenkins **controller** sends jobs to the appropriate **agent** based on the job requirements and the resources available at the time. While it’s possible to run jobs on the controller, it’s considered a best practice to always create at least one agent and run your jobs there. So, we’ll use Docker Compose to do that. 

Jenkins and Docker Compose pair well as we need not worry about which local Java versions are running to support Jenkins. We can also persist our Jenkins data via Docker volumes. We'll use the stable `jenkins/jenkins:lts` official image, rather than the weekly release.

For the additional NGINX frontend service (more below), we'll use the `nginx:latest` official image. We'll handle HTTPS via this reverse proxy, and leave Jenkins in its default HTTP configuration.

**NOTE (April 2024 - have moved from nginx to haproxy - updating this README soon)**

---

**GETTING STARTED**

Ideally bake Docker Compose into your Packer template (to compliment Docker CE) or otherwise install on the host VM via;
```
sudo apt install docker-compose
docker-compose --version
```
Then run the following to prep the Docker Compose directory and files;
```
mkdir ~/docker-compose
mkdir ~/docker-compose/jenkins
cd ~/docker-compose/jenkins
nano docker-compose.yml
```
Remember to change any sensitive values in .env to REDACTED prior to checking into source control. With both our Compose file (docker-compose.yml) and environment variable values (.env) sat in their own project directory, we can use docker-compose to bring our services up.

---

**DOCKER-COMPOSE.YML**

Port `50000` is used by any additional Jenkins Agents that might be added later.

Whilst possible to run the containers as root, in production you would add a Jenkins user with a user ID of 1000 to the systems running Jenkins controllers and agents. https://docs.docker.com/engine/install/linux-postinstall/

We're also allowing our docker cli inside the container to communicate with the docker service on the host via the additional volume mount;
```
- /var/run/docker.sock:/var/run/docker.sock
```
By mounting the host Unix socket (the Docker daemon listens on), it allow us to use Docker from within Jenkins.

Remember the `jenkins-data` mount on the host vm equates to `/var/lib/docker/volumes/jenkins_jenkins-data/_data` - confirm via `docker inspect jenkins` or `docker volume inspect jenkins_jenkins-data`

---

**NGINX REVERSE PROXY**

I have added an NGINX reverse proxy service primarily for the SSL/TLS offloading, for secure connections over HTTPS. NGINX decrypts the traffic using the Lets Encrypt certificate and private key and communicates with the backend Jenkins instance over HTTP, its default mode.  

Client requests on port 80 are redirected to 443 as per best practises. I have also used the `expose:` option in this docker-compose service - this ensures `8080` is only available on the docker-compose network (shared by the individual services) and not published to the host machine.

```
    expose:
      - "8080"
```    
We then specify `server 172.18.0.10:8080;` in the NGINX default.conf upstream block - assuming `172.18.0.10` is the internal IP of the Jenkins container, sourced via;
```
docker network ls
docker network inspect jenkins_jenkins-net
```
A better approach would be to specify the `Name` value instead of the `IPv4Address` otherwise the service will fail when it picks up a different internal Docker IP.

Obviously also ensure the SSL/TLS certificates have been placed in the correct host machine directory as defined in `.env` and `{NGINX_SSL_CERTS}` - likewise for the NGINX configuration file at `{NGINX_CONF}`. These will then be copied to the right container directories upon launch.

---

**RUNNING THE APPLICATION**

We spin up the application with the single **docker-compose up -d** command. This does everything to get it running, including setting up the network backing so each service container can converse with one another. The **-d** flag starts the containers in the background and leaves them running whilst **-p** (not needed here) aids the naming convention of the seperate containers;

```
docker-compose up -d
```

---

**UPDATING THE APPLICATION**

If we need to gracefully stop Jenkins (due to host VM updates and restarts) we can take the opportunity to update Jenkins to the latest version;
```
 docker stop cicd-jenkins
 docker rm cicd-jenkins
 docker image rm jenkins/jenkins:lts
 docker-compose up -d
 docker ps
 docker logs cicd-jenkins
```

---

**INSTALL CONFIGURATION**

Upon first launching the Jenkins controller at https://{JENKINS_URL} - you need to perform the following via the setup wizard;
- unlock Jenkins using an automatically generated password
- install suggested plugins (install additional ones like `terraform` later)
- create first admin user
- change the URL of the controller (if desired)

Running Jenkins in Docker using the official `jenkins/jenkins:lts` image you can use the following to print the password in the console without having to exec into the container;
```
sudo docker exec ${CONTAINER_NAME} cat /var/jenkins_home/secrets/initialAdminPassword
```
Jenkins is then ready to use - however, we need to set the `Jenkins URL` value to match that of our instance - for example; **https://jenkins-01.int.mycompany.com/** and can set this via *Manage Jenkins > Configure System... Jenkins URL*

Also note that we can amend Jenkins system properties by passing the `JENKINS_JAVA_OPTS` environment values within docker-compose.yaml.

---

**DECLARATIVE PIPELINE SYNTAX**

The official Jenkins syntax for the `Jenkinsfile` is at;

https://www.jenkins.io/doc/book/pipeline/syntax/ 

---

**PLUGINS**

The official Jenkins plugins index is at;

https://plugins.jenkins.io/

---

**TROUBLESHOOTING**

```
docker logs cicd-jenkins | less
docker volume ls
docker volume inspect jenkins_jenkins-data
docker network ls
docker network inspect jenkins_jenkins-net
docker restart cicd-jenkins
```