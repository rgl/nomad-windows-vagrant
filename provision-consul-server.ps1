param(
    $ipAddress = '10.11.0.101',
    $server1IpAddress = '10.11.0.101',
    $bootstrapExpect = 1
)

Import-Module Carbon
Import-Module "$env:ChocolateyInstall\helpers\chocolateyInstaller.psm1"

$serviceHome = 'C:\consul-server'
$serviceName = 'consul-server'
$serviceUsername = "NT SERVICE\$serviceName"

# install consul-server.
$archiveUrl = 'https://releases.hashicorp.com/consul/1.9.0/consul_1.9.0_windows_amd64.zip'
$archiveHash = '1cd7736b799a8c2ab1efd57020037a40f51061bac3bee07a518c8a4c87eb965d'
$archiveName = Split-Path $archiveUrl -Leaf
$archivePath = "$env:TEMP\$archiveName"
Write-Host 'Downloading consul-server...'
(New-Object Net.WebClient).DownloadFile($archiveUrl, $archivePath)
$archiveActualHash = (Get-FileHash $archivePath -Algorithm SHA256).Hash
if ($archiveHash -ne $archiveActualHash) {
    throw "$archiveName downloaded from $archiveUrl to $archivePath has $archiveActualHash hash witch does not match the expected $archiveHash"
}
Write-Host 'Installing consul-server...'
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
# see https://learn.hashicorp.com/tutorials/consul/windows-agent
$result = sc.exe create $serviceName binPath="$serviceHome\bin\consul.exe agent -config-dir=$serviceHome\config" start= auto
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
    "$serviceHome\config\consul-server.hcl" `
    (
        (Get-Content consul-server.hcl) `
            -replace '@@data_dir@@',(ConvertTo-Json -Depth 100 -Compress "$serviceHome\data") `
            -replace '@@bootstrap_expect@@',"$bootstrapExpect" `
            -replace '@@log_file@@',(ConvertTo-Json -Depth 100 -Compress "$serviceHome\logs\consul-server.log") `
            -replace '@@ip_address@@',(ConvertTo-Json -Depth 100 -Compress "$ipAddress") `
            -replace '@@server1_ip_address@@',(ConvertTo-Json -Depth 100 -Compress "$server1IpAddress")
    )

# configure the firewall.
@(
    ,@('server', 8300, 'tcp')
    ,@('serf_lan', 8301, 'tcp')
    ,@('serf_lan', 8301, 'udp')
    ,@('serf_wan', 8302, 'tcp')
    ,@('serf_wan', 8302, 'udp')
    ,@('http', 8500, 'tcp')
    ,@('dns', 8600, 'tcp')
    ,@('dns', 8600, 'udp')
) | ForEach-Object {
    if ($_[2] -eq 'tcp') {
        New-NetFirewallRule `
            -Name "consul-server-in-tcp-$($_[0])" `
            -DisplayName "Consul Server $($_[0]) (TCP-In)" `
            -Direction Inbound `
            -Enabled True `
            -Protocol TCP `
            -LocalPort $_[1] `
            | Out-Null
    } elseif ($_[2] -eq 'udp') {
        New-NetFirewallRule `
            -Name "consul-server-in-udp-$($_[0])" `
            -DisplayName "Consul Server $($_[0]) (UDP-In)" `
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

# show information.
Write-Title 'consul version'
consul --version
Write-Title 'consul info'
consul info
Write-Title 'consul members'
consul members
