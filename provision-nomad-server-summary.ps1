Write-Title 'nomad version'
nomad version

Write-Title 'nomad agent-info'
nomad agent-info

Write-Title 'nomad server members'
nomad server members

Write-Title 'nomad server service addresses (http api)'
Invoke-RestMethod http://127.0.0.1:8500/v1/catalog/service/nomad

Write-Title 'nomad server service addresses (dns api)'
dig '@127.0.0.1' -p 8600 srv nomad.service.consul

Write-Title 'nomad server http tag service addresses (http api)'
Invoke-RestMethod http://127.0.0.1:8500/v1/catalog/service/nomad?tag=http

Write-Title 'nomad server http tag service addresses (dns api)'
dig '@127.0.0.1' -p 8600 srv http.nomad.service.consul
