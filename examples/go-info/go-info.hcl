# see https://www.nomadproject.io/docs/job-specification
# see https://www.nomadproject.io/docs/job-specification/vault#vault-parameters
# see https://www.nomadproject.io/docs/job-specification/template
# see https://github.com/hashicorp/consul-template

job "go-info" {
  datacenters = ["dc1"]
  group "go-info" {
    count = @@group_count@@
    constraint {
      distinct_hosts = true
    }
    task "go-info" {
      driver = "docker"
      config {
        image = "go-info:1.0.0"
        port_map {
          http = 8000
        }
      }
      resources {
        network {
          port "http" {}
        }
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
