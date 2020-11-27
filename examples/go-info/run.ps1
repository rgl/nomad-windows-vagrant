param(
    [int]$groupCount
)

# build the image.
# NB we cannot run this from the c:\vagrant share, so we first copy the
#    files to the disk.
mkdir -Force "$env:TEMP\go-info" | Out-Null
Copy-Item * "$env:TEMP\go-info"
Push-Location "$env:TEMP\go-info"
$tag = '1.0.0'
docker build -t go-info:$tag .
docker history go-info:$tag
docker image ls go-info
Pop-Location

# launch the job.
(
    (Get-Content go-info.hcl) `
        -replace '@@group_count@@',$groupCount
) | nomad.exe job run -
if ($LASTEXITCODE) {
    throw "failed to launch job with exit code $LASTEXITCODE"
}

# get its address from consul dns.
dig '@127.0.0.1' -p 8600 a go-info.service.consul
dig '@127.0.0.1' -p 8600 srv go-info.service.consul
dig '@127.0.0.1' -p 8600 srv http.go-info.service.consul # restrict the query to the services that have the `http` tag.
