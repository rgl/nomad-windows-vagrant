Write-Title 'nomad version'
nomad version

Write-Title 'nomad agent-info'
nomad agent-info

Write-Title 'nomad server members'
nomad server members

Write-Title 'nomad server all services from dns'
dig '@127.0.0.1' -p 8600 srv nomad.service.consul

Write-Title 'nomad server http services from dns'
dig '@127.0.0.1' -p 8600 srv http.nomad.service.consul
