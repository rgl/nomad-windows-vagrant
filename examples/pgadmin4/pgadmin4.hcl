# see https://www.nomadproject.io/docs/job-specification

job "pgadmin4" {
  datacenters = ["dc1"]
  group "pgadmin4" {
    task "pgadmin4" {
      driver = "docker"
      config {
        image = "pgadmin4:4.29"
        port_map {
          http = 5050
        }
      }
      resources {
        network {
          port "http" {
            static = 5050
          }
        }
      }
      service {
        name = "pgadmin4"
        port = "http"
        tags = ["http"]
        check {
          type = "http"
          port = "http"
          path = "/misc/ping"
          interval = "20s"
          timeout = "2s"
        }
      }
    }
  }
}
