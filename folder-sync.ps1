<#
.SYNOPSIS
    Synchronize a local data folder with a remote data folder derived from the Git origin URL.

.DESCRIPTION
    This script supports syncing a data folder between a local Git repository and a remote location.
    The remote location is derived by replacing the .git suffix in the Git origin URL with .data.
    It supports push/pull directions, cleaning folders, dry-run mode, logging, exclusion patterns,
    file hash comparison, retry logic, and configuration via syncconfig.json.

.PARAMETER Direction
    Required. 'push' to sync local to remote, 'pull' to sync remote to local.

.PARAMETER CleanRemote
    Optional. If true, clears the remote data folder before syncing.

.PARAMETER CleanLocal
    Optional. If true, clears the local data folder before syncing.

.PARAMETER FolderName
    Optional. Defaults to 'data'. The folder to sync.

.PARAMETER Log
    Optional. Enables verbose logging to the console.

.PARAMETER EnableLogFile
    Optional. If set, logs will also be written to sync.log in the current directory.

.PARAMETER DryRun
    Optional. Simulates actions without making changes.

.PARAMETER Help
    Optional. Displays this help message.

.EXAMPLE
    sync-data.ps1 -Direction push -CleanRemote $true -Log -EnableLogFile -DryRun
#>

param (
    [Parameter(Mandatory=$false, HelpMessage="Show help information.")]
    [switch]$Help,

    [Parameter(Mandatory=$false)]
    [ValidateSet("push", "pull")]
    [string]$Direction,

    [Parameter(Mandatory=$false)]
    [bool]$CleanRemote = $false,

    [Parameter(Mandatory=$false)]
    [bool]$CleanLocal = $false,

    [Parameter(Mandatory=$false)]
    [switch]$Log,

    [Parameter(Mandatory=$false)]
    [switch]$EnableLogFile,

    [Parameter(Mandatory=$false)]
    [switch]$DryRun,

    [string]$FolderName = "data"
)

function Write-Log {
    param ([string]$Message)
    if ($Log -or $EnableLogFile) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logMessage = "[{0}] {1}" -f $timestamp, $Message
        if ($Log) {
            Write-Host $logMessage
        }
        if ($EnableLogFile) {
            Add-Content -Path "$PWD\\sync.log" -Value $logMessage
        }
    }
}

function Remove-FolderContents {
    param (
        [string]$Path,
        [string]$Label
    )
    if (Test-Path $Path) {
        Get-ChildItem -Path $Path -Recurse -Force | ForEach-Object {
            Write-Log "$Label : Removing $($_.FullName)"
        }
        if (-not $DryRun) {
            Remove-Item -Path $Path -Recurse -Force
            New-Item -ItemType Directory -Path $Path | Out-Null
        }
    }
}

function Copy-FolderContents {
    param (
        [string]$Source,
        [string]$Destination,
        [string]$Label,
        [array]$Exclusions,
        [int]$MaxRetries
    )
    if (Test-Path $Source) {
        $items = Get-ChildItem -Path $Source -Recurse -Force
        $total = $items.Count
        $index = 0

        foreach ($item in $items) {
            $index++
            $relativePath = $item.FullName.Substring($Source.Length).TrimStart('\')
            $destPath = Join-Path $Destination $relativePath

            # Check exclusions
            $excluded = $false
            foreach ($pattern in $Exclusions) {
                if ($item.Name -like $pattern -or $relativePath -like $pattern) {
                    $excluded = $true
                    break
                }
            }
            if ($excluded) {
                Write-Log "$Label : Skipping excluded item $($item.FullName)"
                continue
            }

            Write-Progress -Activity "$Label : Syncing files" -Status "$index of $total" -PercentComplete (($index / $total) * 100)

            if ($item.PSIsContainer) {
                Write-Log "$Label : Creating directory $destPath"
                if (-not $DryRun) {
                    New-Item -ItemType Directory -Path $destPath -Force | Out-Null
                }
            } else {
                $copy = $true
                if (Test-Path $destPath) {
                    $srcHash = Get-FileHash -Path $item.FullName -Algorithm SHA256
                    $dstHash = Get-FileHash -Path $destPath -Algorithm SHA256
                    if ($srcHash.Hash -eq $dstHash.Hash) {
                        Write-Log "$Label : Skipping unchanged file $($item.FullName)"
                        $copy = $false
                    }
                }
                if ($copy) {
                    Write-Log "$Label : Copying file $($item.FullName) → $destPath"
                    if (-not $DryRun) {
                        $retry = 0
                        while ($retry -lt $MaxRetries) {
                            try {
                                $destDir = Split-Path -Path $destPath -Parent
                                if (-not (Test-Path $destDir)) {
                                    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                                }
                                Copy-Item -Path $item.FullName -Destination $destPath -Force
                                break
                            } catch {
                                $retry++
                                Write-Log "$Label : Error copying $($item.FullName) (attempt $retry): $_"
                                Start-Sleep -Seconds 1
                            }
                        }
                    }
                }
            }
        }
    } else {
        Write-Log "$Label : Source path '$Source' does not exist."
    }
}

# Load config file if present
$configPath = Join-Path -Path $PWD -ChildPath "syncconfig.json"
$config = @{}
if (Test-Path $configPath) {
    try {
        $config = Get-Content -Raw -Path $configPath | ConvertFrom-Json
    } catch {
        Write-Error "Failed to parse syncconfig.json: $_"
        exit 1
    }
}

# Apply config defaults if parameters not provided
if (-not $PSBoundParameters.ContainsKey("Direction") -and $config.Direction) { $Direction = $config.Direction }
if (-not $PSBoundParameters.ContainsKey("CleanRemote") -and $config.CleanRemote) { $CleanRemote = $config.CleanRemote }
if (-not $PSBoundParameters.ContainsKey("CleanLocal") -and $config.CleanLocal) { $CleanLocal = $config.CleanLocal }
if (-not $PSBoundParameters.ContainsKey("FolderName") -and $config.FolderName) { $FolderName = $config.FolderName }
if (-not $PSBoundParameters.ContainsKey("EnableLogFile") -and $config.EnableLogFile) { $EnableLogFile = $config.EnableLogFile }
if (-not $PSBoundParameters.ContainsKey("DryRun") -and $config.DryRun) { $DryRun = $config.DryRun }
if (-not $PSBoundParameters.ContainsKey("Log") -and $config.Log) { $Log = $config.Log }

$Exclusions = @()
if ($config.Exclusions) { $Exclusions = $config.Exclusions }
$MaxRetries = 3
if ($config.MaxRetries) { $MaxRetries = $config.MaxRetries }

if ($Help -or -not $Direction) {
    Write-Host @"
Usage: sync-data.ps1 -Direction <push|pull> [-CleanRemote <true|false>] [-CleanLocal <true|false>] [-FolderName <name>] [-Log] [-EnableLogFile] [-DryRun] [-Help]

Parameters:
  -Direction       Required. 'push' to sync local to remote, 'pull' to sync remote to local.
  -CleanRemote     Optional. If true, clears the remote data folder before syncing.
  -CleanLocal      Optional. If true, clears the local data folder before syncing.
  -FolderName      Optional. Defaults to 'data'. The folder to sync.
  -Log             Optional. Enables verbose logging to the console.
  -EnableLogFile   Optional. Writes logs to sync.log in the current directory.
  -DryRun          Optional. Simulates actions without making changes.
  -Help            Optional. Displays this help message.

Example:
  folder-sync.ps1 -Direction push -CleanRemote `$true -CleanLocal `$false -Log -EnableLogFile
"@
    exit 0
}

# Log resolved parameters
Write-Log "Runtime configuration:"
Write-Log "  Direction: $Direction"
Write-Log "  CleanRemote: $CleanRemote"
Write-Log "  CleanLocal: $CleanLocal"
Write-Log "  FolderName: $FolderName"
Write-Log "  Log: $Log"
Write-Log "  EnableLogFile: $EnableLogFile"
Write-Log "  DryRun: $DryRun"
Write-Log "  Exclusions: $($Exclusions -join ', ')"
Write-Log "  MaxRetries: $MaxRetries"

$CurrentDir = Get-Location

try {
    $remoteUrl = git -C $CurrentDir remote get-url origin
} catch {
    Write-Error "Not a Git repository or no remote 'origin' found."
    exit 1
}

$remotePath = $remoteUrl -replace "^file://", ""
if (-not (Test-Path $remotePath)) {
    Write-Error "Remote path '$remotePath' does not exist."
    exit 1
}

$remoteDataPath = $remotePath -replace "\.git$", ".data"
$localDataPath = Join-Path -Path $CurrentDir -ChildPath $FolderName

Write-Log "Local data path: $localDataPath"
Write-Log "Remote data path: $remoteDataPath"

# Ensure remote data folder exists
if (-not (Test-Path $remoteDataPath)) {
    Write-Log "Remote data folder does not exist. Creating it..."
    if (-not $DryRun) {
        New-Item -ItemType Directory -Path $remoteDataPath -Force | Out-Null
    }
}

# Clean folders if requested
if ($Direction -eq "push" -and $CleanRemote) {
    Remove-FolderContents -Path $remoteDataPath -Label "Remote"
}

if ($Direction -eq "pull" -and $CleanLocal) {
    Remove-FolderContents -Path $localDataPath -Label "Local"
}

# Sync logic
if ($Direction -eq "push") {
    Write-Log "Starting push: local → remote"
    Copy-FolderContents -Source $localDataPath -Destination $remoteDataPath -Label "Push" -Exclusions $Exclusions -MaxRetries $MaxRetries
    Write-Host "✅ Data pushed to remote."
} elseif ($Direction -eq "pull") {
    Write-Log "Starting pull: remote → local"
    Copy-FolderContents -Source $remoteDataPath -Destination $localDataPath -Label "Pull" -Exclusions $Exclusions -MaxRetries $MaxRetries
    Write-Host "✅ Data pulled to local."
}
