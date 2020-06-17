# docker
Docker images

**USING THE DOCKER REGISTRY**

To push to a private repository the syntax is similar to that of a public one. First, we must prefix our image with the host running our private registry instead of our username. 

List images by running `docker images` and insert the correct ID into the tag command;

```
docker tag f455ea72d468 registry.example.com:5000/apache
```
After tagging, the image needs to be pushed to the registry;

```
docker push registry.example.com:5000/apache
```
Once the image is done uploading, you should be able to start the exact same container on a different host by running;

```
docker run -d -p 80:80 registry.example.com:5000/apache /usr/sbin/apache2ctl -D FOREGROUND
```
___
