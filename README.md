![docker](https://user-images.githubusercontent.com/45919758/85199435-7cd8e480-b2e7-11ea-892f-8c43f38578a7.png)

**USING THE DOCKERHUB PUBLIC REGISTRY**

This example uses the Blackbox Exporter image with the **leakespeake78** Docker ID and **docker** public repository.

First build the image and tag it with a temporary name;

```
docker build --tag blackbox-exporter .
```
Source the IMAGE ID via; 

```
docker images
```
Run the container locally to test using format - docker run --rm -d -p 9115:9115 --name {TEMP NAME} {IMAGE ID};
```
docker run --rm -d -p 9115:9115 --name blackbox c686741581ac
```
**--rm** automatically cleans up the container and removes the file system when the container exits - use when testing!

Ensure that Docker Desktop is signed in with the **leakespeake78** Docker ID - then run;
```
docker login
```
Now re-tag the image using format - docker tag blackbox-exporter {DOCKER_ID}/{DOCKER_REPO}:{IMAGENAME-TAG}
```
docker tag blackbox-exporter leakespeake78/docker:blackbox-exporter-0.17.0
```
Now push the image to your public repository using format; docker push {DOCKER_ID}/{DOCKER_REPO}:{IMAGENAME-TAG}
```
docker push leakespeake78/docker:blackbox-exporter-0.17.0
```
Verify the image exists via https://hub.docker.com/r/leakespeake78/docker/tags

Perform a test pull on another instance;
```
docker pull leakespeake78/docker:blackbox-exporter-0.17.0
```

___
**USING THE DOCKERHUB PRIVATE REGISTRY**

This example uses the X image with the **leakespeake78** Docker ID and **X** private repository.

The syntax is similar to that of a public one. First, we must prefix our image with the host running our private registry instead of our username. 

xxx

___
**DOCKERFILE BEST PRACTISES**

Run the container as a non-root user to prevent malicious code from gaining permissions in the container host;

```
RUN groupadd -g 1000 nonroot && \
    useradd -d /home/barry -u 1000 -g 1000 -m -s /bin/bash barry && \
```
Then state the new **USER** towards the end of the Dockerfile, after all commands that required root permissions;

```
USER barry
ENTRYPOINT  [ "/bin/blackbox_exporter" ]
CMD         [ "--config.file=/etc/blackbox_exporter/config.yml" ]
```
The applications should redirect their logs to STDOUT/STDERR streams so the host can collect them;

```
RUN ln -sf /dev/stdout /var/log/docker-app.log
```
Unless using the "scratch" image, use official DockerHub images when possible. Also source and use a specific version (not "latest"), stating in the tag;

```
FROM centos:7.8.2003
```
Add as much **LABEL** metadata as you like to give as much info about the container as possible;

```
LABEL maintainer="Tim Burr <tim.burr@trees.com>"
LABEL com.leakespeake.version="0.0.1-beta"
LABEL com.leakespeake.release-date="2020-06-30"
```
Use **ADD** as opposed to **COPY** when you will need to unzip the resulting file (and use **COPY** for a literal copy operation);

```
ADD "https://github.com/prometheus/blackbox_exporter/releases/download/v${BLACKBOX_VERSION}/blackbox_exporter-${BLACKBOX_VERSION}.linux-amd64.tar.gz" /tmp/blackbox_exporter.tgz
```
Add a **HEALTHCHECK** so we have a health status of "starting", "healthy" or "unhealthy" rather than just seeing "up" at **docker ps**;

```
HEALTHCHECK CMD curl --fail http://localhost:9115 || exit 1
```
Only the instructions **RUN COPY ADD** create layers so group these commands together into their own blocks.

Cleanup at the end of the **RUN** block to reduce image size;

**CENTOS**

```
yum clean all && \
rm -rf /tmp/*
```
**UBUNTU**

```
apt-get clean && \
rm -rf /var/lib/apt/lists/* /tmp/*
```
Include a **.dockerignore** file in the build directory to exclude files not relevant to the build.

Use **ENV** to make the code more flexible and less DRY. The following NGINX example uses **SED** to replace the **ENV** environment variables;

**DOCKERFILE**

```
ENV NGINX_WORKER_PROCESSES 1
ENV NGINX_WORKER_CONNECTIONS 1024
```
**ENTRYPOINT**

```
NGINX_CONFFILE=/etc/nginx/nginx.conf
sed -i -e "s/%NGINX_WORKER_PROCESSES%/${NGINX_WORKER_PROCESSES}/g" ${NGINX_CONFFILE}
sed -i -e "s/%NGINX_WORKER_CONNECTIONS%/${NGINX_WORKER_CONNECTIONS}/g" ${NGINX_CONFFILE}
```
**NGINX.CONF**

```
worker_processes %NGINX_WORKER_PROCESSES%;
worker_connections %NGINX_WORKER_CONNECTIONS%;
```
We can also use **ENV** to set commonly used version numbers so that version bumps are easier to maintain - consider the following;

```
ENV BLACKBOX_VERSION 0.17.0
ADD "https://github.com/prometheus/blackbox_exporter/releases/download/v${BLACKBOX_VERSION}/blackbox_exporter-${BLACKBOX_VERSION}.linux-amd64.tar.gz" /tmp/blackbox_exporter.tgz
cp /tmp/blackbox_exporter-${BLACKBOX_VERSION}.linux-amd64/blackbox_exporter /bin
```
Lastly, its not essential, but we can redirect STOUT to file /home/barry/log.out then redirect STDERR to STDOUT (inc in the RUN block);

```
exec 3>&1 4>&2 && \
trap 'exec 2>&4 1>&3' 0 1 2 3 && \
exec 1>/home/barry/log.out 2>&1 && \
```
