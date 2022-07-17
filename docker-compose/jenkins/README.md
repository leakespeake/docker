# JENKINS

Jenkins is an automation server you can use to automate just about any task. It’s most often associated with building source code and deploying the results and is synonymous with continuous integration and continuous delivery **(CI/CD)**. Jenkins provides hundreds of **plugins** to support building, deploying and automating any project. More information below;

https://www.jenkins.io/

One of Jenkins’s most powerful features is its ability to distribute jobs across multiple nodes. A Jenkins **controller** sends jobs to the appropriate **agent** based on the job requirements and the resources available at the time. While it’s possible to run jobs on the controller, it’s considered a best practice to always create at least one agent and run your jobs there. So, we’ll use Docker Compose to do just that. 

Jenkins and Docker Compose pair well as we need not worry about which local Java versions are running to support Jenkins. We can also persist our Jenkins data via Docker volumes. We'll use the stable `jenkins/jenkins:lts` official image, rather than the weekly release.

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
We have no need to use a `.env` file to pass in sensitive environment variable values - otherwise we'd create it alongside our compose file.

---

**DOCKER-COMPOSE.YML**

UI host port modified to `8081` to avoid conflicting with `cadvisor`. Port `50000` is used by any additional Jenkins Agents that might be added later.

Whilst possible to run the containers as root, in production you would add a Jenkins user with a user ID of 1000 to the systems running Jenkins controllers and agents. https://docs.docker.com/engine/install/linux-postinstall/

We're also allowing our docker cli inside the container to communicate with the docker service on the host via the additional volume mount;
```
- /var/run/docker.sock:/var/run/docker.sock
```
By mounting the host Unix socket (the Docker daemon listens on), it allow us to use Docker from within Jenkins.

Remember the `jenkins-data` mount on the host vm equates to `/var/lib/docker/volumes/jenkins_jenkins-data/_data` - confirm via `docker inspect jenkins` or `docker volume inspect jenkins_jenkins-data`

---

**RUNNING THE APPLICATION**

We spin up the application with the single **docker-compose up** command. This does everything to get it running, including setting up the network backing so each service container can converse with one another. The **-d** flag starts the containers in the background and leaves them running whilst **-p** (not needed here) aids the naming convention of the seperate containers;

```
docker-compose up -d
```

---

**INSTALL CONFIGURATION**

Upon first launching the Jenkins controller at http://{JENKINS_URL}:8081 - you need to perform the following via the setup wizard;
- unlock Jenkins using an automatically generated password
- install suggested plugins (install additional ones like `terraform` later)
- create first admin user
- change the URL of the controller (if desired)

Running Jenkins in Docker using the official `jenkins/jenkins:lts` image you can use the following to print the password in the console without having to exec into the container;
```
sudo docker exec ${CONTAINER_NAME} cat /var/jenkins_home/secrets/initialAdminPassword
```
Jenkins is then ready to use.

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
docker logs jenkins | less
docker volume inspect jenkins_jenkins-data
docker network inspect jenkins_jenkins-net

```