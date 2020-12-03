# see https://www.nomadproject.io/docs/job-specification

job "damon-su" {
  datacenters = ["dc1"]
  group "damon-su" {
    count = 1
    task "damon-su" {
      driver = "raw_exec"
      artifact {
        source = "https://github.com/rgl/damon/releases/download/v0.1.2/damon.zip"
      }
      artifact {
        source = "https://github.com/rgl/WinSudo/releases/download/v0.0.0.20201201/WinSudo.zip"
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
      template {
        destination = "local/su.ps1"
        data = <<-EOD
        # create the test user.
        $username = 'test-su'
        $password = 'HeyH0Password'
        if (!(Get-LocalUser -ErrorAction SilentlyContinue $username)) {
          Write-Host "Creating the local $username user account..."
          New-LocalUser `
            -Name $username `
            -FullName 'Example local user account' `
            -Password (ConvertTo-SecureString -AsPlainText -Force $password) `
            -PasswordNeverExpires `
            | Out-Null
        }

        # grant the test user permissions to read anything from the
        # local directory.
        Import-Module Carbon
        Grant-Permission local $username Read

        # execute the local/example.ps1 as the test-su user.
        # whoami /all returns the following information for our test-su
        # user when we login at the machine console:
        #
        #    USER INFORMATION
        #    ----------------
        #
        #    User Name       SID
        #    =============== ==============================================
        #    client1\test-su S-1-5-21-1111749203-1379212500-1899942209-1003
        #
        #
        #    GROUP INFORMATION
        #    -----------------
        #
        #    Group Name                             Type             SID          Attributes
        #    ====================================== ================ ============ ==================================================
        #    Everyone                               Well-known group S-1-1-0      Mandatory group, Enabled by default, Enabled group
        #    BUILTIN\Users                          Alias            S-1-5-32-545 Mandatory group, Enabled by default, Enabled group
        #    NT AUTHORITY\INTERACTIVE               Well-known group S-1-5-4      Mandatory group, Enabled by default, Enabled group
        #    CONSOLE LOGON                          Well-known group S-1-2-1      Mandatory group, Enabled by default, Enabled group
        #    NT AUTHORITY\Authenticated Users       Well-known group S-1-5-11     Mandatory group, Enabled by default, Enabled group
        #    NT AUTHORITY\This Organization         Well-known group S-1-5-15     Mandatory group, Enabled by default, Enabled group
        #    NT AUTHORITY\Local account             Well-known group S-1-5-113    Mandatory group, Enabled by default, Enabled group
        #    LOCAL                                  Well-known group S-1-2-0      Mandatory group, Enabled by default, Enabled group
        #    NT AUTHORITY\NTLM Authentication       Well-known group S-1-5-64-10  Mandatory group, Enabled by default, Enabled group
        #    Mandatory Label\Medium Mandatory Level Label            S-1-16-8192
        #
        #
        #    PRIVILEGES INFORMATION
        #    ----------------------
        #
        #    Privilege Name                Description                    State
        #    ============================= ============================== ========
        #    SeChangeNotifyPrivilege       Bypass traverse checking       Enabled
        #    SeIncreaseWorkingSetPrivilege Increase a process working set Disabled
        #
        # and here we mimic most of them when launching our test application.
        $suPath = './local/su.exe'
        $suArgs = @(
          "-u", $username,
          "-o", $username,
          "-p", $username,
          "-g", "Everyone", "0x1", "0",
          "-g", "BUILTIN\Users", "0x1", "0",
          #"-g", "NT AUTHORITY\INTERACTIVE", "0x1", "0",
          #"-g", "CONSOLE LOGON", "0x1", "0",
          "-g", "NT AUTHORITY\Authenticated Users", "0x1", "0",
          "-g", "NT AUTHORITY\This Organization", "0x1", "0",
          "-g", "NT AUTHORITY\Local account", "0x1", "0",
          "-g", "LOCAL", "0x1", "0",
          #"-g", "NT AUTHORITY\NTLM Authentication", "0x1", "0",
          "-g", "Mandatory Label\Medium Mandatory Level", "0x1", "0",
          # see SE_CHANGE_NOTIFY_VALUE	 0x0000000000400000 at https://github.com/rgl/WinSudo/blob/664f624a17880a3fcf349884839231b22428131a/PrivilegeHelps/bsdef.h#L78
          # see SE_INC_WORKING_SET_VALUE 0x0000000100000000 at https://github.com/rgl/WinSudo/blob/664f624a17880a3fcf349884839231b22428131a/PrivilegeHelps/bsdef.h#L88
          "-P", "0x0000000100400000",
          "-c", "PowerShell.exe", "-File", "local/example.ps1"
        )
        Write-Output "Executing $(@($suPath, $suArgs) | ConvertTo-Json -Compress)..."
        Write-Output "NB This ONLY works after you manually login into the $env:COMPUTERNAME machine with the $username user"
        &$suPath @suArgs
        EOD
      }
      config {
        command = "local/damon.exe"
        args = [
          "PowerShell.exe",
          "-File",
          "local/su.ps1"
        ]
      }
      resources {
        cpu = 1000
        memory = 350
      }
    }
  }
}
