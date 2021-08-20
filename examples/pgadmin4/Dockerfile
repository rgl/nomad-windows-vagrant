# escape=`
# see https://www.pgadmin.org/docs/pgadmin4/5.6/deployment.html
FROM mcr.microsoft.com/windows/servercore:1809 as builder
SHELL ["PowerShell.exe", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]
RUN mkdir C:/Windows/TEMP/build | Out-Null
WORKDIR C:/Windows/TEMP/build
RUN $url = 'https://ftp.postgresql.org/pub/pgadmin/pgadmin4/v5.6/windows/pgadmin4-5.6-x64.exe'; `
    $sha256 = 'b4c383b518396699cd668d21b2464f03176e76ddcd14d2b6d0ade9950f25bc11'; `
    Write-Host ('Downloading pgadmin4 from {0}...' -f $url); `
    Invoke-WebRequest -Uri $url -OutFile pgadmin4.exe; `
    Write-Host ('Verifying sha256 ({0})...' -f $sha256); `
    if ((Get-FileHash pgadmin4.exe -Algorithm sha256).Hash -ne $sha256) { `
        Write-Host 'FAILED!'; `
        Exit 1; `
    }; `
    Write-Host 'Installing...'; `
    .\pgadmin4.exe /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- /DIR=C:\pgadmin4 | Out-String -Stream; `
    Write-Host 'Removing unneeded files...'; `
    Remove-Item pgadmin4.exe; `
    Write-Host 'Done.'

FROM mcr.microsoft.com/windows/servercore:1809
SHELL ["PowerShell.exe", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]
USER ContainerUser
COPY --from=builder C:/pgadmin4 /pgadmin4/
COPY entrypoint.ps1 /pgadmin4/
COPY servers.json /pgadmin4/
COPY pgpass.conf /pgadmin4/
COPY config_local.py /pgadmin4/web/
EXPOSE 5050
ENTRYPOINT /pgadmin4/entrypoint.ps1
