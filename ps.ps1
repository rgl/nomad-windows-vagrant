param(
    [Parameter(Mandatory=$true)]
    [String]$script,
    [Parameter(ValueFromRemainingArguments=$true)]
    [String[]]$scriptArguments
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
trap {
    Write-Output "ERROR: $_"
    Write-Output (($_.ScriptStackTrace -split '\r?\n') -replace '^(.*)$','ERROR: $1')
    Exit 1
}

function Write-Title($title) {
    Write-Output "#`n# $title`n#"
}

function Get-WindowsVersionTag {
    $currentVersionKey = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $windowsBuildNumber = $currentVersionKey.CurrentBuildNumber
    $windowsVersionTag = @{
        '19041' = '2004'
        '17763' = '1809'
    }[$windowsBuildNumber]
    if (!$windowsVersionTag) {
        throw "Unknown Windows Build Number $windowsBuildNumber"
    }
    $windowsVersionTag
}

# wrap the choco command (to make sure this script aborts when it fails).
function Start-Choco([string[]]$Arguments, [int[]]$SuccessExitCodes=@(0)) {
    $command, $commandArguments = $Arguments
    if ($command -eq 'install') {
        $Arguments = @($command, '--no-progress') + $commandArguments
    }
    for ($n = 0; $n -lt 10; ++$n) {
        if ($n) {
            # NB sometimes choco fails with "The package was not found with the source(s) listed."
            #    but normally its just really a transient "network" error.
            Write-Host "Retrying choco install..."
            Start-Sleep -Seconds 3
        }
        &C:\ProgramData\chocolatey\bin\choco.exe @Arguments
        if ($SuccessExitCodes -Contains $LASTEXITCODE) {
            return
        }
    }
    throw "$(@('choco')+$Arguments | ConvertTo-Json -Compress) failed with exit code $LASTEXITCODE"
}
function choco {
    Start-Choco $Args
}

Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class Windows
{
    [DllImport("kernel32", SetLastError=true)]
    public static extern UInt64 GetTickCount64();
    public static TimeSpan GetUptime()
    {
        return TimeSpan.FromMilliseconds(GetTickCount64());
    }
}
'@
function Wait-ForCondition {
    param(
      [scriptblock]$Condition,
      [int]$DebounceSeconds=5
    )
    process {
        $begin = [Windows]::GetUptime()
        do {
            Start-Sleep -Seconds 1
            try {
              $result = &$Condition
            } catch {
              $result = $false
            }
            if (-not $result) {
                $begin = [Windows]::GetUptime()
                continue
            }
        } while ((([Windows]::GetUptime()) - $begin).TotalSeconds -lt $DebounceSeconds)
    }
}

# wrap the docker command (to make sure this script aborts when it fails).
function docker {
    docker.exe @Args | Out-String -Stream -Width ([int]::MaxValue)
    if ($LASTEXITCODE) {
        throw "$(@('docker')+$Args | ConvertTo-Json -Compress) failed with exit code $LASTEXITCODE"
    }
}

# wrap the nomad command (to make sure this script aborts when it fails).
# NB exit 2 is returned when the allocation could not be fulfilled immediately
#    (nomad will keep retrying it in background so we assume it went ok).
function nomad {
    nomad.exe @Args | Out-String -Stream -Width ([int]::MaxValue)
    if (@(0, 2) -notcontains $LASTEXITCODE) {
        throw "$(@('nomad')+$Args | ConvertTo-Json -Compress) failed with exit code $LASTEXITCODE"
    }
}

# wrap the vault command (to make sure this script aborts when it fails).
# NB exit 2 is returned when the allocation could not be fulfilled immediately
#    (vault will keep retrying it in background so we assume it went ok).
function vault {
    process {
        $_ | vault.exe @Args | Out-String -Stream -Width ([int]::MaxValue)
        if (@(0, 2) -notcontains $LASTEXITCODE) {
            throw "$(@('vault')+$Args | ConvertTo-Json -Compress) failed with exit code $LASTEXITCODE"
        }
    }
}

cd c:/vagrant
$script = Resolve-Path $script
cd (Split-Path $script -Parent)
Write-Host "Running $script..."
. $script @scriptArguments
