$cookiePath = 'C:\vagrant\shared\vault-server-configured-go-info.txt'

# bail when already configured.
if (Test-Path $cookiePath) {
    Exit 0
}

choco install -y jq

$env:VAULT_ADDR = "http://active.vault.service.consul:8200"
$env:VAULT_TOKEN = Get-Content -Encoding Ascii C:\vagrant\shared\vault-root-token.txt

# create the policy for the go-info example.
@"
path "secret/data/example" {
    capabilities = ["read"]
}

path "secret/data/another-example" {
    capabilities = ["read"]
}
"@ | vault policy write go-info -

# create cookie file that notes that we already have configured vault.
Set-Content -Encoding Ascii $cookiePath 'yes'
