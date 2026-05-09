param(
    [Parameter(Mandatory)][string]$EventFile
)

$scriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$templateFile = Join-Path $scriptDir "template.txt"
$mapFile      = Join-Path $scriptDir "field_map.json"
$outputDir    = Join-Path $scriptDir "output"

# --- Validate inputs ---
if (-not (Test-Path $EventFile))    { Write-Error "Event file not found: $EventFile"; exit 1 }
if (-not (Test-Path $templateFile)) { Write-Error "template.txt not found in script directory."; exit 1 }
if (-not (Test-Path $mapFile))      { Write-Error "field_map.json not found in script directory."; exit 1 }

# --- Load data ---
$event    = Get-Content $EventFile -Raw | ConvertFrom-Json
$fieldMap = Get-Content $mapFile   -Raw | ConvertFrom-Json

$templateFields = Get-Content $templateFile |
    Where-Object { $_ -notmatch '^\s*#' -and $_ -match '\S' }

# --- Build ticket lines ---
$lines = @()
foreach ($displayName in $templateFields) {
    $jsonKey = $fieldMap.$displayName
    if (-not $jsonKey) {
        Write-Warning "No mapping found for field '$displayName' — skipping."
        continue
    }

    $value = $event.$jsonKey
    if ($null -eq $value) {
        Write-Warning "JSON key '$jsonKey' not present in event data — field '$displayName' will be blank."
        $value = ""
    }

    $lines += "${displayName}: $value"
    $lines += ""   # blank line separator
}

# Remove trailing blank line
if ($lines[-1] -eq "") { $lines = $lines[0..($lines.Length - 2)] }

# --- Write output ---
if (-not (Test-Path $outputDir)) { New-Item -ItemType Directory -Path $outputDir | Out-Null }

$timestamp  = Get-Date -Format "yyyyMMdd_HHmmss"
$outputFile = Join-Path $outputDir "ticket_$timestamp.txt"

$lines | Set-Content $outputFile -Encoding UTF8
Write-Host "Ticket written to: $outputFile"
