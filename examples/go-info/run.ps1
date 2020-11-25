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

nomad run go-info.hcl
