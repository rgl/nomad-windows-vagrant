Write-Title 'consul version'
consul --version

Write-Title 'consul info'
consul info

Write-Title 'consul members'
consul members

Write-Title 'consul dns soa'
choco install -y bind-toolsonly
dig '@127.0.0.1' -p 8600 soa consul
