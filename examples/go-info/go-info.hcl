# see https://www.nomadproject.io/docs/job-specification

job "go-info" {
  datacenters = ["dc1"]
  group "go-info" {
    count = 2
    constraint {
      distinct_hosts = true
    }
    network {
      port "http" {
        to = 8000
      }
    }
    task "go-info" {
      driver = "docker"
      config {
        image = "go-info:1.0.0"
        ports = ["http"]
      }
    }
  }
}
