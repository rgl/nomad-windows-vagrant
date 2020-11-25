# see https://www.nomadproject.io/docs/job-specification
# see https://www.nomadproject.io/docs/job-specification/artifact
# see https://www.nomadproject.io/docs/runtime/environment
# see https://www.nomadproject.io/docs/internals/filesystem

job "graceful-stop" {
  datacenters = ["dc1"]
  group "graceful-stop" {
    task "graceful-stop" {
      driver = "raw_exec"
      kill_timeout = "15s"
      config {
        command = "local/graceful-terminating-console-application-windows.exe"
        args = [
          "10"
        ]
      }
      artifact {
        source = "https://github.com/rgl/graceful-terminating-console-application-windows/releases/download/v0.5.0/graceful-terminating-console-application-windows.zip"
      }
    }
  }
}
