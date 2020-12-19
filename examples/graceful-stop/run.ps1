nomad run graceful-stop.hcl

# wait for the job deployment to be successful.
Write-Output 'Waiting for job deployment to be successful...'
Wait-ForCondition {
    (nomad job deployments -latest -json graceful-stop | ConvertFrom-Json).Status -eq 'successful'
}
