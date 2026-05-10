param(
    [Parameter(Mandatory)][string]$EventFile
)

$scriptDir    = Split-Path -Parent $MyInvocation.MyCommand.Path
$templateFile = Join-Path $scriptDir "template.txt"
$outputDir    = Join-Path $scriptDir "output"

if (-not (Test-Path $EventFile))    { Write-Error "Event file not found: $EventFile"; exit 1 }
if (-not (Test-Path $templateFile)) { Write-Error "template.txt not found in script directory."; exit 1 }

$json = Get-Content $EventFile -Raw | ConvertFrom-Json

# Support both Elasticsearch-wrapped exports (_source present) and raw source JSON
if ($json._source -ne $null) {
    $source = $json._source
    $root   = $json
} else {
    $source = $json
    $root   = $null
}

$templateFields = Get-Content $templateFile |
    Where-Object { $_ -notmatch '^\s*#' -and $_ -match '\S' }

function Get-NestedValue($obj, $pathParts) {
    $current = $obj
    foreach ($part in $pathParts) {
        if ($current -eq $null) { return $null }
        $current = $current.($part)
    }
    return $current
}

function Format-Timestamp($str) {
    if ($str -match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}') {
        try {
            $styles = [System.Globalization.DateTimeStyles]::RoundtripKind
            $dt = [datetime]::Parse($str, $null, $styles)
            return $dt.ToLocalTime().ToString('MMMM d, yyyy @ HH:mm:ss.fff')
        } catch { }
    }
    return $str
}

function Format-Value($value) {
    if ($value -eq $null) { return '' }
    if ($value -is [array]) {
        $items = @()
        foreach ($item in $value) {
            $items += Format-Value $item
        }
        return $items -join ', '
    }
    if ($value -is [System.Management.Automation.PSCustomObject]) {
        $pairs = @()
        foreach ($prop in $value.PSObject.Properties) {
            $pairs += $prop.Name + '=' + $prop.Value
        }
        return $pairs -join '; '
    }
    return Format-Timestamp "$value"
}

$lines = @()

foreach ($field in $templateFields) {
    $pathParts = $field -split '\.'

    $raw = Get-NestedValue $source $pathParts

    # Fall back to root level for fields like _id, _index, _score
    if ($raw -eq $null -and $root -ne $null) {
        $raw = Get-NestedValue $root $pathParts
    }

    if ($raw -eq $null) {
        Write-Warning "Field '$field' not found - leaving blank."
    }

    $lines += $field + ': ' + (Format-Value $raw)
    $lines += ''
}

# Remove trailing blank line
if ($lines.Count -gt 0 -and $lines[$lines.Count - 1] -eq '') {
    $lines = $lines[0..($lines.Count - 2)]
}

if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

$timestamp  = Get-Date -Format 'yyyyMMdd_HHmmss'
$outputFile = Join-Path $outputDir ('ticket_' + $timestamp + '.txt')

$lines | Set-Content $outputFile -Encoding UTF8
Write-Host ('Ticket written to: ' + $outputFile)
