$cookiePath = 'C:\vagrant\shared\vault-server-configured.txt'

# bail when already configured.
if (Test-Path $cookiePath) {
    Exit 0
}

choco install -y jq

$env:VAULT_ADDR = "http://active.vault.service.consul:8200"

# enable auditing to stdout (use journalctl -u vault to see it).
# see https://www.vaultproject.io/docs/commands/audit/enable.html
# see https://www.vaultproject.io/docs/audit/file.html
vault audit enable file file_path=stdout log_raw=true
vault audit list

# enable the kv 2 secrets engine.
vault secrets enable -version=2 -path=secret kv

# create example secrets.
# see https://www.vaultproject.io/docs/commands/read-write.html
Write-Output 'abracadabra' | vault kv put secret/example password=- other_key=value
Write-Output '123456789' | vault kv put secret/another-example password=- other_key=example-value
vault kv get -format=json secret/example    # read all the fields as json.
vault kv get secret/example                 # read all the fields.
vault kv get -field=password secret/example # read just the password field.

# create cookie file that notes that we already have configured vault.
Set-Content -Encoding Ascii $cookiePath 'yes'
