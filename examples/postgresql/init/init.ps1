# TODO run the postgres service as the ContainerUser user.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
trap {
    Write-Output "ERROR: $_"
    Write-Output (($_.ScriptStackTrace -split '\r?\n') -replace '^(.*)$','ERROR: $1')
    Write-Output (($_.Exception.ToString() -split '\r?\n') -replace '^(.*)$','ERROR EXCEPTION: $1')
    Exit 1
}

$serviceHome = 'c:/pgsql'
$serviceName = 'pgsql'
$serviceUsername = 'NT AUTHORITY\SYSTEM'
$servicePassword = 'ignored'

# the default postgres superuser username and password.
# see https://www.postgresql.org/docs/10/static/libpq-envars.html
$env:PGUSER = 'postgres'

function psql {
    &"$serviceHome/bin/psql.exe" -v ON_ERROR_STOP=1 -w @Args
    if ($LASTEXITCODE) {
        throw "psql failed with exit code $LASTEXITCODE"
    }
}

function pg_ctl {
    &"$serviceHome/bin/pg_ctl.exe" @Args
    if ($LASTEXITCODE) {
        throw "pg_ctl failed with exit code $LASTEXITCODE"
    }
}

function initdb {
    &"$serviceHome/bin/initdb.exe" @Args
    if ($LASTEXITCODE) {
        throw "initdb failed with exit code $LASTEXITCODE"
    }
}

if (!(Get-Service -ErrorAction SilentlyContinue $serviceName)) {
    Write-Output "Installing the $serviceName service..."
    pg_ctl `
        register `
        -N $serviceName `
        -U $serviceUsername `
        -P $servicePassword `
        -D $env:PGDATA `
        -S demand `
        -w
}

$initialize = !(Test-Path "$env:PGDATA\PG_VERSION")

if ($initialize) {
    # see https://www.postgresql.org/docs/13.1/static/creating-cluster.html
    Write-Host "Creating the Database Cluster in $env:PGDATA..."
    mkdir -Force $env:PGDATA | Out-Null
    $acl = New-Object System.Security.AccessControl.DirectorySecurity
    $acl.SetAccessRuleProtection($true, $false)
    @(
        $serviceUsername
        $env:USERNAME
        'Administrators'
    ) | ForEach-Object {
        $acl.AddAccessRule((
            New-Object `
                System.Security.AccessControl.FileSystemAccessRule(
                    $_,
                    'FullControl',
                    'ContainerInherit,ObjectInherit',
                    'None',
                    'Allow')))
    }
    Set-Acl $env:PGDATA $acl
    initdb `
        --username=$env:PGUSER `
        --auth-host=trust `
        --auth-local=reject `
        --encoding=UTF8 `
        --locale=en `
        -D $env:PGDATA

    Write-Host 'Configuring the listen address...'
    Set-Content -Encoding ascii "$env:PGDATA\postgresql.conf" (
        (Get-Content "$env:PGDATA\postgresql.conf") `
            -replace '^#?(listen_addresses\s+.+?\s+).+','$1''0.0.0.0'''
    )

    Write-Host 'Allowing external connections made with the md5 authentication method...'
@'

# allow md5 authenticated connections from any other address.
#
# TYPE  DATABASE        USER            ADDRESS                 METHOD
host    all             all             0.0.0.0/0               md5
host    all             all             ::/0                    md5
'@ `
    | Out-File -Append -Encoding ascii "$env:PGDATA\pg_hba.conf"
}

Write-Output "Starting the $serviceName service..."
Start-Service $serviceName

Write-Host "Setting the $env:PGUSER user password..."
psql -c "alter role $env:PGUSER login password '$env:PGPASSWORD'" postgres

if ($initialize) {
    @(
        'C:/init/sql.d'
        'C:/local/sql.d'
    ) `
        | Where-Object {Test-Path $_} `
        | ForEach-Object {
            Get-ChildItem "$_/*.sql" `
                | Sort-Object -Property Name `
                | ForEach-Object {
                    Write-Output "Initializing with $($_.FullName)..."
                    psql --file $_.FullName
                }
        }
}

Write-Host "Running $((psql -t -c 'select version()' postgres | Out-String).Trim())..."
cd C:/init/winlogbeat
./winlogbeat.exe
