$scriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$templateDir = Join-Path $scriptDir "Templates"
$outputDir   = Join-Path $scriptDir "ticket output"
$configFile  = Join-Path $scriptDir "config.json"
$refDoc      = "TemplateRefrence.txt"

function Load-Config {
    if (Test-Path $configFile) {
        try { return Get-Content $configFile -Raw | ConvertFrom-Json } catch {}
    }
    return [PSCustomObject]@{ LastTemplate = "DefaultTemplate" }
}

function Save-Config($cfg) {
    $cfg | ConvertTo-Json | Set-Content $configFile -Encoding UTF8
}

$zwPattern = '[' + [char]0x200B + [char]0x200C + [char]0x200D + [char]0xFEFF + [char]0x00AD + ']'

function Get-NestedValue($obj, $pathParts) {
    $current = $obj
    foreach ($part in $pathParts) {
        if ($null -eq $current) { return $null }
        $current = $current.$part
    }
    return $current
}

function Format-Timestamp($str) {
    if ($str -match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}') {
        try {
            $styles = [System.Globalization.DateTimeStyles]::RoundtripKind
            $dt = [datetime]::Parse($str, $null, $styles)
            return $dt.ToLocalTime().ToString('MMMM d, yyyy @ HH:mm:ss.fff')
        } catch {}
    }
    return $str
}

function Format-Value($value) {
    if ($null -eq $value) { return '' }
    if ($value -is [array]) {
        $items = @()
        foreach ($item in $value) { $items += Format-Value $item }
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

function Get-TemplateFields($templatePath) {
    return Get-Content $templatePath -Encoding UTF8 |
        Where-Object { $_ -notmatch '^\s*#' -and $_ -match '\S' } |
        ForEach-Object { ($_ -replace $zwPattern, '').Trim() }
}

function Get-Templates {
    if (-not (Test-Path $templateDir)) { return @() }
    return Get-ChildItem -Path $templateDir -File |
        Where-Object { $_.Name -ne $refDoc } |
        Sort-Object Name
}

function New-Ticket($templateName) {
    $templatePath = Join-Path $templateDir $templateName

    $clipText = Get-Clipboard -Raw
    if (-not $clipText -or $clipText.Trim() -eq '') {
        Write-Host "`nClipboard is empty." -ForegroundColor Yellow
        Read-Host "Press Enter to continue"
        return
    }

    $json = $null
    try { $json = $clipText | ConvertFrom-Json } catch {
        Write-Host "`nClipboard does not contain valid JSON." -ForegroundColor Red
        Read-Host "Press Enter to continue"
        return
    }

    if ($null -ne $json._source) {
        $source = $json._source
        $root   = $json
    } else {
        $source = $json
        $root   = $null
    }

    $templateFields    = Get-TemplateFields $templatePath
    $populatedLines    = @()
    $unpopulatedFields = @()

    foreach ($field in $templateFields) {
        $pathParts = $field -split '\.'
        $raw = Get-NestedValue $source $pathParts
        if ($null -eq $raw -and $null -ne $root) {
            $raw = Get-NestedValue $root $pathParts
        }
        if ($null -eq $raw) {
            $unpopulatedFields += $field
        } else {
            $populatedLines += $field + ': ' + (Format-Value $raw)
            $populatedLines += ''
        }
    }

    $lines = @()
    $lines += $populatedLines
    if ($lines.Count -gt 0 -and $lines[-1] -eq '') {
        $lines = $lines[0..($lines.Count - 2)]
    }

    if ($unpopulatedFields.Count -gt 0) {
        $lines += ''
        $lines += ''
        $lines += 'Unpopulated Fields:'
        $lines += ''
        foreach ($field in $unpopulatedFields) {
            $lines += $field + ': '
            $lines += ''
        }
        if ($lines[-1] -eq '') { $lines = $lines[0..($lines.Count - 2)] }
    }

    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir | Out-Null
    }

    $timestamp  = Get-Date -Format 'yyyyMMdd_HHmmss'
    $outputFile = Join-Path $outputDir ('ticket_' + $timestamp + '.txt')
    $lines | Set-Content $outputFile -Encoding UTF8
    Write-Host "`nTicket saved to: $outputFile" -ForegroundColor Green

    $copy = Read-Host "Copy ticket to clipboard? (y/n)"
    if ($copy -eq 'y' -or $copy -eq 'Y') {
        ($lines -join "`n") | Set-Clipboard
        Write-Host "Copied to clipboard." -ForegroundColor Green
    }
    Read-Host "Press Enter to continue"
}

function Select-Template {
    $templates  = Get-Templates
    if ($templates.Count -eq 0) {
        Write-Host "`nNo templates found in: $templateDir" -ForegroundColor Yellow
        Read-Host "Press Enter to continue"
        return $null
    }

    $pageSize   = 8
    $page       = 0
    $totalPages = [math]::Ceiling($templates.Count / $pageSize)

    while ($true) {
        Clear-Host
        Write-Host "Select Template  (Page $($page + 1) of $totalPages)"
        Write-Host "---------------------------------------------"

        $start         = $page * $pageSize
        $end           = [math]::Min($start + $pageSize, $templates.Count) - 1
        $pageTemplates = $templates[$start..$end]

        for ($i = 0; $i -lt $pageTemplates.Count; $i++) {
            Write-Host "$($i + 1)) $($pageTemplates[$i].Name)"
        }

        Write-Host ""
        if ($page -lt ($totalPages - 1)) { Write-Host "9) Next page" }
        if ($page -gt 0)                 { Write-Host "0) Previous page" }
        Write-Host "B) Back"
        Write-Host ""

        $choice = Read-Host "Select"

        if ($choice -eq 'B' -or $choice -eq 'b') { return $null }
        if ($choice -eq '9' -and $page -lt ($totalPages - 1)) { $page++; continue }
        if ($choice -eq '0' -and $page -gt 0)                 { $page--; continue }

        $idx = 0
        if ([int]::TryParse($choice, [ref]$idx) -and $idx -ge 1 -and $idx -le $pageTemplates.Count) {
            return $pageTemplates[$idx - 1].Name
        }

        Write-Host "Invalid selection." -ForegroundColor Yellow
        Start-Sleep -Milliseconds 600
    }
}

$config = Load-Config

while ($true) {
    Clear-Host
    Write-Host "AutoTicket"
    Write-Host "=========="
    Write-Host "Template: $($config.LastTemplate)"
    Write-Host ""
    Write-Host "1) Paste from clipboard and create ticket"
    Write-Host "2) Select template"
    Write-Host "3) Open template folder"
    Write-Host "4) Quit"
    Write-Host ""

    $choice = Read-Host "Select option"

    switch ($choice) {
        '1' {
            $tPath = Join-Path $templateDir $config.LastTemplate
            if (-not (Test-Path $tPath)) {
                Write-Host "`nTemplate '$($config.LastTemplate)' not found. Use option 2 to select a template." -ForegroundColor Red
                Read-Host "Press Enter to continue"
            } else {
                New-Ticket $config.LastTemplate
            }
        }
        '2' {
            $selected = Select-Template
            if ($selected) {
                $config.LastTemplate = $selected
                Save-Config $config
                Write-Host "`nTemplate set to: $selected" -ForegroundColor Green
                Start-Sleep -Milliseconds 800
            }
        }
        '3' {
            Invoke-Item $templateDir
        }
        '4' { exit }
    }
}
