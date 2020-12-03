param(
    $ipAddress = '10.11.0.101'
)

choco install -y bind-toolsonly

# register an example service.
# see https://www.consul.io/docs/discovery/dns
# see https://www.consul.io/docs/discovery/services
# see https://www.consul.io/api-docs/agent/service#register-service
# see https://www.consul.io/api-docs/catalog#list-nodes-for-service
Write-Title 'consul ad-hoc service address'
Invoke-RestMethod `
    -Uri http://127.0.0.1:8500/v1/agent/service/register `
    -Method Put `
    -ContentType 'application/json' `
    -Body (
        @{
            Name = 'consul-ad-hoc'
            Address = $ipAddress
            Port = 80
            Tags = @(
                'http'
            )
            Meta = @{
                version = '1.0.0'
            }
        } | ConvertTo-Json -Depth 100 -Compress
    )

# get its address from consul http api.
Invoke-RestMethod http://127.0.0.1:8500/v1/catalog/service/consul-ad-hoc
Invoke-RestMethod http://127.0.0.1:8500/v1/catalog/service/consul-ad-hoc?tag=http

# get its address from consul dns api.
dig '@127.0.0.1' -p 8600 a consul-ad-hoc.service.consul
dig '@127.0.0.1' -p 8600 srv consul-ad-hoc.service.consul
dig '@127.0.0.1' -p 8600 srv http.consul-ad-hoc.service.consul # restrict the query to the services that have the `http` tag.
