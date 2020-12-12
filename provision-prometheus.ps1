param (
    [int]$numberOfServerNodes,
    [int]$numberOfClientNodes
)

choco install -y nssm

Import-Module Carbon
Import-Module "$env:ChocolateyInstall\helpers\chocolateyInstaller.psm1"

$prometheusHome = 'C:/prometheus'
$prometheusServiceName = 'prometheus'
$prometheusServiceUsername = "NT SERVICE\$prometheusServiceName"

# download and install prometheus.
$archiveUrl = 'https://github.com/prometheus/prometheus/releases/download/v2.23.0/prometheus-2.23.0.windows-amd64.zip'
$archiveHash = 'd032e4597c137d8f39effc459a94d533a0c3135ff8ed7eae5b0a7c540b61985c'
$archiveName = Split-Path $archiveUrl -Leaf
$archivePath = "$env:TEMP\$archiveName"
Write-Host 'Downloading Prometheus...'
(New-Object Net.WebClient).DownloadFile($archiveUrl, $archivePath)
$archiveActualHash = (Get-FileHash $archivePath -Algorithm SHA256).Hash
if ($archiveHash -ne $archiveActualHash) {
    throw "$archiveName downloaded from $archiveUrl to $archivePath has $archiveActualHash hash witch does not match the expected $archiveHash"
}
Write-Host 'Installing Prometheus...'
Get-ChocolateyUnzip -FileFullPath $archivePath -Destination $prometheusHome
$prometheusArchiveTempPath = Resolve-Path $prometheusHome\prometheus-*
Move-Item $prometheusArchiveTempPath\* $prometheusHome
Remove-Item $prometheusArchiveTempPath
Remove-Item $archivePath

$prometheusInstallHome = $prometheusHome

# configure the windows service using a managed service account.
Write-Host "Configuring the $prometheusServiceName service..."
nssm install $prometheusServiceName $prometheusInstallHome\prometheus.exe
nssm set $prometheusServiceName Start SERVICE_AUTO_START
nssm set $prometheusServiceName AppRotateFiles 1
nssm set $prometheusServiceName AppRotateOnline 1
nssm set $prometheusServiceName AppRotateSeconds 86400
nssm set $prometheusServiceName AppRotateBytes 1048576
nssm set $prometheusServiceName AppStdout $prometheusHome\logs\service-stdout.log
nssm set $prometheusServiceName AppStderr $prometheusHome\logs\service-stderr.log
nssm set $prometheusServiceName AppDirectory $prometheusInstallHome
nssm set $prometheusServiceName AppParameters `
    "--config.file=$prometheusHome/prometheus.yml" `
    "--storage.tsdb.path=$prometheusHome/data" `
    "--storage.tsdb.retention=$(7*24)h" `
    "--web.console.libraries=$prometheusInstallHome/console_libraries" `
    "--web.console.templates=$prometheusInstallHome/consoles" `
    '--web.listen-address=0.0.0.0:9090' `
    '--web.external-url=http://server1:9090'
$result = sc.exe sidtype $prometheusServiceName unrestricted
if ($result -ne '[SC] ChangeServiceConfig2 SUCCESS') {
    throw "sc.exe sidtype failed with $result"
}
$result = sc.exe config $prometheusServiceName obj= $prometheusServiceUsername
if ($result -ne '[SC] ChangeServiceConfig SUCCESS') {
    throw "sc.exe config failed with $result"
}
$result = sc.exe failure $prometheusServiceName reset= 0 actions= restart/1000
if ($result -ne '[SC] ChangeServiceConfig2 SUCCESS') {
    throw "sc.exe failure failed with $result"
}

Disable-AclInheritance $prometheusHome
Grant-Permission $prometheusHome SYSTEM FullControl
Grant-Permission $prometheusHome Administrators FullControl
Grant-Permission $prometheusHome $prometheusServiceUsername ReadAndExecute
$config = Get-Content -Raw c:/vagrant/prometheus.yml
function Get-Targets($placeholder, $port) {
    if (!($config -match "(.+)$placeholder")) {
        throw "c:/vagrant/prometheus.yml must have a $placeholder placeholder"
    }
    $prefix = $Matches[1]
    @(
        (1..$numberOfServerNodes) | ForEach-Object {"server$_`:$port"}
        (1..$numberOfClientNodes) | ForEach-Object {"client$_`:$port"}
    ) | ForEach-Object {"$prefix- $_"}
}
Set-Content -Encoding Ascii "$prometheusHome\prometheus.yml" (
    $config `
        -replace '(.+)@@consul_targets@@',$((Get-Targets '@@consul_targets@@' 8500) -join "`n") `
        -replace '(.+)@@vault_targets@@',$((Get-Targets '@@vault_targets@@' 8200) -join "`n") `
        -replace '(.+)@@nomad_targets@@',$((Get-Targets '@@nomad_targets@@' 4646) -join "`n")
)
'data','logs' | ForEach-Object {
    mkdir $prometheusHome/$_ | Out-Null
    Disable-AclInheritance $prometheusHome/$_
    Grant-Permission $prometheusHome/$_ SYSTEM FullControl
    Grant-Permission $prometheusHome/$_ Administrators FullControl
    Grant-Permission $prometheusHome/$_ $prometheusServiceUsername FullControl
}

Write-Host "Checking the prometheus configuration..."
&"$prometheusInstallHome\promtool.exe" check config $prometheusHome/prometheus.yml

# configure the firewall.
@(
    ,@('http', 9090)
) | ForEach-Object {
    New-NetFirewallRule `
        -Name "prometheus-in-tcp-$($_[0])" `
        -DisplayName "Prometheus $($_[0]) (TCP-In)" `
        -Direction Inbound `
        -Enabled True `
        -Protocol TCP `
        -LocalPort $_[1] `
        | Out-Null
}

Write-Host "Starting the $prometheusServiceName service..."
Start-Service $prometheusServiceName
