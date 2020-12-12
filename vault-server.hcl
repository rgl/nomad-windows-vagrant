# see https://www.vaultproject.io/docs/configuration#parameters
# see https://learn.hashicorp.com/tutorials/vault/troubleshooting-vault#vault-server-logs
# see https://www.vaultproject.io/docs/configuration/telemetry
# see https://www.vaultproject.io/docs/configuration/listener/tcp#telemetry-parameters

cluster_name = "example"

ui = true

# one of: trace, debug, info, warning, error.
log_level = "trace"

storage "consul" {
    address = "127.0.0.1:8500"
    path = "vault"
}

listener "tcp" {
    address = "0.0.0.0:8200"
    cluster_address = "0.0.0.0:8201"
    tls_disable = true
    telemetry {
        unauthenticated_metrics_access = true
    }
}

api_addr = @@api_addr@@
cluster_addr = @@cluster_addr@@

# enable the telemetry endpoint.
# access it at http://localhost:8200/v1/sys/metrics?format=prometheus
# see https://www.vaultproject.io/docs/configuration/telemetry
# see https://www.vaultproject.io/docs/configuration/listener/tcp#telemetry-parameters
telemetry {
    disable_hostname = true
    prometheus_retention_time = "24h"
}
