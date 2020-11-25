# see https://www.nomadproject.io/docs/configuration
# see https://learn.hashicorp.com/tutorials/nomad/production-reference-architecture-vm-with-consul
# see https://learn.hashicorp.com/tutorials/nomad/production-deployment-guide-vm-with-consul

datacenter = "dc1"
data_dir = @@data_dir@@
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
ports {
  http = 4646
  rpc  = 4647
  serf = 4648
}

server {
  enabled = false
}

client {
  enabled = true
  servers = @@servers@@
  network_speed = 1000
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
