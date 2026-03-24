$workspace = $PSScriptRoot | Split-Path -Parent

# Load configuration
$configPath = Join-Path $PSScriptRoot 'config.json'
if(-not (Test-Path $configPath)) {
    Write-Host "ERROR: config.json not found at $configPath"
    exit 1
}

$config = Get-Content $configPath | ConvertFrom-Json
$metaEditor = $config.metaTraderPath
$commonLog = Join-Path $workspace $config.logFile
$dirs = $config.sourceDirectories

if(-not (Test-Path $metaEditor)) {
    Write-Host "ERROR: MetaEditor not found at: $metaEditor"
    Write-Host "Please update the metaTraderPath in .vscode/config.json"
    exit 1
}

$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

$total = 0
$passed = 0
$failed = 0
$failedFiles = @()

# Log header to file
Add-Content -Path $commonLog -Value ('=' * 80)
Add-Content -Path $commonLog -Value ("[$timestamp] Compile All MQL5 Files")
Add-Content -Path $commonLog -Value ('=' * 80)

foreach($d in $dirs) {
    $dir = Join-Path $workspace $d
    if(-not (Test-Path $dir)) {
        Write-Host ('Directory not found: ' + $dir)
        continue
    }

    Get-ChildItem -Path $dir -Filter '*.mq5' -File | ForEach-Object {
        $currentFile = $_
        $total++
        $header = '===== Compiling: ' + $currentFile.Name + ' ====='
        Write-Host $header
        Add-Content -Path $commonLog -Value $header

        $compileArg = '/compile:"' + $currentFile.FullName + '"'
        $logArg = '/log:"' + $commonLog + '"'

        Start-Process -FilePath $metaEditor -ArgumentList @($compileArg, $logArg) -Wait -NoNewWindow | Out-Null
        Start-Sleep -Milliseconds 2000

        if(Test-Path $commonLog) {
            $logLines = Get-Content $commonLog -Encoding Unicode
            $logText = $logLines -join "`n"
            $resultLine = ($logLines | Where-Object { $_ -match '^Result:' } | Select-Object -First 1)
            $errorLines = ($logLines | Where-Object { $_ -match ': error ' })
            $genStart = ($logLines | Where-Object { $_ -match '^\s*: information: generating code$' } | Select-Object -First 1)
            $gen95 = ($logLines | Where-Object { $_ -match 'generating code 95%' } | Select-Object -First 1)
            $gen100 = ($logLines | Where-Object { $_ -match 'generating code 100%' } | Select-Object -First 1)

            if($logText -match 'Result:\s+(\d+)\s+errors,\s+(\d+)\s+warnings') {
                if([int]$matches[1] -eq 0) {
                    $passed++

                    if($genStart) { Write-Host $genStart; Add-Content -Path $commonLog -Value $genStart }
                    if($gen95) { Write-Host $gen95; Add-Content -Path $commonLog -Value $gen95 }
                    if($gen100) { Write-Host $gen100; Add-Content -Path $commonLog -Value $gen100 }
                    if($resultLine) { Write-Host $resultLine; Add-Content -Path $commonLog -Value $resultLine }
                    Write-Host ''; Add-Content -Path $commonLog -Value ''
                } else {
                    $failed++
                    if($errorLines.Count -gt 0) {
                        $errorLines | ForEach-Object { Write-Host $_; Add-Content -Path $commonLog -Value $_ }
                    }
                    if($resultLine) { Write-Host $resultLine; Add-Content -Path $commonLog -Value $resultLine }
                    Write-Host ''; Add-Content -Path $commonLog -Value ''

                    $firstError = ($errorLines | Select-Object -First 1)
                    $failedFiles += [PSCustomObject]@{
                        File = $currentFile.Name
                        Result = $(if($resultLine) { $resultLine } else { 'Result: unknown' })
                        Error = $(if($firstError) { $firstError } else { 'No explicit compiler error line found' })
                    }
                }
            } else {
                $failed++
                if($errorLines.Count -gt 0) {
                    $errorLines | ForEach-Object { Write-Host $_; Add-Content -Path $commonLog -Value $_ }
                }
                if($resultLine) { Write-Host $resultLine; Add-Content -Path $commonLog -Value $resultLine }
                Write-Host ''; Add-Content -Path $commonLog -Value ''

                $firstError = ($errorLines | Select-Object -First 1)
                $failedFiles += [PSCustomObject]@{
                    File = $currentFile.Name
                    Result = 'Result line not found'
                    Error = $(if($firstError) { $firstError } else { 'No explicit compiler error line found' })
                }
            }
        } else {
            $errorMsg = 'ERROR: Log file not created'
            Write-Host $errorMsg
            Add-Content -Path $commonLog -Value $errorMsg
            Write-Host ''; Add-Content -Path $commonLog -Value ''
            $failed++
            $failedFiles += [PSCustomObject]@{
                File = $currentFile.Name
                Result = 'Log file not created'
                Error = 'MetaEditor did not write compile.log for this file'
            }
        }
    }
}

Write-Host ('SUMMARY: Total=' + $total + ' Passed=' + $passed + ' Failed=' + $failed + "`n")

# Log summary to file
Add-Content -Path $commonLog -Value ('SUMMARY: Total=' + $total + ' Passed=' + $passed + ' Failed=' + $failed)

if($failedFiles.Count -gt 0) {
    Write-Host 'FAILED FILES:'
    Add-Content -Path $commonLog -Value 'FAILED FILES:'
    $failedFiles | ForEach-Object {
        $output = ('- ' + $_.File)
        Write-Host $output
        Add-Content -Path $commonLog -Value $output
        
        $result = ('  ' + $_.Result)
        Write-Host $result
        Add-Content -Path $commonLog -Value $result
        
        $error = ('  ' + $_.Error)
        Write-Host $error
        Add-Content -Path $commonLog -Value $error
    }
}
Add-Content -Path $commonLog -Value ''

if($failed -gt 0) { exit 1 }
