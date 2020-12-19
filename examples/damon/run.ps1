nomad run damon.hcl

# wait for the job deployment to be successful.
Write-Output 'Waiting for job deployment to be successful...'
Wait-ForCondition {
    (nomad job deployments -latest -json damon | ConvertFrom-Json).Status -eq 'successful'
}
