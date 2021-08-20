# build the image.
# NB we cannot run this from the c:\vagrant share, so we first copy the
#    files to the disk.
Write-Output 'building the pgadmin4 image...'
if (Test-Path "$env:TEMP\pgadmin4") {
    Remove-Item -Recurse -Force "$env:TEMP\pgadmin4" | Out-Null
}
mkdir -Force "$env:TEMP\pgadmin4" | Out-Null
Copy-Item -Recurse * "$env:TEMP\pgadmin4"
Push-Location "$env:TEMP\pgadmin4"
docker build -t pgadmin4:5.6 .
docker image ls pgadmin4:5.6
docker history pgadmin4:5.6
Pop-Location

# launch the job.
nomad.exe job run pgadmin4.hcl
if ($LASTEXITCODE) {
    throw "failed to launch job with exit code $LASTEXITCODE"
}

# wait for the job deployment to be successful.
Write-Output 'Waiting for job deployment to be successful...'
Wait-ForCondition {
    (nomad job deployments -latest -json pgadmin4 | ConvertFrom-Json).Status -eq 'successful'
}

# get its address from consul http api.
Invoke-RestMethod http://127.0.0.1:8500/v1/catalog/service/pgadmin4
Invoke-RestMethod http://127.0.0.1:8500/v1/catalog/service/pgadmin4?tag=http

# get its address from consul dns api.
dig '@127.0.0.1' -p 53 a pgadmin4.service.consul
dig '@127.0.0.1' -p 53 srv pgadmin4.service.consul
dig '@127.0.0.1' -p 53 srv http.pgadmin4.service.consul # restrict the query to the services that have the `http` tag.
