param(
    [switch]$Force = $false
)

<#
    Setup Environment Script
    
    Generates c_cpp_properties.json from config.json settings.
    This ensures IntelliSense paths are configured for your environment.
    
    Usage:
        .\setup-environment.ps1           # Normal run - skips if file exists
        .\setup-environment.ps1 -Force    # Overwrites existing c_cpp_properties.json
#>

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$configPath = Join-Path $scriptDir 'config.json'
$cppPropsPath = Join-Path $scriptDir 'c_cpp_properties.json'

# Load configuration
if(-not (Test-Path $configPath)) {
    Write-Host "ERROR: config.json not found at $configPath"
    Write-Host "Please ensure you're running this from the .vscode directory."
    exit 1
}

$config = Get-Content $configPath | ConvertFrom-Json

if(-not $config.metaTraderTerminalId) {
    Write-Host "ERROR: metaTraderTerminalId not found in config.json"
    Write-Host "Please add your Terminal ID (format: XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX)"
    exit 1
}

# Check if file exists
if((Test-Path $cppPropsPath) -and -not $Force) {
    Write-Host "c_cpp_properties.json already exists."
    Write-Host "Use -Force flag to regenerate: .\setup-environment.ps1 -Force"
    exit 0
}

# Build include path
$appDataPath = $env:APPDATA
$includePath = "$appDataPath\MetaQuotes\Terminal\$($config.metaTraderTerminalId)\MQL5\Include"

# Check if path exists
if(-not (Test-Path $includePath)) {
    Write-Host "WARNING: MQL5 include path not found at:"
    Write-Host "  $includePath"
    Write-Host ""
    Write-Host "Verify your Terminal ID in config.json is correct."
    Write-Host "You can find it in MetaTrader settings or Windows Explorer:"
    Write-Host "  %APPDATA%\MetaQuotes\Terminal\[TERMINAL_ID]\MQL5\Include"
    Write-Host ""
}

# Create c_cpp_properties.json object
$cppProps = @{
    "configurations" = @(
        @{
            "name" = "MQL5"
            "includePath" = @(
                "`${workspaceFolder}/**",
                $includePath
            )
            "defines" = @(
                "_WIN32",
                "UNICODE",
                "_UNICODE",
                "__MQL5__"
            )
            "cppStandard" = "c++17"
            "intelliSenseMode" = "windows-msvc-x64"
        }
    )
    "version" = 4
}

# Write file
$cppProps | ConvertTo-Json -Depth 10 | Set-Content -Path $cppPropsPath -Encoding UTF8

Write-Host "✓ c_cpp_properties.json generated successfully"
Write-Host ""
Write-Host "Include path configured:"
Write-Host "  $includePath"
Write-Host ""
Write-Host "VS Code will now provide IntelliSense for MQL5 code."
Write-Host "If IntelliSense doesn't appear, restart VS Code."
