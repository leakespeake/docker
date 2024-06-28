# Consul
Consul is a distributed, highly-available, and multi-datacenter aware tool for; 

- service discovery
- service mesh
- configuration
- orchestration

It provides a centralized system for service registration and discovery where services can be registered with their;

- location
- health status
- metadata

Consul also includes a DNS server that can be used for service discovery, and supports various load balancing and routing strategies.

For more information see;

https://www.consul.io/
https://github.com/hashicorp/consul


## CONSUL AND DOCKER
Each host in a Consul cluster runs the **Consul agent**, a long running daemon that can be started in client or server mode.

Each cluster has at least 1 agent in `server mode`, and usually 3 or 5 for high availability (we are using 3 here for basic HA). The server agents; 

- participate in a consensus protocol
- maintain a centralized view of the cluster's state
- respond to queries from other agents in the cluster

The rest of the agents in `client mode` participate in a **gossip protocol** to discover other agents and check them for failures, and they forward queries about the cluster to the server agents. Consul allows for individual node failure by replicating all data between each server agent of the cluster. If the **leader** node fails, the remaining cluster members will elect a new leader following the **raft protocol**. 

Raft is the consensus algorithm that Consul uses to respond to client requests and replicate information (logs) between server agents. Information flows unidirectionally from the leader to the other server agents.


## GETTING STARTED
Ideally bake Docker Compose into your Packer template (to compliment Docker CE) or otherwise install on the host VM via;
```
sudo apt install docker-compose
docker-compose --version
```
Then run the following to prep the Docker Compose directory and files;
```
mkdir ~/docker-compose
mkdir ~/docker-compose/consul
cd ~/docker-compose/consul
nano docker-compose.yml
```
Remember to change any sensitive values in `.env` to REDACTED prior to checking into source control.


## CONSIDERATIONS
- DATA PERSISTENCE - the Consul container exposes VOLUME **/consul/data** which is a path where Consul will place its persisted state. We can back this data up using the **consul snapshot save** command, saving a copy to `data_dir/raft/snapshots`

- CONFIGURATION - the container has a Consul configuration directory set up at **/consul/config** and the agent will load any configuration files placed here by binding a volume or by composing a new image and adding files.

- TLS ENABLEMENT - requires TLS certificate for the Consul API. Always ensure end-to-end TLS is configured, whether you have a load balancer in front or not.

- REVERSE PROXY - a reverse proxy is the recommended method to expose our internal Consul servers to the Internet, we'll use Nginx with the `proxy_pass` directive.

- HA - we are running 3 server mode Consul agents on the same host VM as this is a homelab - however, split these into seperate hosts in a production environment.

- MONITORING - will use Prometheus with a Consul exporter for metric consumption and display in Grafana.

- TERRAFORM - this readme covers a manual setup, however it might be prudent to bring an existing Consul instance under the management of Terraform using the **import** block, to codify the management of policies, keys, rules etc


## DOCKER-COMPOSE.YML
We are not running Consul in development mode (via the *-dev* flag) as there would be no SSL capability and it would only exist in-memory (no persistence). It would also ship with default bridge networking and no services exposed on the host.

Our Docker Compose configuration file instructs Docker to create 3 Consul agent containers in `server mode` using their respective configuration files. It will then configure networking, and bootstrap the Consul datacenter with 3 Consul servers. Three servers in a datacenter is the recommended minimum for achieving a balance between availability and performance. These servers together run the Raft-driven consistent state store for updating; 

- catalog
- session
- prepared query
- ACLs
- KV state

Container details for the official Docker Hub image - https://hub.docker.com/r/hashicorp/consul


## CONSUL SERVER CONFIGURATION
Consul servers are configured using the **server.json** files, placed within *./config* for copy into the Consul server container via the Docker Compose volume. 

Each Consul server calls the agent and starts the server based on their server config. The first server container has **"agent -bootstrap-expect=3"** to indicate the number of consul members and to initiate a leader upon start.

Consul servers require up to 5 different ports to work properly, some on TCP, UDP, or both protocols;

- 8600 # **DNS** enabled by default -receives incoming traffic from workloads to resolve Consul DNS requests
- 8500 # **HTTP API** enabled by default - receives incoming traffic from workloads that make HTTP API calls (such as the Consul CLI) - also, TLS connections via **nginx** are handed off here
- 8300 # **Server RPC** enabled by default - sends and receives traffic between Consul servers in the same datacenter, as well as incoming traffic from Consul clients in the same datacenter
- 8301 # **LAN Serf** enabled by default - sends and receives traffic from Consul clients and other Consul servers in the same datacenter using the **gossip protocol**

See https://developer.hashicorp.com/consul/docs/install/ports#consul-servers for more.

Salient options within our server.json files are;

- **encrypt** - enables `gossip` encryption via a 32-bytes, Base64 encoded key which we generate via **consul keygen**. All nodes within a Consul cluster must share the same encryption key in order to send and receive cluster information.

- **data-dir** - provides a data directory for the agents to store state, this directory should be durable across reboots - especially critical for agents that are running in server mode as they must be able to persist cluster state. Use `docker exec -it consul-server1 /bin/sh` and explore `"data_dir": "/consul/data",`

- **retry-join** - addresses of the other agents to join with upon starting up - the agents then maintain their membership via gossip.

- **acl** - enablement of the ACL system and assocated agent tokens (more on this below)


## NGINX REVERSE PROXY CONFIGURATION
I have added an NGINX reverse proxy service primarily for the SSL/TLS offloading, securing connections over HTTPS. NGINX decrypts the traffic using the Lets Encrypt certificate and private key and communicates with the backend Consul instances over HTTP (port 8500) - alternating between the Consul nodes specified in the nginx.conf `upstream` block.

Reverse proxy functionality is enabled through Nginx’s **proxy_pass** directive. Requests on port 80 are automatically diverted to 443.

Also ensure the SSL/TLS certificates have been placed in the correct host machine directory as defined in `.env` and `{NGINX_SSL_CERTS}` - likewise for the NGINX configuration file at `{NGINX_CONF}`. These will then be copied to the right container directories upon launch.

General information here https://www.digitalocean.com/community/tutorials/how-to-configure-nginx-as-a-reverse-proxy-on-ubuntu-22-04


## RUNNING THE APPLICATION STACK
With both our Compose file (docker-compose.yml) and all other associated files sat in their own project directory, we can use docker-compose to bring our services up.

We spin up the application with the single **docker-compose up -d** command. This does everything to get it running, including setting up the network backing so each service container can converse with one another. The **-d** flag starts the containers in the background and leaves them running whilst **-p** (not needed here) aids the naming convention of the seperate containers;

```
cd ~/docker-compose/consul
docker-compose up -d
```
If we use `docker logs consul-server1` we can clearly see the Consul cluster discovery, sync and leader election; 

```
Starting Consul agent...
Version: '1.18.2'
Node name: 'consul-server1'
Datacenter: 'dc1' (Segment: '<all>')
Server: true (Bootstrap: false)
Client Addr: [127.0.0.1] (HTTP: 8500, HTTPS: -1, gRPC: -1, gRPC-TLS: 8503, DNS: 8600)
Cluster Addr: 172.24.0.3 (LAN: 8301, WAN: 8302)
Gossip Encryption: true

[INFO]  agent: Starting server: address=[::]:8500 network=tcp protocol=http
[INFO]  agent: (LAN) joining: lan_addresses=["consul-server2", "consul-server3"]
[INFO]  agent: (LAN) joined: number_of_nodes=2
[INFO]  agent: Join cluster completed. Synced with initial agents: cluster=LAN num_agents=2
[INFO]  agent.server: New leader elected: payload=consul-server3

[INFO]  agent.server: initializing acls
[INFO]  agent.server: Created ACL 'global-management' policy
[INFO]  agent.server: Created ACL 'builtin/global-read-only' policy
[INFO]  agent.server: Created ACL anonymous token from configuration
```
Consul is now ready to configure for use! Exit the container then let's also ensure that the API is accessible remotely by opening on UFW;

```
sudo ufw allow from 192.168.0.0/24 to any port 443
sudo ufw status numbered
```
Then from your local machine issue an **openssl s_client** command: `openssl s_client -connect consul-prd-01.int.leakespeake.com:443 -servername consul-prd-01.int.leakespeake.com`

## ACCESS CONTROL LISTS (ACLs)
Network communication to Consul agents should be secured by configuring encryption, authentication, and authorization in Consul. `Access Control Lists (ACLs)` authenticate requests and authorize access to resources. They also control access to the Consul UI, API, and CLI, as well as secure service-to-service and agent-to-agent communication. Consul ACL divides its work in two parts;

- ACL Token - used for **authentication** between remote client & Consul server agent - linked to an ACL policy
- ACL Policy - used for **authorization** using one or more `ACL rules` contained in the policy to define access to resources - linked to an ACL token

An example of this would be the initial **bootstrap token** that is automatically linked to the **global-management policy** - more on this below.

### BOOTSTRAP ACL SYSTEM
Prior to bootstrapping the ACL system, when Consul starts up initially an **anonymous token** is created, being the built-in token that is used when no other token is set - this is seen in the logs;
```
[INFO]  agent.server: Created ACL anonymous token from configuration
```
Further down the logs, we'll then see Consul agent ops that are blocked due to insuffient permissions of the anonymous token;
```
[WARN]  agent: Coordinate update blocked by ACLs: accessorID="anonymous token"
```
This is because the datacenter is configured to have ACL enabled by default, denying any request that does not present a valid token. You must bootstrap the ACL system to finish setting up your Consul server.

First, (on the Consul host vm) - install the Consul CLI via `sudo apt install consul` then configure the environment to be able to interact with the local Consul agent via;
```
export CONSUL_HTTP_ADDR=localhost:8501
```
Now bootstrap the ACL system via;
```
consul acl bootstrap
```
This command generates a new token with **unlimited privileges** to use for management purposes and outputs the token's details;

```
AccessorID:       351df266-REDACTED-REDACTED-REDACTED-REDACTED
SecretID:         ad6803b6-REDACTED-REDACTED-REDACTED-REDACTED
Description:      Bootstrap Token (Global Management)
Local:            false
Create Time:      2024-06-10 07:10:15.36516995 +0000 UTC
Policies:
   00000000-0000-0000-0000-000000000001 - global-management
```
You can create this bootstrapping token only once and afterwards bootstrapping will be disabled, so secure them in a safe place. Finally, set the `CONSUL_HTTP_TOKEN` environment variable to the **SecretID** value;

```
export CONSUL_HTTP_TOKEN=ad6803b6-REDACTED-REDACTED-REDACTED-REDACTED
```
You can now use the bootstrap token to create other ACL policies and tokens for the rest of your datacenter. You will also use the same token to configure the Vault secrets engine. First a quick test;
```
consul info
consul members
consul catalog nodes
consul operator raft list-peers
```
The first step towards a more fine grained ACL approach is to create individual tokens for the server agents (and end-user Consul operators) so that they can interact properly with the rest of the Consul datacenter without being assigned the unlimited bootstrap token. But just for this initial system configuration, the bootstrap token is fine.

### ACL TOKENS
ACL tokens are the core method of authentication in Consul. Tokens contain several attributes, but the value of the **SecretID** field is the attribute that you or your service must include to identify the person or system making the request. You may also use the token's **AccessorID** for tasks such as auditing.

### ACL POLICIES & ACL RULES
Policies define which services and agents are authorized to interact with resources in the network. A policy is a group of one or more ACL rules that are linked to ACL tokens. In the logs we see the built-in `global-management` policy creation (which is automatically linked to the initial `bootstrap token` once created).
```
[INFO]  agent.server: Created ACL 'global-management' policy
```
To see all Consul `resources` we can apply policies to: https://developer.hashicorp.com/consul/docs/security/acl/acl-rules

### ROLES
We will use roles in the steps below using our integration with Vault.


## VAULT INTEGRATION
HashiCorp's Vault has a secrets engine for generating short-lived Consul tokens, the **Consul Secrets Engine**. This engine generates `Consul Access Control (ACL) tokens` dynamically based on `Consul ACL policies`. We'll use it issue tokens for the server agents and our end-user Consul operators, with permissions tailored to these groups.

First, authenticate to Vault then enable the Consul Secrets Engine;
```
vault secrets enable consul

Success! Enabled the consul secrets engine at: consul/
```
Update your `vault_admins` Vault policy to include the new Consul path - `cd ~/vault-policies` and amend the **.hcl** file as required then run;
```
vault policy write vault_admins vault_admins.hcl

Success! Uploaded policy: vault_admins
```
Now configure access for Vault with Consul's address and management token (since we have already bootstrapped the Consul ACL system);
```
vault write consul/config/access address=${CONSUL_HTTP_ADDR} token=${CONSUL_HTTP_TOKEN}

Success! Data written to: consul/config/access
```
We can check the `address` that Vault is using at any time via `vault read consul/config/access`

On Consul, create a **Consul ACL policy** to define a tokens' privileges - that permits server agents to register themselves, locate other agents and discover services. To compliment our local `~/vault-policies` folder (where we amend and upload our Vault policies), we should now also create `~/consul-policies` to do the same in Consul - then create **consul_server_policy.hcl** as per;
```
node_prefix "consul-server" {
  policy = "write"
}
node_prefix "" {
  policy = "read"
}
service_prefix "" {
  policy = "read"
}

```
Then create the policy with the `consul acl` command;

```
consul acl policy create -name "consul-servers" -description "Token capable of agent registration, location and service discovery" -valid-datacenter "home-dc-01" -rules @consul_server_policy.hcl
```
Once the "consul-servers" policy is created you need to *associate it to a token* in order to use it. To do this we'll configure a **Vault role** that maps a name in Vault to a set of Consul ACL policies. If users generate credentials associated with this role, they will be associated with the policies of that role. (Roles allow you to group a set of policies and service identities into a reusable higher-level entity that can be applied to many tokens.)
```
vault write consul/roles/consul-server-role policies=consul-servers
Success! Data written to: consul/roles/consul-server-role
```
Now lets test the creation of a Consul token via Vaults dedicated Consul secrets engine;
```
vault read consul/creds/consul-server-role
```
It's the running of **vault read** against the **/consul/creds/:name** path that generates a dynamic Consul token based on the given role definition, seen in our output here;
```
Key                 Value
---                 -----
lease_id            consul/creds/consul-server-role/0607S2FZjJiGrqVFXiaBTSUM
lease_duration      168h
lease_renewable     true
accessor            f8c87253-REDACTED-REDACTED-REDACTED-REDACTED
consul_namespace    n/a
local               false
partition           n/a
token               659b8bec-REDACTED-REDACTED-REDACTED-REDACTED
```
Verify that the token is created correctly in Consul by looking it up via its `accessor` value;
```
consul acl token read -id f8c87253-REDACTED-REDACTED-REDACTED-REDACTED

AccessorID:       f8c87253-REDACTED-REDACTED-REDACTED-REDACTED
SecretID:         659b8bec-REDACTED-REDACTED-REDACTED-REDACTED
Description:      Vault consul-server-role ldap-barry 1719212650547125986
Local:            false
Create Time:      2024-06-24 07:04:10.762867449 +0000 UTC
Policies:
   7a0feee6-f0d0-d06a-6760-961c1f6893cd - consul-servers
```
Any user or process with access to Vault can now create short lived Consul tokens in order to carry out operations, thus centralizing the management of Consul tokens.

Note that the way Vault and Consul refer to tokens in the command output is slightly different;
- the unique identifier for the token [Consul uses `AccessorID`] [Vault uses `accessor`]
- the actual token to be used for configuration and ops [Consul uses `SecretID`] [Vault uses `token`]

Finally, lets register the token with the Consul servers as its new agent token;
```
consul acl set-agent-token agent 659b8bec-REDACTED-REDACTED-REDACTED-REDACTED
```
This replaces the agents use of the initial bootstrap token that had unlimited privileges.

Use the same approach for a standard Consul user and a Consul operator - for example;
```
consul acl policy create -name "consul-operators" -description "Token capable of write access to all Consul resources plus write operator ops" -valid-datacenter "home-dc-01" -rules @consul_operator_policy.hcl

vault write consul/roles/consul-operator-role policies=consul-operators

consul acl policy create -name "consul-users" -description "Token capable of read-only access to all Consul resources plus read-only operator info" -valid-datacenter "home-dc-01" -rules @consul_user_policy.hcl

vault write consul/roles/consul-user-role policies=consul-users
```
These .hcl rules files can be found in the **/policies** folder.

### TOKEN LEASE AND ROTATION
The tokens created using the integration with Vault's Consul secrets engine are created with a Time To Live (TTL) of 30 days. You can verify the lease duration and expiration time on the Vault UI (under Leases) using the `lease_id` value - for example `consul/creds/consul-server-role/0607S2FZjJiGrqVFXiaBTSUM` 

The recommended approach for operators is to rotate the tokens by generating a new token using the `vault read consul/creds/consul-server-role` (every month), then register the token with the servers via `consul acl set-agent-token agent [token]` - however, this is a manual approach. We'll need to automate the whole process, as well as the updating of the `tokens:` block in our **server.json** files via Ansible (out of scope here).

## CONSUL CLI
Consul is controlled via a very easy to use command-line interface (CLI) - install it locally via `sudo apt install consul`.

As we saw above with the Consul agent ops, We'll also need to supply a valid Consul token when we begin issueing `consul` cli commands at our `CONSUL_HTTP_ADDR` address. Without this, Consul will default to using the **anonymous token** and display `Permission denied: anonymous token lacks permission 'agent:read' on "consul-server3". The anonymous token is used implicitly when a request does not specify a token.`

To avoid this, add a permanent export for **CONSUL_HTTP_ADDR** to `~/.bashrc` to set our Consul address;
```
### CONSUL ENVIRONMENT VARIABLES
export CONSUL_HTTP_ADDR=https://consul-prd-01.int.leakespeake.com
```
Then add a temporary export for **CONSUL_HTTP_TOKEN** via a function. Running `vauth` will log you into Vault, create a new Consul Operator ACL token then load that value into the `$TOKEN` variable for use with the temporary export.
```
### VAULT AND CONSUL TOKEN FUNCTION
function vauth {
  vault login -method=ldap username=$USER
    TOKEN=$(vault read -field=token consul/creds/consul-operator-role)
      export CONSUL_HTTP_TOKEN="$TOKEN"
}
```
We could also add **export TF_VAR_consul_token="$TOKEN"** if we need Terraform to use the same token. The syntax for the `vault read -field` command should be `vault read -field YOUR_KEY_NAME secret/path/to/your/key` - this prints only the field with the given name without a trailing newline, making it ideal for piping to other processes.

For quick reference use `env | grep CONSUL` and `consul acl token read -id {accessor}`.

## CONSUL SERVICE REGISTRATION
TBC

## JENKINS INTEGRATION AND AUTHENTICATION
This piece is covered in the **ci-cd** repository with use of the Jenkins Consul plugin.

## CONSUL BACKUPS
The `snapshot save` command is used to retrieve an atomic, point-in-time snapshot of the state of the Consul servers which includes key/value entries, service catalog, prepared queries, sessions, and ACLs. 
```
consul snapshot save -append-filename version,dc backup.snap
```
More info at https://developer.hashicorp.com/consul/commands/snapshot/save

## TROUBLESHOOTING

```
docker logs consul-nginx | less
docker logs consul-server1
docker volume ls
docker volume inspect [VOLUME_NAME]
docker network ls

tail -f logs/nginx/access.log
tail -f logs/nginx/error.log

consul info
consul members -detailed
consul catalog services
consul catalog nodes
consul operator raft list-peers
consul operator raft list-peers -stale=[true|false]
```
