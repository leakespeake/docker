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




