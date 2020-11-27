# see https://www.nomadproject.io/docs/job-specification

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
