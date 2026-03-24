param(
    [Parameter(Mandatory=$true)]
    [string]$Target
)

# Load configuration
$configPath = Join-Path $PSScriptRoot 'config.json'
if(-not (Test-Path $configPath)) {
    Write-Host "ERROR: config.json not found at $configPath"
    exit 1
}

$config = Get-Content $configPath | ConvertFrom-Json
$metaEditor = $config.metaTraderPath
$workspace = $PSScriptRoot | Split-Path -Parent
$log = Join-Path $workspace $config.logFile

if([string]::IsNullOrWhiteSpace($Target) -or -not $Target.ToLower().EndsWith('.mq5')) {
    Write-Host 'Active file is not an .mq5 file. Open an .mq5 file and run task again.'
    exit 1
}

if(-not (Test-Path $metaEditor)) {
    Write-Host "ERROR: MetaEditor not found at: $metaEditor"
    Write-Host "Please update the metaTraderPath in .vscode/config.json"
    exit 1
}

$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

$compileArg = '/compile:"' + $Target + '"'
$logArg = '/log:"' + $log + '"'

# Log header to file
Add-Content -Path $log -Value ('=' * 80)
Add-Content -Path $log -Value ("[$timestamp] Compile MQL5 File: $(Split-Path $Target -Leaf)")
Add-Content -Path $log -Value ('=' * 80)

Start-Process -FilePath $metaEditor -ArgumentList @($compileArg, $logArg) -Wait -NoNewWindow | Out-Null
Start-Sleep -Milliseconds 2000

if(Test-Path $log) {
    $output = Get-Content $log -Encoding Unicode
    $output
    
    # Log output to file
    $output | Add-Content -Path $log
    Add-Content -Path $log -Value ''
} else {
    Write-Host ('Compile log not found: ' + $log)
    Add-Content -Path $log -Value ('ERROR: Compile log not found: ' + $log)
    Add-Content -Path $log -Value ''
    exit 1
}
