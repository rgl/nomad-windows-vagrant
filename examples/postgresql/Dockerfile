# escape=`
# see https://github.com/PowerShell/PowerShell-Docker/blob/master/release/stable/nanoserver1809/docker/Dockerfile
FROM mcr.microsoft.com/powershell:7.1.4-nanoserver-1809 AS builder
SHELL ["pwsh.exe", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]
RUN mkdir C:/Windows/TEMP/build | Out-Null
WORKDIR C:/Windows/TEMP/build
# see https://www.enterprisedb.com/download-postgresql-binaries
RUN $url = 'https://get.enterprisedb.com/postgresql/postgresql-13.4-1-windows-x64-binaries.zip'; `
    $sha256 = '265afeb19906c0c89efdcaf7d652ab90ab3c295c49be792c0dbbbf13ca50de25'; `
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
RUN $url = 'https://artifacts.elastic.co/downloads/beats/winlogbeat/winlogbeat-oss-7.14.0-windows-x86_64.zip'; `
    $sha512 = '4a163be17e29d9c3d2b395734850963f09d6fe125c14254e45facd23b8c22db7d112e9cce4e5f56bbd8079353e30003bf57d5a60ff590edd1238b360c6d6d55a'; `
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
RUN $url = 'https://download.visualstudio.microsoft.com/download/pr/7239cdc3-bd73-4f27-9943-22de059a6267/003063723B2131DA23F40E2063FB79867BAE275F7B5C099DBD1792E25845872B/VC_redist.x64.exe'; `
    $sha256 = '003063723b2131da23f40e2063fb79867bae275f7b5c099dbd1792e25845872b'; `
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
