# see https://www.consul.io/docs/agent/options
# see https://www.consul.io/docs/agent/options#configuration-key-reference
# see https://www.consul.io/docs/install/ports
# see https://learn.hashicorp.com/tutorials/consul/reference-architecture

server = false

datacenter = "dc1"

data_dir = @@data_dir@@

log_level = "DEBUG"
log_file = @@log_file@@
log_rotate_bytes = 52428800 # 50MiB
log_rotate_max_files = 10

disable_anonymous_signature = true
disable_update_check = true

bind_addr = "0.0.0.0"
client_addr = "0.0.0.0"
advertise_addr = @@ip_address@@
retry_join = [@@servers@@]

# NB if you change these ports you also need to change them in the firewall
#    settings, server (in the ports stanza and retry_join),
#    client (in the servers array).
# NB clients only need access to the servers http and serf_lan ports.
ports {
  server = 8300
  serf_lan = 8301
  serf_wan = 8302
  http = 8500
  dns = 8600
}

ui_config {
  enabled = true
}

telemetry {
  disable_hostname = true
  prometheus_retention_time = "1m" # this should be at least 2 * Prometheus scrape_interval.
}
