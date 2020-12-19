# escape=`
# see https://github.com/PowerShell/PowerShell-Docker/blob/master/release/stable/nanoserver1809/docker/Dockerfile
FROM mcr.microsoft.com/powershell:7.1.0-nanoserver-1809 AS builder
SHELL ["pwsh.exe", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]
RUN mkdir C:/Windows/TEMP/build | Out-Null
WORKDIR C:/Windows/TEMP/build
RUN $url = 'https://get.enterprisedb.com/postgresql/postgresql-13.1-1-windows-x64-binaries.zip'; `
    $sha256 = '90f80410bbfda295741b09c3b7ae2e9f35981fbfabdabc1ca876e1c408ddf283'; `
    Write-Host ('Downloading PostgreSQL from {0}...' -f $url); `
    Invoke-WebRequest -Uri $url -OutFile postgresql.zip; `
    Write-Host ('Verifying sha256 ({0})...' -f $sha256); `
    if ((Get-FileHash postgresql.zip -Algorithm sha256).Hash -ne $sha256) { `
        Write-Host 'FAILED!'; `
        Exit 1; `
    }; `
    Write-Host 'Expanding...'; `
    Expand-Archive postgresql.zip .; `
    Write-Host 'Removing unneeded files...'; `
    Remove-Item postgresql.zip; `
    cd pgsql; `
    Get-ChildItem -Exclude bin,lib,share | ForEach-Object {cmd.exe /c rd /s /q $_}; `
    Write-Host 'Done.'
# see https://www.elastic.co/downloads/beats/winlogbeat
RUN $url = 'https://artifacts.elastic.co/downloads/beats/winlogbeat/winlogbeat-oss-7.10.1-windows-x86_64.zip'; `
    $sha512 = '97b853404ae4824e287ac2d4128fb25d9f9cfe167f79bda5bfe3e53314d897e925704d5f7e2ccb60a40e717909561247ad759fa84963e232fa9931757de4a772'; `
    Write-Host ('Downloading winlogbeat from {0}...' -f $url); `
    Invoke-WebRequest -Uri $url -OutFile winlogbeat.zip; `
    Write-Host ('Verifying sha512 ({0})...' -f $sha512); `
    if ((Get-FileHash winlogbeat.zip -Algorithm sha512).Hash -ne $sha512) { `
        Write-Host 'FAILED!'; `
        Exit 1; `
    }; `
    Write-Host 'Expanding...'; `
    Expand-Archive winlogbeat.zip .; `
    Write-Host 'Removing unneeded files...'; `
    Remove-Item winlogbeat.zip; `
    Copy-Item winlogbeat-*/winlogbeat.exe .; `
    Remove-Item -Recurse winlogbeat-*; `
    Write-Host 'Done.'

FROM mcr.microsoft.com/windows/servercore:1809
SHELL ["PowerShell.exe", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]
USER ContainerAdministrator
RUN $url = 'https://download.visualstudio.microsoft.com/download/pr/89a3b9df-4a09-492e-8474-8f92c115c51d/B1A32C71A6B7D5978904FB223763263EA5A7EB23B2C44A0D60E90D234AD99178/VC_redist.x64.exe'; `
    $sha256 = 'b1a32c71a6b7d5978904fb223763263ea5a7eb23b2c44a0d60e90d234ad99178'; `
    Write-Host ('Downloading vcredist140 (aka vcredist2017) from {0}...' -f $url); `
    Invoke-WebRequest -Uri $url -OutFile VC_redist.x64.exe; `
    Write-Host ('Verifying sha256 ({0})...' -f $sha256); `
    if ((Get-FileHash VC_redist.x64.exe -Algorithm sha256).Hash -ne $sha256) { `
        Write-Host 'FAILED!'; `
        Exit 1; `
    }; `
    Write-Host 'Installing...'; `
    ./VC_redist.x64.exe /quiet /norestart | Out-String -Stream; `
    Write-Host 'Removing unneeded files...'; `
    Remove-Item VC_redist.x64.exe; `
    Write-Host 'Done.'
COPY --from=builder C:/Windows/TEMP/build/pgsql /pgsql/
RUN regsvr32.exe C:/pgsql/lib/pgevent.dll
COPY --from=builder C:/Windows/TEMP/build/winlogbeat.exe /init/winlogbeat/
COPY winlogbeat.yml /init/winlogbeat/
COPY init /init/
EXPOSE 5432
ENV PGPASSWORD="postgres"
ENV PGDATA="C:/data/pgdata"
VOLUME ["C:/data"]
ENTRYPOINT /init/init.ps1
# NB nomad does not uses this HEALTHCHECK CMD; instead, we define it in the nomad job.
#    see https://github.com/hashicorp/nomad/issues/5310
#HEALTHCHECK CMD ["c:/pgsql/bin/psql.exe", "-v", "ON_ERROR_STOP=1", "-w", "-t", "-U", "postgres", "-c", "select 1", "postgres"]
