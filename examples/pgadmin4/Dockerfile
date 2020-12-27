# escape=`
# see https://www.pgadmin.org/docs/pgadmin4/4.29/deployment.html
FROM mcr.microsoft.com/windows/servercore:1809 as builder
SHELL ["PowerShell.exe", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]
RUN mkdir C:/Windows/TEMP/build | Out-Null
WORKDIR C:/Windows/TEMP/build
RUN $url = 'https://ftp.postgresql.org/pub/pgadmin/pgadmin4/v4.29/windows/pgadmin4-4.29-x64.exe'; `
    $sha256 = '9dd7ca8ea6d86165490908b3d213019a04e15567b2ba11c1f3c429533783da00'; `
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
