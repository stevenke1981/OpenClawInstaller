# 設定主控台輸出編碼為 UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ErrorActionPreference = "Stop"

# 定義路徑 (使用 Join-Path 以確保跨平台兼容性)
$ConfigDir = Join-Path $env:USERPROFILE ".openclaw"
$ConfigFile = Join-Path $ConfigDir "config.yaml"
$ExampleFile = Join-Path $ConfigDir "config.yaml.example"

# 如果設定檔不存在，複製範例設定
if (-not (Test-Path -Path $ConfigFile)) {
    Write-Host "📝 首次執行，正在建立預設設定檔..." -ForegroundColor Cyan
    
    if (Test-Path -Path $ExampleFile) {
        Copy-Item -Path $ExampleFile -Destination $ConfigFile
    } else {
        Write-Warning "找不到範例設定檔: $ExampleFile"
    }
    
    Write-Host "⚠️ 請編輯設定檔並填入您的 API Key: $ConfigFile" -ForegroundColor Yellow
}

# 確保目錄存在 (Force $true 等同於 mkdir -p)
New-Item -ItemType Directory -Force -Path (Join-Path $ConfigDir "logs") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $ConfigDir "data") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $ConfigDir "skills") | Out-Null

# 列印啟動資訊
Write-Host ""
Write-Host "🦞 OpenClaw Windows 環境" -ForegroundColor Magenta
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host "設定目錄: $ConfigDir"
Write-Host "日誌目錄: $(Join-Path $ConfigDir 'logs')"
Write-Host "技能目錄: $(Join-Path $ConfigDir 'skills')"
Write-Host "網關連接埠: 18789"
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host ""

# 執行傳入的命令
if ($args.Count -gt 0) {
    & $args
}
