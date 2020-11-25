param(
    $ipAddress = '10.11.0.101',
    $server1IpAddress = '10.11.0.101',
    $bootstrapExpect = 1
)

Import-Module Carbon
Import-Module "$env:ChocolateyInstall\helpers\chocolateyInstaller.psm1"

$serviceHome = 'C:\nomad-server'
$serviceName = 'nomad-server'
$serviceUsername = "NT SERVICE\$serviceName"

# install nomad-server.
$archiveUrl = 'https://releases.hashicorp.com/nomad/1.0.0-beta3/nomad_1.0.0-beta3_windows_amd64.zip'
$archiveHash = '79173fbf48c91d3cc1f8519f4daa605ea0453c5282faddf01b69da1bcdabf4ee'
$archiveName = Split-Path $archiveUrl -Leaf
$archivePath = "$env:TEMP\$archiveName"
Write-Host 'Downloading nomad-server...'
(New-Object Net.WebClient).DownloadFile($archiveUrl, $archivePath)
$archiveActualHash = (Get-FileHash $archivePath -Algorithm SHA256).Hash
if ($archiveHash -ne $archiveActualHash) {
    throw "$archiveName downloaded from $archiveUrl to $archivePath has $archiveActualHash hash witch does not match the expected $archiveHash"
}
Write-Host 'Installing nomad-server...'
mkdir -Force "$serviceHome\bin" | Out-Null
Get-ChocolateyUnzip -FileFullPath $archivePath -Destination "$serviceHome\bin"
Remove-Item $archivePath

# add to the Machine PATH.
[Environment]::SetEnvironmentVariable(
    'PATH',
    "$([Environment]::GetEnvironmentVariable('PATH', 'Machine'));$serviceHome\bin",
    'Machine')
# add docker to the current process PATH.
$env:PATH += ";$serviceHome\bin"

# install the service.
# see https://www.nomadproject.io/docs/install/windows-service
$result = sc.exe create $serviceName binPath="$serviceHome\bin\nomad.exe agent -config=$serviceHome\config" start= auto
if ($result -ne '[SC] CreateService SUCCESS') {
    throw "sc.exe create failed with $result"
}
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
    'data'
) | ForEach-Object {
    mkdir -Force "$serviceHome\$_" | Out-Null
    Grant-Permission "$serviceHome\$_" $serviceUsername FullControl
}
mkdir -Force "$serviceHome\config" | Out-Null
Set-Content `
    -Encoding Ascii `
    "$serviceHome\config\nomad-server.hcl" `
    (
        (Get-Content nomad-server.hcl) `
            -replace '@@data_dir@@',(ConvertTo-Json -Depth 100 -Compress "$serviceHome\data") `
            -replace '@@bootstrap_expect@@',"$bootstrapExpect" `
            -replace '@@log_file@@',(ConvertTo-Json -Depth 100 -Compress "$serviceHome\logs\nomad-server.log") `
            -replace '@@ip_address@@',(ConvertTo-Json -Depth 100 -Compress "$ipAddress") `
            -replace '@@server1_ip_address@@',(ConvertTo-Json -Depth 100 -Compress "$server1IpAddress")
    )

# configure the firewall.
@(
    @('http', 4646),
    @('rpc', 4647),
    @('serf', 4648)
) | ForEach-Object {
    New-NetFirewallRule `
        -Name "nomad-server-in-tcp-$($_[0])" `
        -DisplayName "Nomad Server $($_[0]) (TCP-In)" `
        -Direction Inbound `
        -Enabled True `
        -Protocol TCP `
        -LocalPort $_[1] `
        | Out-Null
}

# start the service.
Start-Service $serviceName

# show information.
Write-Title 'nomad version'
nomad version
Write-Title 'nomad agent-info'
nomad agent-info