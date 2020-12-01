Import-Module Carbon
Import-Module "$env:ChocolateyInstall\helpers\chocolateyInstaller.psm1"

$grafanaHome = 'C:/grafana'
$grafanaServiceName = 'grafana'
$grafanaServiceUsername = "NT SERVICE\$grafanaServiceName"

# create the windows service using a managed service account.
Write-Host "Creating the $grafanaServiceName service..."
nssm install $grafanaServiceName $grafanaHome\bin\grafana-server.exe
nssm set $grafanaServiceName AppParameters `
    "--config=$grafanaHome/conf/grafana.ini"
nssm set $grafanaServiceName AppDirectory $grafanaHome
nssm set $grafanaServiceName Start SERVICE_AUTO_START
nssm set $grafanaServiceName AppRotateFiles 1
nssm set $grafanaServiceName AppRotateOnline 1
nssm set $grafanaServiceName AppRotateSeconds 86400
nssm set $grafanaServiceName AppRotateBytes 1048576
nssm set $grafanaServiceName AppStdout $grafanaHome\logs\$grafanaServiceName-stdout.log
nssm set $grafanaServiceName AppStderr $grafanaHome\logs\$grafanaServiceName-stderr.log
$result = sc.exe sidtype $grafanaServiceName unrestricted
if ($result -ne '[SC] ChangeServiceConfig2 SUCCESS') {
    throw "sc.exe sidtype failed with $result"
}
$result = sc.exe config $grafanaServiceName obj= $grafanaServiceUsername
if ($result -ne '[SC] ChangeServiceConfig SUCCESS') {
    throw "sc.exe config failed with $result"
}
$result = sc.exe failure $grafanaServiceName reset= 0 actions= restart/1000
if ($result -ne '[SC] ChangeServiceConfig2 SUCCESS') {
    throw "sc.exe failure failed with $result"
}

# download and install grafana.
# see https://grafana.com/grafana/download?platform=windows
$archiveUrl = 'https://dl.grafana.com/oss/release/grafana-7.3.4.windows-amd64.zip'
$archiveHash = '9e1614cf3ceaa4c18f0cc0d111adca75eb77b6d019004cd0c75bb723ca4ffc57'
$archiveName = Split-Path $archiveUrl -Leaf
$archivePath = "$env:TEMP\$archiveName"
Write-Host 'Downloading Grafana...'
(New-Object Net.WebClient).DownloadFile($archiveUrl, $archivePath)
$archiveActualHash = (Get-FileHash $archivePath -Algorithm SHA256).Hash
if ($archiveHash -ne $archiveActualHash) {
    throw "$archiveName downloaded from $archiveUrl to $archivePath has $archiveActualHash hash witch does not match the expected $archiveHash"
}
Write-Host 'Installing Grafana...'
Get-ChocolateyUnzip -FileFullPath $archivePath -Destination $grafanaHome
$grafanaArchiveTempPath = Resolve-Path $grafanaHome\grafana-*
Move-Item $grafanaArchiveTempPath\* $grafanaHome
Remove-Item $grafanaArchiveTempPath
Remove-Item $archivePath
'logs','data' | ForEach-Object {
    mkdir $grafanaHome/$_ | Out-Null
    Disable-AclInheritance $grafanaHome/$_
    Grant-Permission $grafanaHome/$_ Administrators FullControl
    Grant-Permission $grafanaHome/$_ $grafanaServiceUsername FullControl
}
Disable-AclInheritance $grafanaHome/conf
Grant-Permission $grafanaHome/conf Administrators FullControl
Grant-Permission $grafanaHome/conf $grafanaServiceUsername Read
Copy-Item c:/vagrant/grafana.ini $grafanaHome/conf

Write-Host "Starting the $grafanaServiceName service..."
Start-Service $grafanaServiceName

$apiBaseUrl = 'http://localhost:3000/api'
$apiAuthorizationHeader = "Basic $([Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes('admin:admin')))"

function Invoke-GrafanaApi($relativeUrl, $body, $method='Post') {
    Invoke-RestMethod `
        -Method $method `
        -Uri $apiBaseUrl/$relativeUrl `
        -ContentType 'application/json' `
        -Headers @{
            Authorization = $apiAuthorizationHeader
        } `
        -Body (ConvertTo-Json -Depth 100 $body)
}

function Wait-ForGrafanaReady {
    Wait-ForCondition {
        $health = Invoke-RestMethod `
            -Method Get `
            -Uri $apiBaseUrl/health
        $health.database -eq 'ok'
    }
}

function New-GrafanaDataSource($body) {
    Invoke-GrafanaApi datasources $body
}

function New-GrafanaDashboard($body) {
    Invoke-GrafanaApi dashboards/db $body
}

Write-Host 'Waiting for Grafana to be ready...'
Wait-ForGrafanaReady

# create a data source for the local prometheus server.
Write-Host 'Creating the Prometheus Data Source...'
function Get-PrometheusSimpleSetting($name) {
    $r = [regex]::new("^\s+$([regex]::Escape($name)):\s*(\d+[a-z])")
    ((Get-Content 'prometheus.yml') -match $r)[0] -match $r | Out-Null
    $Matches[1]
}
New-GrafanaDataSource @{
    name = 'Prometheus'
    type = 'prometheus'
    url = 'http://server1:9090'
    access = 'direct'
    basicAuth = $false
    jsonData = @{
        httpMethod = 'GET'
        timeInterval = Get-PrometheusSimpleSetting 'scrape_interval'
        queryTimeout = Get-PrometheusSimpleSetting 'scrape_timeout'
    }
} | ConvertTo-Json

# configure the firewall.
@(
    ,@('http', 3000)
) | ForEach-Object {
    New-NetFirewallRule `
        -Name "grafana-in-tcp-$($_[0])" `
        -DisplayName "Grafana $($_[0]) (TCP-In)" `
        -Direction Inbound `
        -Enabled True `
        -Protocol TCP `
        -LocalPort $_[1] `
        | Out-Null
}
