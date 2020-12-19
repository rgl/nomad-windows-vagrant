param(
    $ipAddress = '10.11.0.101',
    $initializeVaultServer = 'true'
)

$initializeVaultServer = $initializeVaultServer -eq 'true'

choco install -y nssm

Import-Module Carbon
Import-Module "$env:ChocolateyInstall\helpers\chocolateyInstaller.psm1"

$serviceHome = 'C:\vault-server'
$serviceName = 'vault-server'
$serviceUsername = "NT SERVICE\$serviceName"

# install vault-server.
$archiveUrl = 'https://releases.hashicorp.com/vault/1.6.1/vault_1.6.1_windows_amd64.zip'
$archiveHash = '4a9b0c803098e745f22bdd510205803ceb4c800fb9c89810c784b6a9e9abc4a4'
$archiveName = Split-Path $archiveUrl -Leaf
$archivePath = "$env:TEMP\$archiveName"
Write-Host 'Downloading vault-server...'
(New-Object Net.WebClient).DownloadFile($archiveUrl, $archivePath)
$archiveActualHash = (Get-FileHash $archivePath -Algorithm SHA256).Hash
if ($archiveHash -ne $archiveActualHash) {
    throw "$archiveName downloaded from $archiveUrl to $archivePath has $archiveActualHash hash witch does not match the expected $archiveHash"
}
Write-Host 'Installing vault-server...'
mkdir -Force "$serviceHome\bin" | Out-Null
Get-ChocolateyUnzip -FileFullPath $archivePath -Destination "$serviceHome\bin"
Remove-Item $archivePath

# add to the Machine PATH.
[Environment]::SetEnvironmentVariable(
    'PATH',
    "$([Environment]::GetEnvironmentVariable('PATH', 'Machine'));$serviceHome\bin",
    'Machine')
# add to the current process PATH.
$env:PATH += ";$serviceHome\bin"

# install the service.
# see https://learn.hashicorp.com/tutorials/vault/windows-agent
# NB vault 1.6.0 does not yet have a windows service; later versions will
#    probably have a native windows service because the master bransh has:
#       https://github.com/hashicorp/vault/blob/master/command/agent/winsvc/service_windows.go
nssm install $serviceName $serviceHome\bin\vault.exe
nssm set $serviceName Start SERVICE_AUTO_START
nssm set $serviceName AppRotateFiles 1
nssm set $serviceName AppRotateOnline 1
nssm set $serviceName AppRotateSeconds 86400
nssm set $serviceName AppRotateBytes 1048576
nssm set $serviceName AppStdout $serviceHome\logs\$serviceName-stdout.log
nssm set $serviceName AppStderr $serviceHome\logs\$serviceName-stderr.log
nssm set $serviceName AppDirectory $serviceHome
nssm set $serviceName AppParameters `
    "server" `
    "-config=$serviceHome\config\vault.hcl"
$result = sc.exe sidtype $serviceName unrestricted
if ($result -ne '[SC] ChangeServiceConfig2 SUCCESS') {
    throw "sc.exe sidtype failed with $result"
}
$result = sc.exe config $serviceName obj= $serviceUsername
if ($result -ne '[SC] ChangeServiceConfig SUCCESS') {
    throw "sc.exe config failed with $result"
}
$result = sc.exe failure $serviceName reset= 0 actions= restart/60000
if ($result -ne '[SC] ChangeServiceConfig2 SUCCESS') {
    throw "sc.exe failure failed with $result"
}

# create the configuration.
Disable-AclInheritance $serviceHome
Grant-Permission $serviceHome SYSTEM FullControl
Grant-Permission $serviceHome Administrators FullControl
Grant-Permission $serviceHome $serviceUsername ReadAndExecute
@(
    'logs'
) | ForEach-Object {
    mkdir -Force "$serviceHome\$_" | Out-Null
    Grant-Permission "$serviceHome\$_" $serviceUsername FullControl
}
mkdir -Force "$serviceHome\config" | Out-Null
Set-Content `
    -Encoding Ascii `
    "$serviceHome\config\vault.hcl" `
    (
        (Get-Content vault-server.hcl) `
            -replace '@@api_addr@@',(ConvertTo-Json -Depth 100 -Compress "http://$ipAddress`:8200") `
            -replace '@@cluster_addr@@',(ConvertTo-Json -Depth 100 -Compress "http://$ipAddress`:8201")
    )

# configure the firewall.
@(
    ,@('api', 8200, 'tcp')
    ,@('server', 8201, 'tcp')
) | ForEach-Object {
    if ($_[2] -eq 'tcp') {
        New-NetFirewallRule `
            -Name "vault-server-in-tcp-$($_[0])" `
            -DisplayName "Vault $($_[0]) (TCP-In)" `
            -Direction Inbound `
            -Enabled True `
            -Protocol TCP `
            -LocalPort $_[1] `
            | Out-Null
    } elseif ($_[2] -eq 'udp') {
        New-NetFirewallRule `
            -Name "vault-server-in-udp-$($_[0])" `
            -DisplayName "Vault $($_[0]) (UDP-In)" `
            -Direction Inbound `
            -Enabled True `
            -Protocol UDP `
            -LocalPort $_[1] `
            | Out-Null
    } else {
        throw "unknown protocol $($_[2])"
    }
}

# start the service.
Start-Service $serviceName

# init vault-server.
# NB vault-operator-init-result.txt will have something like:
#       Unseal Key 1: sXiqMfCPiRNGvo+tEoHVGy+FHFW092H7vfOY0wPrzpYh
#       Unseal Key 2: dCm5+NhacPcX6GwI0IMMK+CM0xL6wif5/k0LJ0XTPHhy
#       Unseal Key 3: YjbM3TANam0dO9FTa0y/2wj7nxnlDyct7oVMksHs7trE
#       Unseal Key 4: CxWG0yrF75cIYsKvWQBku8klN9oPaPJDWqO7l7LNWX2A
#       Unseal Key 5: C+ttQv3KeViOkIxVZH7gXuZ7iZPKi0va1/lUBSiMeyLz
#       Initial Root Token: d2bb2175-2264-d18b-e8d8-18b1d8b61278
#
#       Vault initialized with 5 keys and a key threshold of 3. Please
#       securely distribute the above keys. When the vault is re-sealed,
#       restarted, or stopped, you must provide at least 3 of these keys
#       to unseal it again.
#
#       Vault does not store the master key. Without at least 3 keys,
#       your vault will remain permanently sealed.
if ($initializeVaultServer) {
    $env:VAULT_ADDR = "http://localhost:8200"
    Push-Location ~
    vault operator init >vault-operator-init-result.txt
    Get-Content vault-operator-init-result.txt `
        | ForEach-Object {
            if ($_ -match 'Initial Root Token: (.+)') {
                $Matches[1]
            }
        } `
        | Select-Object -First 3 `
        | Set-Content `
            -Encoding Ascii `
            .vault-token
    mkdir -Force C:\vagrant\shared | Out-Null
    Copy-Item vault-operator-init-result.txt C:\vagrant\shared\vault-operator-init-result.txt
    Copy-Item .vault-token C:\vagrant\shared\vault-root-token.txt
    Pop-Location
}

# show information.
Write-Title 'vault version'
vault -version
Write-Title 'vault info'
vault status
