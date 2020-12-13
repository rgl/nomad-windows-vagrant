param(
    $ipAddress = '10.11.0.201',
    $servers = @('10.11.0.101')
)

Import-Module Carbon
Import-Module "$env:ChocolateyInstall\helpers\chocolateyInstaller.psm1"

$serviceHome = 'C:\consul-client'
$serviceName = 'consul-client'
$serviceUsername = "NT SERVICE\$serviceName"

# install consul-client.
$archiveUrl = 'https://releases.hashicorp.com/consul/1.9.0/consul_1.9.0_windows_amd64.zip'
$archiveHash = '1cd7736b799a8c2ab1efd57020037a40f51061bac3bee07a518c8a4c87eb965d'
$archiveName = Split-Path $archiveUrl -Leaf
$archivePath = "$env:TEMP\$archiveName"
Write-Host 'Downloading consul-client...'
(New-Object Net.WebClient).DownloadFile($archiveUrl, $archivePath)
$archiveActualHash = (Get-FileHash $archivePath -Algorithm SHA256).Hash
if ($archiveHash -ne $archiveActualHash) {
    throw "$archiveName downloaded from $archiveUrl to $archivePath has $archiveActualHash hash witch does not match the expected $archiveHash"
}
Write-Host 'Installing consul-client...'
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

# get the machine current dns servers. they will be used as the consul
# dns recursors.
$recursors = (
        Get-NetAdapter -Physical `
            | Get-DnsClientServerAddress -AddressFamily IPv4
    ).ServerAddresses

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
    "$serviceHome\config\consul-client.hcl" `
    (
        (Get-Content consul-client.hcl) `
            -replace '@@data_dir@@',(ConvertTo-Json -Depth 100 -Compress "$serviceHome\data") `
            -replace '@@log_file@@',(ConvertTo-Json -Depth 100 -Compress "$serviceHome\logs\consul-client.log") `
            -replace '@@ip_address@@',(ConvertTo-Json -Depth 100 -Compress "$ipAddress") `
            -replace '@@servers@@',(ConvertTo-Json -Depth 100 -Compress @($servers)) `
            -replace '@@recursors@@',(ConvertTo-Json -Depth 100 -Compress @($recursors))
    )

# configure the firewall.
@(
    ,@('serf_lan', 8301, 'tcp')
    ,@('serf_lan', 8301, 'udp')
    ,@('http', 8500, 'tcp')
    ,@('dns', 53, 'tcp')
    ,@('dns', 53, 'udp')
) | ForEach-Object {
    if ($_[2] -eq 'tcp') {
        New-NetFirewallRule `
            -Name "consul-client-in-tcp-$($_[0])" `
            -DisplayName "Consul Server $($_[0]) (TCP-In)" `
            -Direction Inbound `
            -Enabled True `
            -Protocol TCP `
            -LocalPort $_[1] `
            | Out-Null
    } elseif ($_[2] -eq 'udp') {
        New-NetFirewallRule `
            -Name "consul-client-in-udp-$($_[0])" `
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

# configure this machine dns client to use the local consul client
# as its dns resolver.
Get-NetAdapter -Physical `
    | Set-DnsClientServerAddress -ServerAddresses '127.0.0.1'
# dito for docker.
# NB we have to use the server ip address because docker containers normally
#    have their own network interface, which means 127/8 resolves locally,
#    instead of going to the host.
# NB unfortunately this means we have to allow incomming connections to the
#    DNS port.
$config = Get-Content "$env:ProgramData\docker\config\daemon.json" | ConvertFrom-Json
$config | Add-Member -Force -MemberType NoteProperty -Name dns -Value @($ipAddress)
Set-Content -Encoding ascii "$env:ProgramData\docker\config\daemon.json" ($config | ConvertTo-Json -Depth 100)
Restart-Service docker

# show information.
Write-Title 'consul version'
consul --version
Write-Title 'consul info'
consul info
Write-Title 'consul members'
consul members
