# Vault

Vault is a tool for securely accessing secrets. A secret is anything that you want to tightly control access to, such as; 

- passwords
- certificates
- API keys

Vault provides a unified interface to any secret, while providing tight access control and recording a detailed audit log. Vault validates and authorizes clients (users, machines, apps) before providing them access to secrets or stored sensitive data. Vault works primarily with tokens and a token is associated to the client's policy. Each policy is path-based and policy rules constrains the actions and accessibility to the paths for each client. 

The core Vault workflow consists of four stages;

- **authenticate** - a client is authenticated against an auth method, a token is generated and associated to a policy 
- **validation** - a client is validated against third-party trusted sources, such as LDAP, AppRole, Github and more
- **authorize** - a client is matched against the Vault security policy
- **access** - Vault grants access to secrets, keys, and encryption capabilities by issuing a token based on policies associated with the client’s identity

For more information see;

https://www.vaultproject.io/
https://github.com/hashicorp/vault

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
mkdir ~/docker-compose/vault
cd ~/docker-compose/vault
nano docker-compose.yml
```
Remember to change any sensitive values in .env to REDACTED prior to checking into source control. With both our Compose file (docker-compose.yml) and environment variable values (.env) sat in their own project directory, we can use docker-compose to bring our services up.

---

**CONSIDERATIONS**

- STORAGE BACKEND - for homelab purposes, the **Filesystem** storage backend is ample - it stores Vault's data on the filesystem using a standard directory structure - used for durable single server situations. Ensure persistence and backups are in place - Vault can be recovered quickly using (1) backend data (2) server configuration file *vault-config.json* and (3) the unseal key shares. *NOTE: I may migrate this to the **Consul** storage backend at a later date*

- TLS ENABLEMENT - requires TLS certificate for the Vault API. Always ensure end-to-end TLS is configured, whether you have a load balancer in front or not.

- MONITORING - will use Prometheus with a Vault exporter for metric consumption and display in Grafana.

- RESILIENCY - is a load balancer or round robin DNS suitable for your use case?

- TERRAFORM - this readme covers a manual setup, however it might be prudent to bring an existing Vault instance under the management of Terraform (min version 1.5) using the **import** block, to codify the management of policies, keys, engines etc - see: https://developer.hashicorp.com/vault/tutorials/operations/codify-mgmt-vault-terraform

- PRODUCTION HARDENING - see here https://developer.hashicorp.com/vault/tutorials/operations/production-hardening

---

**DOCKER-COMPOSE.YML**

We are not running Vault in development mode (via *vault server -dev*) as there would be no SSL capability and it would only exist in-memory (no persistence), also starting unsealed - used if you purely want to experiment.

Salient parts of the YAML have commnets supplied. Container details for the official Docker Hub image - https://hub.docker.com/_/vault

---

**INSTALL CONFIGURATION**

Vault servers are configured using the **vault-config.json** file, placed within *./config* for copy into the Vault server container via the Docker Compose volume. We then use the *vault server -config* command to specify where Vault should load it from;

```
    volumes:
      - ./config:/vault/config

    command: vault server -config=/vault/config/
```    
There is no mutual trust between the Vault client and server. The https "listener" must be secured by a TLS Certificate to encrypt traffic between the requesting client (authenticated via the TOKEN) and the API.

The main parts of the configuration will involve the listener, TLS, storage and general parameters - a full breakdown is explained below;

https://developer.hashicorp.com/vault/docs/configuration

---

**RUNNING THE APPLICATION**

We spin up the application with the single **docker-compose up -d** command. This does everything to get it running, including setting up the network backing so each service container can converse with one another. The **-d** flag starts the containers in the background and leaves them running whilst **-p** (not needed here) aids the naming convention of the seperate containers;

```
cd ~/docker-compose/vault
docker-compose up -d
docker logs vault-server
curl -XGET https://vault-prd-01.int.leakespeake.com:8200/v1/sys/health
```
---

**INITIALIZE AND UNSEAL VAULT SERVER**

We must first enter the container and initialize our new Vault instance. This is the process by which Vault's storage backend is prepared to receive data;

```
docker exec -it vault-server /bin/sh
vault operator init
```
During initialization, Vault generates a **root key**, which is stored in the storage backend alongside all other Vault data. The root key itself is encrypted and requires an unseal key to decrypt it. The root key is split into a configured number of **shards** (referred as key shares, or **unseal keys**). A certain threshold of shards is required (3/5 unseal keys) to reconstruct the root key, which is then used to decrypt the Vault's encryption key.

Take note of the unseal keys and the **initial root token** and store securely in a decent password safe.

Once started, the Vault is in a sealed state. Unsealing is the process of constructing the master key necessary to read the decryption key to decrypt the data, allowing access to the Vault. Before any other operation can be performed on Vault - it must be unsealed using three of the keys (also every time the Vault server is re-sealed or restarted);

```
vault status
vault operator unseal [UNSEAL KEY 1]
vault operator unseal [UNSEAL KEY 2]
vault operator unseal [UNSEAL KEY 3]
vault status
```
Vault is now unsealed and ready for use! Exit the container then let's also ensure that the API is accessible remotely by opening on UFW;

```
sudo ufw allow from 192.168.0.0/24 to any port 8200
sudo ufw status numbered
```
Next we'll prep our local machine to issue `vault login` commands and test our initial login.

---

**VAULT CLIENT - BASHRC ENV VARIABLES**

Install Vault to your local machine and, at a minimum, add `VAULT_ADDR` to your ~/.bashrc file.

```
### VAULT ENVIRONMENT VARIABLES
export VAULT_ADDR='https://vault-prd-01.int.leakespeake.com:8200'
```
We can also create a function (called 'vauth') to first login to Vault, have Vault read our Consul token, populate a variable **$TOKEN** (with this Consul token) and make it available to the relevant Consul and Terraform environment variables in the shell;

```
### VAULT FUNCTION
function vauth {
    vault login -method=ldap username=$USER
    TOKEN=$(vault read -field=token consul/creds/devops)
    export CONSUL_HTTP_TOKEN="$TOKEN"
    export TF_VAR_consul_token="$TOKEN"
}
```
---

**VAULT LOGIN**

Before a Vault client can interact with Vault, it must authenticate by verifying its identity and then generating a token to associate with that identity. Within Vault, tokens map to information. The most important information mapped to a token is a set of one or more attached policies. These policies control what the token holder is allowed to do within Vault. First, let's authenticate using the ROOT TOKEN

```
vault login 
[ROOT TOKEN]
```
It must be noted that the ROOT TOKEN is the initial way to login to Vault, but... this token can do anything and has no expiration! It's recommended to revoke it and generate new one with expiration settings.

---

**AUDITING AND LOGGING**

Vaut auditing captures all requests and responses made through the API (everything goes via API) – then sent to either;

•	File (will use this option)
•	Unix socket
•	Syslog

The official Vault container exposes the optional volume `/vault/logs` to use for writing persistent audit logs. By default nothing is written here; the 'file' audit backend must be enabled with a path under this directory, see the docker-compose.yaml volume - as per;

```
volumes:
./logs:/vault/logs
```
First, we need to enable an `Audit Device` which keeps a detailed log of all requests and responses to Vault. Running **vault audit list** should show "No audit devices are enabled." - so run the following;

```
vault audit enable file file_path=/vault/logs/audit.log
Success! Enabled the file audit device at: file/
```
We should now be able to view the logs within **audit.log** at the `host:container` mounts specified.
```
cat /home/ubuntu/docker-compose/vault/logs/audit.log
cat /vault/logs/audit.log
```
```
vault audit list

Path     Type    Description
----     ----    -----------
file/    file    n/a
```

The logging component captures server activity (not client activity) and is set in vault-config.json `("log_level": "info",)` - the output being visible via;
```
journalctl -u vault
-- No entries --
```
`journalctl` (query the systemd journal)
`-u` (show messages for the specified systemd UNIT, such as a service unit)

---

**LDAP AUTHENTICATION & ACTIVE DIRECTORY INTEGRATION**

Auth methods are the components in Vault that perform authentication and are responsible for assigning identity and a set of policies to a user. In all cases, Vault will enforce authentication as part of the request processing.

There are many auth methods available to the Vault client for interaction with Vault;

**LDAP**		  # [USER] allows authentication using an existing LDAP server - allows Vault to be integrated into environments without duplicating the user/pass configuration in multiple places (great)
**AppRole**		# [SERVICE] allows machines or apps to authenticate with Vault-defined roles - will be used with `Jenkins` and `Ansible`

Many more listed at https://developer.hashicorp.com/vault/docs/auth

We'll need to use the root token for now to do some initial setup - first let's see what auth methods are avilable now;
```
vault login
vault auth list
```
We'll only see the `token` method at this point, all additional ones need explicit enablement.

The **auth enable** command enables an auth method at a given path. After the auth method is enabled, it usually needs configuration. Auth methods must be enabled and configured in advance before users or machines can authenticate.

```
vault auth enable ldap
Success! Enabled ldap auth method at: ldap/

vault auth list
Path      Type     Accessor               Description                Version
----      ----     --------               -----------                -------
ldap/     ldap     auth_ldap              n/a                        n/a
token/    token    auth_token             token based credentials    n/a
```
NOTE: it's easy to lose track of which login you're using on the CLI - to check, simply use;

```
vault token lookup
```
The value we see for **id** is our current Vault token. We could even paste this into the UI (selecting token auth method) and explore Vault that way.

Now we need to push a configuration to the newly created authentication method. This must contain connection details for your LDAP server, info on how to authenticate users and instructions on how to query for group membership. All configuration options at https://developer.hashicorp.com/vault/docs/auth/ldap

NOTE: install `ADExplorer` on the Domain Controller as it's easier to find the values for the config - https://learn.microsoft.com/en-us/sysinternals/downloads/adexplorer

Now for the push!

```
vault write auth/ldap/config \
    url="ldap://win2019-dc01.int.leakespeake.com" \
    userattr=sAMAccountName \
    userdn="CN=Users,DC=int,DC=leakespeake,DC=com" \
    groupdn="CN=Users,DC=int,DC=leakespeake,DC=com" \
    groupfilter="(&(objectClass=group)(member={{.UserDN}}))" \
    groupattr="cn" \
    binddn="CN=svc_vault_ldap,CN=Users,DC=int,DC=leakespeake,DC=com" \
    bindpass='REDACTED' \
    certificate=@~/.ssh/certbot/cert.pem \
    insecure_tls=false \
    starttls=false
Success! Data written to: auth/ldap/config
```
Now confirm;
```
vault read /auth/ldap/config
```
Then test our new LDAP auth method;
```
vault login -method=ldap username=barry
* no LDAP groups found in groupDN "CN=Users,DC=int,DC=leakespeake,DC=com";
  only policies from locally-defined groups available
policies               ["default"]
```
Worked! At this stage we have simply authenticated successfully against the AD user account properties but only have the `default` policy applied - giving minimal access within Vault. We see the "no LDAP groups found" warning above as we have not yet added our AD user to an AD group (that matches an LDAP group name and associated policy within Vault).

First lets create our new secrets engines as this will form the basis of the access we want to grant via our new Vault policies.

---

**SECRETS ENGINES**

Returning to Vault as root, lets see which engines we have out-of-the-box;
```
vault secrets list
```
There are numerous types of secrets engines that can be created, but here we will use the **Key/Value secrets engine** type. This type has a `version 1` and `version 2` - the difference being that v2 provides versioning of secrets and v1 does not.
```
vault secrets enable -path=kv1 -version=1 kv
vault secrets enable -path=kv2 -version=2 kv
```
Re-issue `vault secrets list` and note that each path is completely isolated and cannot talk to other paths. *Vault is path based!*

Now write a test secret called "test" at kv1/ with key name "mysecret" and value "test";
```
vault kv put kv1/test mysecret=test
Success! Data written to: kv1/test
```
Then check you can read the value;
```
vault kv list kv1/
vault kv get kv1/test
```

---

**ACTIVE DIRECTORY GROUPS**

In preperation for the Vault policies we'll create (admin and read-only) - add new LDAP groups in AD called `vault_admins` and `vault_users` then move intended AD user accounts to them as needed. Remember that the groups need to exist in the paths that Vault has been configured to search - in particular the `groupdn` value - check via **vault read /auth/ldap/config**. Also, these AD group names must exactly match those that we'll create in Vault at `/auth/ldap/groups/` (next).

---

**POLICIES**

Out-of-the-box we have the 'default' policy and the 'root' policy;

```
vault policy list
default
root
```
Authentication works by verifying our identity then generating a token to associate with that identity. Within Vault, tokens map to information. The most important information mapped to a token is a set of one or more attached policies. These policies control what the token holder is allowed to do within Vault. Policies may be created (uploaded) via the CLI or via the API. To create a new policy in Vault, we have 5 steps;

[1] Create our policy file within our local docker-compose directory - we'll commit this with all the other files later to version control;
```
cd policies/
touch vault_admins.hcl
touch vault_users.hcl
```
[2] Upload the policy file to Vault using syntax `vault policy write {policy-name} {policy-file.hcl}` as per;
```
vault policy write vault_admins vault_admins.hcl
```
NOTE - you can re-run this command when making .hcl file / policy amendments

[3] Assign the Vault policy to the Vault LDAP group;
```
vault write auth/ldap/groups/vault_admins policies=vault_admins
```
[4] Confirm changes;
```
vault policy list
vault read auth/ldap/config
```

[5] Test;
```
vault login -method=ldap username=bob
```
If working, we have successfully authenticated against AD! We should see `policies ["default" "vault_admins"]` in the output. Let see what capabilities we have against **kv1/** secrets engine - they should reflect what we configured in the vault_admins policy;
```
vault token capabilities kv1/
create, delete, list, read, sudo, update
```
Future Vault requests will automatically use this token until it expires - more details (including expire_time) for our session can be viewed via `vault token lookup`

---

**REGENERATE ROOT TOKEN (WITH EXPIRATION)**

Now that we have additional login options, it's best to adhere to best practises and limit the scope slightly of the root token.

As stated, after intialilizing Vault you get a `ROOT TOKEN` as the initial way to login and configure Vault. This token can do absolutely anything in Vault and has no expiration! It's recommended to use the Vault Admin account and for root - revoke it permanently or generate a new one with expiration settings. You don't need to be authenticated to generate a new root token but Vault must be unsealed. 

Either a base64-encoded **one-time-password (OTP)** or a **PGP key file** must be provided to start the root token generation. I will use OTP;

First enter as root via `vault login`, revoke the existing root token then initialize a new root token generation;
```
vault token revoke -self
vault operator generate-root -init
```
Nonce and one-time password (OTP) are generated - save both to a password safe! You will need the OTP value later to decode the generated root token.

Add temporary unseal key exports for your terminal session - adding a leading space so they are not recorded to the bash history;
```
 export UNSEAL_KEY1=...
 export UNSEAL_KEY2=...
 export UNSEAL_KEY2=...
```
Then provide 3/5 unseal keys for the nonce value;
```
echo $UNSEAL_KEY1 | vault operator generate-root -nonce=f67f4da3-4ae4-68fb-4716-91da6b609c3e -
echo $UNSEAL_KEY2 | vault operator generate-root -nonce=f67f4da3-4ae4-68fb-4716-91da6b609c3e -
echo $UNSEAL_KEY3 | vault operator generate-root -nonce=f67f4da3-4ae4-68fb-4716-91da6b609c3e -
```
When the quorum of unseal keys are supplied, you'll get the encoded root token. Decode the encoded token using the OTP generated during the initialization;
```
vault operator generate-root \
  -decode=IxJpyqxn3YafOGhqhvP6cQ== \
  -otp=5JFQaH76Ky2TIuSt4SPvO1CGkx
```
The new root token appears - try and login with it via `vault login`. Done.

---

**JENKINS INTEGRATION AND AUTHENTICATION**

This piece is covered in the **ci-cd** repository.

**TROUBLESHOOTING**

```
docker logs vault-server | less
docker volume ls
docker volume inspect [VOLUME_NAME]
docker network ls
docker network inspect vault_default

vault status
```
