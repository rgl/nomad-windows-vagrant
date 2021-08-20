# build the image.
# NB we cannot run this from the c:\vagrant share, so we first copy the
#    files to the disk.
Write-Output 'building the postgresql image...'
if (Test-Path "$env:TEMP\postgresql") {
    Remove-Item -Recurse -Force "$env:TEMP\postgresql" | Out-Null
}
mkdir -Force "$env:TEMP\postgresql" | Out-Null
Copy-Item -Recurse * "$env:TEMP\postgresql"
Push-Location "$env:TEMP\postgresql"
docker build -t postgresql:13.4 .
docker image ls postgresql:13.4
docker history postgresql:13.4
Pop-Location

# launch the job.
nomad.exe job run postgresql.hcl
if ($LASTEXITCODE) {
    throw "failed to launch job with exit code $LASTEXITCODE"
}

# wait for the job deployment to be successful.
Write-Output 'Waiting for job deployment to be successful...'
Wait-ForCondition {
    (nomad job deployments -latest -json postgresql | ConvertFrom-Json).Status -eq 'successful'
}

# get its address from consul http api.
Invoke-RestMethod http://127.0.0.1:8500/v1/catalog/service/postgresql
Invoke-RestMethod http://127.0.0.1:8500/v1/catalog/service/postgresql?tag=http

# get its address from consul dns api.
dig '@127.0.0.1' -p 53 a postgresql.service.consul
dig '@127.0.0.1' -p 53 srv postgresql.service.consul
dig '@127.0.0.1' -p 53 srv postgresql.postgresql.service.consul # restrict the query to the services that have the `postgresql` tag.
