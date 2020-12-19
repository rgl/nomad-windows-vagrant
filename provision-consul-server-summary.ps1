Write-Title 'consul version'
consul --version

Write-Title 'consul info'
consul info

Write-Title 'consul members'
consul members

Write-Title 'consul service address (http api)'
Invoke-RestMethod http://127.0.0.1:8500/v1/catalog/service/consul

Write-Title 'consul service soa (dns api)'
choco install -y bind-toolsonly
dig '@127.0.0.1' -p 53 soa consul
