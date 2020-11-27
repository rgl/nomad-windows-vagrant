# see https://www.nomadproject.io/docs/configuration
# see https://www.nomadproject.io/docs/configuration/consul
# see https://learn.hashicorp.com/tutorials/nomad/production-reference-architecture-vm-with-consul
# see https://learn.hashicorp.com/tutorials/nomad/production-deployment-guide-vm-with-consul
# see https://www.nomadproject.io/docs/internals/security#network-ports

datacenter = "dc1"

data_dir = @@data_dir@@

log_level = "DEBUG"
log_file = @@log_file@@
log_rotate_bytes = 52428800 # 50MiB
log_rotate_max_files = 10

disable_anonymous_signature = true
disable_update_check = true

bind_addr = "0.0.0.0"

advertise {
  http = @@ip_address@@
  rpc  = @@ip_address@@
  serf = @@ip_address@@
}

# NB if you change these ports you also need to change them in the firewall
#    settings, server (in the ports stanza and retry_join),
#    client (in the servers array).
# NB clients only need access to the servers http port. the other ports are
#    used between servers.
ports {
  http = 4646
  rpc  = 4647
  serf = 4648
}

server {
  enabled = true
  bootstrap_expect = @@bootstrap_expect@@
  server_join {
    retry_join = [@@server1_ip_address@@]
  }
}

client {
  enabled = false
  network_speed = 1000
  network_interface = @@network_interface@@
}

consul {
  address = "127.0.0.1:8500"
}

plugin "raw_exec" {
  config {
    enabled = true
  }
}

telemetry {
  publish_allocation_metrics = true
  publish_node_metrics = true
}
