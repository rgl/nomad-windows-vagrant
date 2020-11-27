param(
    $ipAddress = '10.11.0.201',
    $servers = @('10.11.0.101')
)

Import-Module Carbon
Import-Module "$env:ChocolateyInstall\helpers\chocolateyInstaller.psm1"

$networkInterface = (
        Get-NetAdapter -Physical `
            | Get-NetIPAddress -AddressFamily IPv4 `
            | Where-Object {$_.IPAddress -eq $ipAddress}
    ).InterfaceAlias

$serviceHome = 'C:\nomad-client'
$serviceName = 'nomad-client'

# install nomad-client.
$archiveUrl = 'https://releases.hashicorp.com/nomad/1.0.0-beta3/nomad_1.0.0-beta3_windows_amd64.zip'
$archiveHash = '79173fbf48c91d3cc1f8519f4daa605ea0453c5282faddf01b69da1bcdabf4ee'
$archiveName = Split-Path $archiveUrl -Leaf
$archivePath = "$env:TEMP\$archiveName"
Write-Host 'Downloading nomad-client...'
(New-Object Net.WebClient).DownloadFile($archiveUrl, $archivePath)
$archiveActualHash = (Get-FileHash $archivePath -Algorithm SHA256).Hash
if ($archiveHash -ne $archiveActualHash) {
    throw "$archiveName downloaded from $archiveUrl to $archivePath has $archiveActualHash hash witch does not match the expected $archiveHash"
}
Write-Host 'Installing nomad-client...'
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
# see https://www.nomadproject.io/docs/install/windows-service
$result = sc.exe create $serviceName binPath="$serviceHome\bin\nomad.exe agent -config=$serviceHome\config" start= auto
if ($result -ne '[SC] CreateService SUCCESS') {
    throw "sc.exe create failed with $result"
}
$result = sc.exe failure $serviceName reset= 0 actions= restart/60000
if ($result -ne '[SC] ChangeServiceConfig2 SUCCESS') {
    throw "sc.exe failure failed with $result"
}

# create the configuration.
Disable-AclInheritance $serviceHome
Grant-Permission $serviceHome SYSTEM FullControl
Grant-Permission $serviceHome Administrators FullControl
mkdir -Force "$serviceHome\logs" | Out-Null
mkdir -Force "$serviceHome\data" | Out-Null
mkdir -Force "$serviceHome\config" | Out-Null
Set-Content `
    -Encoding Ascii `
    "$serviceHome\config\nomad-client.hcl" `
    (
        (Get-Content nomad-client.hcl) `
            -replace '@@data_dir@@',(ConvertTo-Json -Depth 100 -Compress "$serviceHome\data") `
            -replace '@@log_file@@',(ConvertTo-Json -Depth 100 -Compress "$serviceHome\logs\nomad-client.log") `
            -replace '@@ip_address@@',(ConvertTo-Json -Depth 100 -Compress "$ipAddress") `
            -replace '@@network_interface@@',(ConvertTo-Json -Depth 100 -Compress "$networkInterface") `
            -replace '@@servers@@',(ConvertTo-Json -Depth 100 -Compress @($servers))
    )

# configure the firewall.
@(
    ,@('http', 4646, 'tcp')
) | ForEach-Object {
    if ($_[2] -eq'tcp') {
        New-NetFirewallRule `
            -Name "nomad-client-in-tcp-$($_[0])" `
            -DisplayName "Nomad Client $($_[0]) (TCP-In)" `
            -Direction Inbound `
            -Enabled True `
            -Protocol TCP `
            -LocalPort $_[1] `
            | Out-Null
    } else {
        throw "unknown protocol $($_[2])"
    }
}

# start the service.
Start-Service $serviceName

# wait for nomad to be avaiable.
while (!(Test-NetConnection localhost -Port 4646).TcpTestSucceeded) {
    Start-Sleep -Seconds 3
}

# show information.
Write-Title 'nomad version'
nomad version
Write-Title 'nomad agent-info'
nomad agent-info
Write-Title 'nomad server members'
nomad server members
Write-Title 'nomad node status'
nomad node status
