# see https://www.nomadproject.io/docs/job-specification

job "pgadmin4" {
  datacenters = ["dc1"]
  group "pgadmin4" {
    network {
      port "http" {
        static = 5050
        to = 5050
      }
    }
    task "pgadmin4" {
      driver = "docker"
      config {
        image = "pgadmin4:5.6"
        ports = ["http"]
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
