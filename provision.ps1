# define the Install-Application function that downloads and unzips an application.
Add-Type -AssemblyName System.IO.Compression.FileSystem
function Install-Application($name, $url, $expectedHash, $expectedHashAlgorithm = 'SHA256') {
    $localZipPath = "$env:TEMP\$name.zip"
    (New-Object Net.WebClient).DownloadFile($url, $localZipPath)
    $actualHash = (Get-FileHash $localZipPath -Algorithm $expectedHashAlgorithm).Hash
    if ($actualHash -ne $expectedHash) {
        throw "$name downloaded from $url to $localZipPath has $actualHash hash that does not match the expected $expectedHash"
    }
    $destinationPath = Join-Path $env:ProgramFiles $name
    [IO.Compression.ZipFile]::ExtractToDirectory($localZipPath, $destinationPath)
}

# disable cortana and web search.
New-Item -Path 'HKLM:SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Force `
    | New-ItemProperty -Name AllowCortana -Value 0 `
    | New-ItemProperty -Name ConnectedSearchUseWeb -Value 0 `
    | Out-Null

# set keyboard layout.
# NB you can get the name from the list:
#      [Globalization.CultureInfo]::GetCultures('InstalledWin32Cultures') | Out-GridView
Set-WinUserLanguageList pt-PT -Force

# set the date format, number format, etc.
Set-Culture pt-PT

# set the welcome screen culture and keyboard layout.
# NB the .DEFAULT key is for the local SYSTEM account (S-1-5-18).
New-PSDrive HKU -PSProvider Registry -Root HKEY_USERS | Out-Null
'Control Panel\International','Keyboard Layout' | ForEach-Object {
    Remove-Item -Path "HKU:.DEFAULT\$_" -Recurse -Force
    Copy-Item -Path "HKCU:$_" -Destination "HKU:.DEFAULT\$_" -Recurse -Force
}
Remove-PSDrive HKU

# set the timezone.
# use Get-TimeZone -ListAvailable to list the available timezone ids.
Set-TimeZone -Id 'GMT Standard Time'

# show window content while dragging.
Set-ItemProperty -Path 'HKCU:Control Panel\Desktop' -Name DragFullWindows -Value 1

# show hidden files.
Set-ItemProperty -Path HKCU:Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name Hidden -Value 1

# show protected operating system files.
Set-ItemProperty -Path HKCU:Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name ShowSuperHidden -Value 1

# show file extensions.
Set-ItemProperty -Path HKCU:Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name HideFileExt -Value 0

# display full path in the title bar.
New-Item -Path HKCU:Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState -Force `
    | New-ItemProperty -Name FullPath -Value 1 -PropertyType DWORD `
    | Out-Null

# set the desktop wallpaper.
Add-Type -AssemblyName System.Drawing
$backgroundColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
$backgroundPath = 'C:\Windows\Web\Wallpaper\Windows\nomad.png'
$logo = [System.Drawing.Image]::FromFile((Resolve-Path 'nomad.png'))
$b = New-Object System.Drawing.Bitmap($logo.Width, $logo.Height)
$g = [System.Drawing.Graphics]::FromImage($b)
$g.Clear($backgroundColor)
$g.DrawImage($logo, 0, 0, $logo.Width, $logo.Height)
$b.Save($backgroundPath)
Set-ItemProperty -Path 'HKCU:Control Panel\Desktop' -Name Wallpaper -Value $backgroundPath
Set-ItemProperty -Path 'HKCU:Control Panel\Desktop' -Name WallpaperStyle -Value 0
Set-ItemProperty -Path 'HKCU:Control Panel\Desktop' -Name TileWallpaper -Value 0
Set-ItemProperty -Path 'HKCU:Control Panel\Colors' -Name Background -Value ($backgroundColor.R,$backgroundColor.G,$backgroundColor.B -join ' ')

# set the lock screen background.
Copy-Item $backgroundPath C:\Windows\Web\Screen
New-Item -Path HKLM:Software\Policies\Microsoft\Windows\Personalization -Force `
    | New-ItemProperty -Name LockScreenImage -Value C:\Windows\Web\Screen\nomad.png `
    | New-ItemProperty -Name PersonalColors_Background -Value '#1e1e1e' `
    | New-ItemProperty -Name PersonalColors_Accent -Value '#007acc' `
    | Out-Null

# set account picture.
$accountSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$accountPictureBasePath = "C:\Users\Public\AccountPictures\$accountSid"
$accountRegistryKeyPath = "HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\AccountPicture\Users\$accountSid"
mkdir $accountPictureBasePath | Out-Null
New-Item $accountRegistryKeyPath | Out-Null
# NB we are resizing the same image for all the resolutions, but for better
#    results, you should use images with different resolutions.
Add-Type -AssemblyName System.Drawing
$accountImage = [System.Drawing.Image]::FromFile("c:\vagrant\vagrant.png")
32,40,48,96,192,240,448 | ForEach-Object {
    $p = "$accountPictureBasePath\Image$($_).jpg"
    $i = New-Object System.Drawing.Bitmap($_, $_)
    $g = [System.Drawing.Graphics]::FromImage($i)
    $g.DrawImage($accountImage, 0, 0, $_, $_)
    $i.Save($p)
    New-ItemProperty -Path $accountRegistryKeyPath -Name "Image$_" -Value $p -Force | Out-Null
}

# install Google Chrome.
# see https://www.chromium.org/administrators/configuring-other-preferences
choco install -y --ignore-checksums googlechrome
$chromeLocation = 'C:\Program Files\Google\Chrome\Application'
cp -Force GoogleChrome-external_extensions.json (Resolve-Path "$chromeLocation\*\default_apps\external_extensions.json")
cp -Force GoogleChrome-master_preferences.json "$chromeLocation\master_preferences"
cp -Force GoogleChrome-master_bookmarks.html "$chromeLocation\master_bookmarks.html"

# set the default browser.
choco install -y SetDefaultBrowser
SetDefaultBrowser HKLM "Google Chrome"

# install the carbon powershell library.
choco install -y carbon

# install monospace font.
# NB should be one from https://www.nerdfonts.com/ to be compatible with oh-my-posh.
# see https://www.programmingfonts.org/#dejavu
# see https://www.programmingfonts.org/#meslo
choco install -y font-nerd-dejavusansmono

# replace notepad with notepad3.
choco install -y notepad3
$notepad3IniPath = "$env:APPDATA\Rizonesoft\Notepad3\Notepad3.ini"
mkdir -Force (Split-Path -Parent $notepad3IniPath) | Out-Null
Set-Content -Encoding Ascii $notepad3IniPath @'
[Settings]
SettingsVersion=4
[Common Base]
Default Style=font:DejaVuSansMono NF; fstyle:Book; size:11
'@

# configure the windows console (command prompt and powershell).
reg import console-settings.reg
# re-create the existing powershell shortcuts.
# NB the powershell console settings are stored inside the shortcut file and
#    since there is no obvious api to modify it... we have to re-crete the
#    shortcuts; these new shortcuts will not have any console settings in
#    them, so, they will inherit the settings from the registry keys that
#    we've set before.
# see https://devblogs.microsoft.com/commandline/understanding-windows-console-host-settings/
Import-Module C:\ProgramData\chocolatey\helpers\chocolateyInstaller.psm1
@(
    ,@(
        "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Windows PowerShell\Windows PowerShell (x86).lnk"
        "$env:SystemRoot\syswow64\WindowsPowerShell\v1.0\powershell.exe")
    ,@(
        "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Windows PowerShell\Windows PowerShell.lnk"
        "$env:SystemRoot\system32\WindowsPowerShell\v1.0\powershell.exe")
) | ForEach-Object {
    if (Test-Path $_[0]) {
        Remove-Item $_[0]
    }
    Install-ChocolateyShortcut `
        -ShortcutFilePath $_[0] `
        -TargetPath $_[1] `
        -WorkingDirectory '%USERPROFILE%'
}

# customize the powershell psreadline behaviour.
Set-Content -Encoding Ascii $PROFILE @'
#Set-PSReadLineOption -EditMode Emacs
Set-PSReadLineKeyHandler -Key Ctrl+d -Function DeleteCharOrExit
Set-PSReadlineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadlineKeyHandler -Key DownArrow -Function HistorySearchForward
'@

# install oh-my-posh v3.
# see https://ohmyposh.dev/docs/installation/
# see https://ohmyposh.dev/docs/powershell/
# see https://ohmyposh.dev/docs/themes
# see also https://starship.rs/
# NB this requires an updated PowerShellGet as done in provision-powershellget.ps1.
#Install-Module -Name posh-git
Install-Module -Name oh-my-posh -AllowPrerelease
Copy-Item rgl.omp.json ~/.rgl.omp.json
Add-Content -Encoding Ascii $PROFILE @'
Import-Module oh-my-posh
Set-PoshPrompt -Theme ~/.rgl.omp.json
'@
