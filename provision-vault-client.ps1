param(
    $ipAddress = '10.11.0.201'
)

Import-Module "$env:ChocolateyInstall\helpers\chocolateyInstaller.psm1"

$serviceHome = 'C:\vault-client'
$env:VAULT_ADDR = "http://active.vault.service.consul:8200"

# install vault-client.
$archiveUrl = 'https://releases.hashicorp.com/vault/1.6.1/vault_1.6.1_windows_amd64.zip'
$archiveHash = '4a9b0c803098e745f22bdd510205803ceb4c800fb9c89810c784b6a9e9abc4a4'
$archiveName = Split-Path $archiveUrl -Leaf
$archivePath = "$env:TEMP\$archiveName"
Write-Host 'Downloading vault-client...'
(New-Object Net.WebClient).DownloadFile($archiveUrl, $archivePath)
$archiveActualHash = (Get-FileHash $archivePath -Algorithm SHA256).Hash
if ($archiveHash -ne $archiveActualHash) {
    throw "$archiveName downloaded from $archiveUrl to $archivePath has $archiveActualHash hash witch does not match the expected $archiveHash"
}
Write-Host 'Installing vault-client...'
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

# show information.
Write-Title 'vault version'
vault -version
Write-Title 'vault info'
vault status
