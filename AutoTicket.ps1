param(
    [Parameter(Mandatory)][string]$EventFile
)

$scriptDir    = Split-Path -Parent $MyInvocation.MyCommand.Path
$templateFile = Join-Path $scriptDir "template.txt"
$outputDir    = Join-Path $scriptDir "output"

if (-not (Test-Path $EventFile))    { Write-Error "Event file not found: $EventFile"; exit 1 }
if (-not (Test-Path $templateFile)) { Write-Error "template.txt not found in script directory."; exit 1 }

$event = Get-Content $EventFile -Raw | ConvertFrom-Json

$templateFields = Get-Content $templateFile |
    Where-Object { $_ -notmatch '^\s*#' -and $_ -match '\S' }

# Walk a dot-notation path through a nested object
function Resolve-DotPath {
    param($obj, [string[]]$parts)
    $current = $obj
    foreach ($part in $parts) {
        if ($null -eq $current) { return $null }
        $current = $current.$part
    }
    return $current
}

function Get-EventValue {
    param($event, [string]$field)
    $parts = $field -split '\.'

    # 1. Most fields live under _source; table names are the direct traversal path
    $val = Resolve-DotPath $event._source $parts
    if ($null -ne $val) { return $val }

    # 2. Root-level fields: _id, _index, _score, _type, sort, isAnchor
    $val = Resolve-DotPath $event $parts
    if ($null -ne $val) { return $val }

    # 3. Elasticsearch 'fields' section stores some timestamps as single-element arrays
    if ($event.fields -and $null -ne $event.fields.$field) {
        return $event.fields.$field
    }

    return $null
}

function Format-Value {
    param($value)
    if ($null -eq $value) { return "" }

    if ($value -is [System.Management.Automation.PSCustomObject]) {
        $pairs = $value.PSObject.Properties | ForEach-Object { "$($_.Name)=$($_.Value)" }
        return ($pairs -join "; ")
    }

    if ($value -is [object[]]) {
        return ($value | ForEach-Object { Format-Value $_ }) -join ", "
    }

    return "$value"
}

$lines = [System.Collections.Generic.List[string]]::new()

foreach ($field in $templateFields) {
    $raw = Get-EventValue $event $field
    if ($null -eq $raw) {
        Write-Warning "Field '$field' not found in event data — leaving blank."
    }
    $lines.Add("${field}: $(Format-Value $raw)")
    $lines.Add("")
}

# Remove trailing blank line
if ($lines.Count -gt 0 -and $lines[$lines.Count - 1] -eq "") {
    $lines.RemoveAt($lines.Count - 1)
}

if (-not (Test-Path $outputDir)) { New-Item -ItemType Directory -Path $outputDir | Out-Null }

$timestamp  = Get-Date -Format "yyyyMMdd_HHmmss"
$outputFile = Join-Path $outputDir "ticket_$timestamp.txt"

$lines | Set-Content $outputFile -Encoding UTF8
Write-Host "Ticket written to: $outputFile"
