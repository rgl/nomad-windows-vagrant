param(
    $ipAddress = '10.11.0.201'
)

Import-Module "$env:ChocolateyInstall\helpers\chocolateyInstaller.psm1"

$serviceHome = 'C:\vault-client'
$env:VAULT_ADDR = "http://active.vault.service.consul:8200"

# install vault-client.
$archiveUrl = 'https://releases.hashicorp.com/vault/1.8.1/vault_1.8.1_windows_amd64.zip'
$archiveHash = '130e887a18de9a213418de45af190b95e157dbdbf08a9e2c33d4d53406a8791e'
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
