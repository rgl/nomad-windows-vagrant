$serviceHome = 'C:\vault-server'
$serviceName = 'vault-server'
$autoUnsealPath = "$serviceHome\bin\auto-unseal.ps1"

if (Test-Path $autoUnsealPath) {
    Exit 0
}

# save the unseal keys.
# NB these were generated by provision-vault-server.ps1.
Get-Content C:\vagrant\shared\vault-operator-init-result.txt `
    | ForEach-Object {
        if ($_ -match 'Unseal Key [0-9]+: (.+)') {
            $Matches[1]
        }
    } `
    | Select-Object -First 3 `
    | Set-Content `
        -Encoding Ascii `
        "$serviceHome\config\unseal-keys.txt"

# configure the service to auto-unseal.
Set-Content -Encoding Ascii -Path $autoUnsealPath -Value @'
$env:VAULT_ADDR = "http://localhost:8200"
$env:PATH = "$env:PATH;$PSScriptRoot"
Get-Content "$PSScriptRoot\..\config\unseal-keys.txt" `
    | ForEach-Object {
        while ($true) {
            Write-Output "Auto Unsealing Vault..."
            vault operator unseal $_
            if ($LASTEXITCODE) {
                Start-Sleep -Seconds 5
            } else {
                break
            }
        }
    }
'@
nssm set $serviceName AppRedirectHook 1
nssm set $serviceName AppEvents `
    Start/Post `
    PowerShell.exe `
    -File $autoUnsealPath

# auto-unseal.
&$autoUnsealPath
