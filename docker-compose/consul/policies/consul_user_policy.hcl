  GNU nano 4.8                                                                                                                consul_user_policy.hcl                                                                                                                 Modified  # Controls access to cluster-wide Consul operator info
operator = "read"

# Controls access to ACL policies
acl = "read"

# Controls access to the key/value store
key_prefix "" {
  policy = "read"
}

# Controls access to node level ops
node_prefix "" {
  policy = "read"
}

# Controls access to services
service_prefix "" {
  policy = "read"
}

# Controls access to utility ops such as 'join' and 'leave'
agent_prefix "" {
  policy = "read"
}

# Controls access to event ops such as firing and listing events
event_prefix "" {
  policy = "read"
}

# Controls access to create, update, and delete prepared queries
query_prefix "" {
  policy = "read"
}

# Controls access to event ops in the session API
session_prefix "" {
  policy = "read"
}