# cleanup the taskbar by removing the existing buttons and unpinning all applications; once the user logs on.
# NB the shell executes these RunOnce commands about ~10s after the user logs on.
[IO.File]::WriteAllText(
    "C:\tmp\ConfigureTaskbar.ps1",
@'
Import-Module C:\ProgramData\chocolatey\helpers\chocolateyInstaller.psm1

# unpin all applications.
# NB this can only be done in a logged on session.
$pinnedTaskbarPath = "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"
(New-Object -Com Shell.Application).NameSpace($pinnedTaskbarPath).Items() `
    | ForEach-Object {
        $unpinVerb = $_.Verbs() | Where-Object { $_.Name -eq 'Unpin from tas&kbar' }
        if ($unpinVerb) {
            $unpinVerb.DoIt()
        } else {
            $shortcut = (New-Object -Com WScript.Shell).CreateShortcut($_.Path)
            if (!$shortcut.TargetPath -and ($shortcut.IconLocation -eq '%windir%\explorer.exe,0')) {
                Remove-Item -Force $_.Path
            }
        }
    }
Get-Item HKCU:SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Taskband `
    | Set-ItemProperty -Name Favorites -Value 0xff `
    | Set-ItemProperty -Name FavoritesResolve -Value 0xff `
    | Set-ItemProperty -Name FavoritesVersion -Value 3 `
    | Set-ItemProperty -Name FavoritesChanges -Value 1 `
    | Set-ItemProperty -Name FavoritesRemovedChanges -Value 1

# hide the search button.
Set-ItemProperty -Path HKCU:SOFTWARE\Microsoft\Windows\CurrentVersion\Search -Name SearchboxTaskbarMode -Value 0

# hide the task view button.
Set-ItemProperty -Path HKCU:SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name ShowTaskViewButton -Value 0

# never combine the taskbar buttons.
# possibe values:
#   0: always combine and hide labels (default)
#   1: combine when taskbar is full
#   2: never combine
Set-ItemProperty -Path HKCU:Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name TaskbarGlomLevel -Value 2

# remove the default desktop shortcuts.
del C:\Users\*\Desktop\*.lnk
del -Force C:\Users\*\Desktop\*.ini

# add desktop shortcuts.
[IO.File]::WriteAllText("$env:USERPROFILE\Desktop\Nomad Web UI.url", @"
[InternetShortcut]
URL=http://localhost:4646
"@)

[IO.File]::WriteAllText("$env:USERPROFILE\Desktop\Nomad Metrics.url", @"
[InternetShortcut]
URL=http://localhost:4646/v1/metrics?format=prometheus
"@)

[IO.File]::WriteAllText("$env:USERPROFILE\Desktop\Consul Web UI.url", @"
[InternetShortcut]
URL=http://localhost:8500
"@)

[IO.File]::WriteAllText("$env:USERPROFILE\Desktop\Consul Metrics.url", @"
[InternetShortcut]
URL=http://localhost:8500/v1/agent/metrics?format=prometheus
"@)

[IO.File]::WriteAllText("$env:USERPROFILE\Desktop\Prometheus.url", @"
[InternetShortcut]
URL=http://server1:9090
"@)

[IO.File]::WriteAllText("$env:USERPROFILE\Desktop\Grafana.url", @"
[InternetShortcut]
URL=http://server1:3000
"@)

# restart explorer to apply the changed settings.
(Get-Process explorer).Kill()
'@)
New-Item -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce -Force `
    | New-ItemProperty -Name ConfigureTaskbar -Value 'PowerShell -WindowStyle Hidden -File "C:\tmp\ConfigureTaskbar.ps1"' -PropertyType ExpandString `
    | Out-Null
