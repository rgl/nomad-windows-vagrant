$cookiePath = 'C:\vagrant\shared\vault-server-configured-postgresql.txt'

# bail when already configured.
if (Test-Path $cookiePath) {
    Exit 0
}

choco install -y jq

$env:VAULT_ADDR = "http://active.vault.service.consul:8200"
$env:VAULT_TOKEN = Get-Content -Encoding Ascii C:\vagrant\shared\vault-root-token.txt

# enable the database secrets engine.
# NB this is needed by our examples.
vault secrets enable database

# configure the greetings PostgreSQL database.
# see https://learn.hashicorp.com/vault/secrets-management/sm-dynamic-secrets#postgresql
# see https://learn.hashicorp.com/vault/secrets-management/db-root-rotation
# see https://www.postgresql.org/docs/13/libpq-connect.html#LIBPQ-CONNSTRING
# see https://www.postgresql.org/docs/13/sql-createrole.html
# see https://www.postgresql.org/docs/13/sql-grant.html
# see https://www.vaultproject.io/docs/secrets/databases/postgresql.html
# see https://www.vaultproject.io/api/secret/databases/postgresql.html
vault write database/config/greetings `
    'plugin_name=postgresql-database-plugin' `
    'allowed_roles=greetings-admin,greetings-reader' `
    'connection_url=postgresql://{{username}}:{{password}}@postgresql.service.consul:5432/greetings?sslmode=disable' `
    'username=postgres' `
    'password=postgres'
#vault write -force database/rotate-root/greetings # immediatly rotate the root password (in this case, the vault username password).
vault read -format=json database/config/greetings | jq .data
# configure the greetings-admin role.
$creationStatements = @'
create role \"{{name}}\" with login password '{{password}}' valid until '{{expiration}}';
grant all privileges on all tables in schema public to \"{{name}}\";
'@
# NB db_name must match the database/config/:db_name
vault write database/roles/greetings-admin `
    'db_name=greetings' `
    "creation_statements=$creationStatements" `
    'default_ttl=1h' `
    'max_ttl=24h'
vault read -format=json database/roles/greetings-admin | jq .data
# configure the greetings-reader role.
$creationStatements = @'
create role \"{{name}}\" with login password '{{password}}' valid until '{{expiration}}';
grant select on all tables in schema public to \"{{name}}\";
'@
# NB db_name must match the database/config/:db_name
vault write database/roles/greetings-reader `
    'db_name=greetings' `
    "creation_statements=$creationStatements" `
    'default_ttl=1h' `
    'max_ttl=24h'
vault read -format=json database/roles/greetings-reader | jq .data
echo 'You can create a user to administer the greetings database with: vault read database/creds/greetings-admin'
echo 'You can create a user to access the greetings database with: vault read database/creds/greetings-reader'

# list database connections/names.
vault list -format=json database/config

# create cookie file that notes that we already have configured vault.
Set-Content -Encoding Ascii $cookiePath 'yes'
