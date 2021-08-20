$env:PATH += ';c:\pgadmin4\python'
cd c:\pgadmin4
if (!(Test-Path "$env:APPDATA\pgAdmin\pgadmin4.db")) {
    Write-Output 'Initializing the database...'
    python web\setup.py
    Write-Output 'Loading servers...'
    python web\setup.py --load-servers servers.json
}
Write-Output 'Running pgAdmin4...'
python web\pgAdmin4.py
