# Jenkins policy to consume Vault secrets during a pipeline run 

# Read and list key/value secrets for kv1
path "kv1/*"
{
  capabilities = ["read", "list"]
}

# Read and list key/value secrets for kv2
path "kv2/*"
{
  capabilities = ["read", "list"]
}