# see https://www.nomadproject.io/docs/job-specification

job "damon" {
  datacenters = ["dc1"]
  group "damon" {
    count = 1
    task "damon" {
      driver = "raw_exec"
      artifact {
        source = "https://github.com/rgl/damon/releases/download/v0.1.2/damon.zip"
      }
      template {
        destination = "local/example.ps1"
        data = <<-EOD
        $FormatEnumerationLimit = -1
        function Write-Title($title) {
            Write-Output "#`n# $title`n#"
        }
        while ($true) {
          Write-Output "$(Get-Date -Format s)$("-"*128)"
          Write-Output "Process ID:        $PID"
          Write-Output "Current Directory: $PWD"
          Write-Title 'Environment Variables'
          dir env: `
            | Sort-Object -Property Name `
            | Format-Table -AutoSize `
            | Out-String -Stream -Width ([int]::MaxValue) `
            | ForEach-Object {$_.TrimEnd()}
          Write-Title 'whoami /all'
          whoami.exe /all
          Start-Sleep -Seconds 60
          1..10 | ForEach-Object { Write-Output " " }
        }
        EOD
      }
      config {
        command = "local/damon.exe"
        args = [
          "PowerShell.exe",
          "-File",
          "local/example.ps1"
        ]
      }
      resources {
        cpu = 100
        memory = 200
      }
      env {
        DAMON_RESTRICTED_TOKEN = "Y"
      }
    }
  }
}
