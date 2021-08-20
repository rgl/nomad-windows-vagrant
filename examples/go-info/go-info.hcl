# see https://www.nomadproject.io/docs/job-specification
# see https://www.nomadproject.io/docs/job-specification/vault#vault-parameters
# see https://www.nomadproject.io/docs/job-specification/template
# see https://www.nomadproject.io/docs/runtime/interpolation
# see https://www.nomadproject.io/docs/runtime/environment
# see https://github.com/hashicorp/consul-template

job "go-info" {
  datacenters = ["dc1"]
  group "go-info" {
    count = @@group_count@@
    constraint {
      distinct_hosts = true
    }
    network {
      port "http" {
        static = 8000
        to = 8000
      }
    }
    task "go-info" {
      driver = "docker"
      config {
        image = "go-info:1.0.0"
        ports = ["http"]
      }
      # see https://www.nomadproject.io/docs/job-specification/vault#vault-parameters
      vault {
        policies = ["default", "go-info"]
        # restart this task when the vault token changes.
        # this means that the task itself will not try to renew the vault token.
        # NB "restart" is the default.
        change_mode = "restart"
      }
      env {
        VAULT_ADDR = "http://active.vault.service.consul:8200"
        POSTGRESQL_ADDR = "postgres://postgresql.service.consul:5432/greetings?sslmode=disable"
        # set the name of the application that appears in the postgresql tools.
        # NB the used postgres libary can be configured with the environment
        #    variables described at:
        #       https://github.com/lib/pq/blob/v1.9.0/conn.go#L1939-L2015
        #    these are a sub-set of the ones described at:
        #       https://www.postgresql.org/docs/13/libpq-envars.html
        PGAPPNAME = "nomad-${NOMAD_NAMESPACE}-${NOMAD_ALLOC_NAME}-${NOMAD_ALLOC_ID}"
      }
      # see https://www.nomadproject.io/docs/job-specification/template
      # see https://github.com/hashicorp/consul-template
      template {
        destination = "secrets/example.json"
        data = "{{ with secret \"secret/data/example\" }}{{ .Data.data | toJSONPretty }}{{ end }}"
      }
      template {
        destination = "secrets/another-example.json"
        data = "{{ with secret \"secret/data/another-example\" }}{{ .Data.data | toJSONPretty }}{{ end }}"
      }
      service {
        name = "go-info"
        port = "http"
        tags = ["http"]
        meta {
          version = "1.0.0"
        }
      }
    }
  }
}
