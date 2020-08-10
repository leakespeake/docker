# Blackbox Exporter

The Blackbox exporter is a tool that allows you to monitor HTTP, DNS, TCP and ICMP endpoints. Results can be visualized in modern dashboard tools such as Grafana.

Normal use case - run on the Prometheus nodes alongside the Prometheus, Grafana and AlertManager containers. However, the Blackbox exporter is a standalone tool.

It provides metrics about HTTP latencies, DNS lookup latencies as well as statistics about SSL certificates expiration.

The best use case of this container is to monitor the expiry of your public SSL certs. As such, the blackbox.yml http module has been tailored to probe these metrics from the public VIP endpoints.

---

**RUNNING THE CONTAINER**

```
docker run -d \
    --restart unless-stopped \
    --name blackbox \
    -p 9115:9115 \
    leakespeake78/docker:blackbox-exporter-0.17.0
```

---

**TESTING**

Curl the local Blackbox port with the probe target and module to use;

```
curl http://localhost:9115/probe?target=https://90.216.135.8&module=http_2xx
```

---

**DEBUGGING**

Add **debug=true** to our curl command to display the connection logs - these are helpful in shaping the blackbox.yml http module;

```
curl -s "localhost:9115/probe?debug=true&target=https://anoto.com&module=http_2xx" | grep -v \#
```
