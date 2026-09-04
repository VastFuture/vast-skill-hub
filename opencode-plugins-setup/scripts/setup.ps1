# OpenCode Core Plugins One-Click Setup Script (Windows PowerShell)
$ErrorActionPreference = "Stop"

$configDir = Join-Path $HOME ".config\opencode"
Write-Host "🚀 [OpenCode Setup] Installing plugins to $configDir..." -ForegroundColor Cyan

if (!(Test-Path -LiteralPath $configDir)) {
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null
}

Set-Location -LiteralPath $configDir

# 1. Ensure package.json exists
$pkgJsonPath = Join-Path $configDir "package.json"
if (!(Test-Path -LiteralPath $pkgJsonPath)) {
    @{
        dependencies = @{
            "@opencode-ai/plugin" = "1.18.23"
        }
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $pkgJsonPath -Encoding UTF8
}

# 2. Install plugins via npm
Write-Host "📦 Installing plugin dependencies via npm..." -ForegroundColor Cyan
npm install opencode-runtime-fallback opencode-wecom-ping cc-adapter-v2 VastFuture/opencode-ralph-loop --save

# 3. Update opencode.json
$opencodeJsonPath = Join-Path $configDir "opencode.json"
$pluginsToAdd = @(
    "cc-adapter-v2",
    "opencode-runtime-fallback",
    "opencode-wecom-ping",
    "ralph-loop"
)

if (Test-Path -LiteralPath $opencodeJsonPath) {
    $raw = Get-Content -LiteralPath $opencodeJsonPath -Raw -Encoding UTF8
    $cfg = ConvertFrom-Json $raw
} else {
    $cfg = [PSCustomObject]@{
        '`$schema' = "https://opencode.ai/config.json"
        plugin = @()
    }
}

if ($null -eq $cfg.plugin) {
    $cfg | Add-Member -MemberType NoteProperty -Name "plugin" -Value @()
}

$existingPlugins = @($cfg.plugin)
foreach ($p in $pluginsToAdd) {
    if ($existingPlugins -notcontains $p) {
        $existingPlugins += $p
    }
}
$cfg.plugin = $existingPlugins

$cfg | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $opencodeJsonPath -Encoding UTF8
Write-Host "✅ Updated plugin list in opencode.json" -ForegroundColor Green

# 4. Create default fallback config if not present
$fallbackJsonPath = Join-Path $configDir "opencode-fallback.jsonc"
if (!(Test-Path -LiteralPath $fallbackJsonPath)) {
    $defaultFallback = @{
        "`$schema" = "https://opencode.ai/config.json"
        enabled = $true
        retry_on_errors = @(429, 500, 502, 503, 504)
        max_fallback_attempts = 10
        cooldown_seconds = 60
        timeout_seconds = 30
        notify_on_fallback = $true
        fallback_models = @()
    }
    $defaultFallback | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $fallbackJsonPath -Encoding UTF8
    Write-Host "✅ Created default opencode-fallback.jsonc" -ForegroundColor Green
}

Write-Host "🎉 All plugins installed successfully! Please restart OpenCode to take effect." -ForegroundColor Green
