# Controls access to cluster-wide Consul operator info
operator = "write"

# Controls access to ACL policies
acl = "write"

# Controls access to the key/value store
key_prefix "" {
  policy = "write"
}

# Controls access to node level ops
node_prefix "" {
  policy = "write"
}

# Controls access to services
service_prefix "" {
  policy = "write"
}

# Controls access to utility ops such as 'join' and 'leave'
agent_prefix "" {
  policy = "write"
}

# Controls access to event ops such as firing and listing events
event_prefix "" {
  policy = "write"
}

# Controls access to create, update, and delete prepared queries
query_prefix "" {
  policy = "write"
}

# Controls access to event ops in the session API
session_prefix "" {
  policy = "write"
}