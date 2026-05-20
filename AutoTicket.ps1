param(
    [string]$EventFile
)

if (-not $EventFile) {
    $EventFile = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "PasteEventHere.json"
}

$scriptDir    = $PSScriptRoot
$templateFile = Join-Path $scriptDir "UserTemplate.txt"
$outputDir    = Join-Path $scriptDir "output"


if (-not (Test-Path $EventFile))    { Write-Error "Event file not found: $EventFile"; exit 1 }
if (-not (Test-Path $templateFile)) { Write-Error "UserTemplate.txt not found in script directory."; exit 1 }

$json = Get-Content $EventFile -Raw | ConvertFrom-Json

# Support both Elasticsearch-wrapped exports (_source present) and raw source JSON
if ($json._source -ne $null) {
    $source = $json._source
    $root   = $json
} else {
    $source = $json
    $root   = $null
}

$zwPattern = '[' + [char]0x200B + [char]0x200C + [char]0x200D + [char]0xFEFF + [char]0x00AD + ']'
$templateFields = Get-Content $templateFile -Encoding UTF8 |
    Where-Object { $_ -notmatch '^\s*#' -and $_ -match '\S' } |
    ForEach-Object { ($_ -replace $zwPattern, '' -replace '\r','').Trim() }


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

$populatedLines    = @()
$unpopulatedFields = @()

foreach ($field in $templateFields) {
    $pathParts = $field -split '\.'

    $raw = Get-NestedValue $source $pathParts

    # Fall back to root level for fields like _id, _index, _score
    if ($raw -eq $null -and $root -ne $null) {
        $raw = Get-NestedValue $root $pathParts
    }

    if ($raw -eq $null) {
        $unpopulatedFields += $field
    } else {
        $populatedLines += $field + ': ' + (Format-Value $raw)
        $populatedLines += ''
    }
}

$lines = @()

# Populated fields
$lines += $populatedLines
if ($lines.Count -gt 0 -and $lines[$lines.Count - 1] -eq '') {
    $lines = $lines[0..($lines.Count - 2)]
}

# Unpopulated fields section
if ($unpopulatedFields.Count -gt 0) {
    $lines += ''
    $lines += ''
    $lines += 'Unpopulated Fields:'
    $lines += ''
    foreach ($field in $unpopulatedFields) {
        $lines += $field + ': '
        $lines += ''
    }
    if ($lines[$lines.Count - 1] -eq '') {
        $lines = $lines[0..($lines.Count - 2)]
    }
}

if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

$timestamp  = Get-Date -Format 'yyyyMMdd_HHmmss'
$outputFile = Join-Path $outputDir ('ticket_' + $timestamp + '.txt')

$lines | Set-Content $outputFile -Encoding UTF8
Write-Host ('Ticket written to: ' + $outputFile)
