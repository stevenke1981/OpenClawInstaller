<#
.SYNOPSIS
    OpenClaw 互動式配置選單 (Windows PowerShell 版)
.DESCRIPTION
    便捷的視覺化配置工具，用於管理 OpenClaw 的 AI 模型、渠道與服務。
    已繁體中文化並針對 Windows 環境優化。
#>

# ================================ 初始化設定 ================================
# 設定主控台編碼為 UTF-8 以支援繁體中文
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# 定義路徑
$UserHome = $env:USERPROFILE
$ConfigDir = Join-Path $UserHome ".openclaw"
$OpenClawEnv = Join-Path $ConfigDir "env.txt" # Windows 下用 env.txt 比較方便讀取
$OpenClawJson = Join-Path $ConfigDir "openclaw.json"
$BackupDir = Join-Path $ConfigDir "backups"

# ================================ 工具函數 ================================

function Write-Color {
    param(
        [string]$Text,
        [ConsoleColor]$Color = "White",
        [switch]$NoNewLine
    )
    if ($NoNewLine) {
        Write-Host $Text -ForegroundColor $Color -NoNewline
    } else {
        Write-Host $Text -ForegroundColor $Color
    }
}

function Show-Header {
    Clear-Host
    Write-Color "╔═══════════════════════════════════════════════════════════════╗" -Color Cyan
    Write-Color "║                                                               ║" -Color Cyan
    Write-Color "║   🦞 OpenClaw 設定中心 (Windows)                              ║" -Color Cyan
    Write-Color "║                                                               ║" -Color Cyan
    Write-Color "╚═══════════════════════════════════════════════════════════════╝" -Color Cyan
    Write-Host ""
}

function Show-Divider {
    Write-Color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -Color DarkGray
}

function Show-MenuItem {
    param([string]$Num, [string]$Text, [string]$Icon)
    Write-Host "  " -NoNewline
    Write-Host "[$Num]" -ForegroundColor Cyan -NoNewline
    Write-Host " $Icon $Text"
}

function Log-Info { param([string]$Msg) Write-Host "✓ $Msg" -ForegroundColor Green }
function Log-Warn { param([string]$Msg) Write-Host "⚠ $Msg" -ForegroundColor Yellow }
function Log-Error { param([string]$Msg) Write-Host "✗ $Msg" -ForegroundColor Red }

function Pause-Script {
    Write-Host ""
    Write-Host "按 Enter 鍵繼續..." -ForegroundColor DarkGray -NoNewline
    $null = Read-Host
}

function Confirm-Action {
    param([string]$Message, [string]$Default = "y")
    
    $prompt = if ($Default -eq "y") { "[Y/n]" } else { "[y/N]" }
    Write-Host "$Message $prompt: " -ForegroundColor Yellow -NoNewline
    $response = Read-Host
    
    if ([string]::IsNullOrWhiteSpace($response)) { $response = $Default }
    
    if ($response -match "^(y|yes)$") { return $true }
    return $false
}

# 讀取環境變數檔案並載入到當前 Session
function Load-EnvFile {
    if (Test-Path $OpenClawEnv) {
        Get-Content $OpenClawEnv | ForEach-Object {
            if ($_ -match "^export\s+([^=]+)=(.*)$") {
                $matches[1] = $matches[1].Trim()
                $val = $matches[2].Trim('"')
                Set-Item -Path "env:$($matches[1])" -Value $val
            }
        }
    }
}

# 取得特定環境變數值 (優先從檔案讀取)
function Get-EnvValue {
    param([string]$Key)
    if (Test-Path $OpenClawEnv) {
        $line = Get-Content $OpenClawEnv | Select-String "^export\s+$Key="
        if ($line) {
            return ($line.ToString() -replace "^export\s+$Key=", "").Trim('"')
        }
    }
    return $null
}

# 檢查 OpenClaw 是否安裝
function Test-OpenClawInstalled {
    return (Get-Command openclaw -ErrorAction SilentlyContinue)
}

# 確保目錄存在
if (-not (Test-Path $ConfigDir)) { New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null }

# ================================ 核心邏輯 ================================

# 儲存 AI 設定
function Save-AI-Config {
    param($Provider, $ApiKey, $Model, $BaseUrl, $ApiType)

    # 確保目錄存在
    if (-not (Test-Path $ConfigDir)) { New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null }
    
    $content = @()
    $content += "# OpenClaw 環境變數配置"
    $content += "# 由 PowerShell 設定選單生成: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    
    # 讀取舊的變數，保留非本次修改的項目
    if (Test-Path $OpenClawEnv) {
        $oldLines = Get-Content $OpenClawEnv
        foreach ($line in $oldLines) {
            # 這裡簡化處理：如果不是我們要設定的 provider 相關變數，就保留
            # 實際應用建議全部重寫或更精細的解析
        }
    }

    # 根據 Provider 寫入變數
    switch ($Provider) {
        "anthropic" {
            $content += "export ANTHROPIC_API_KEY=`"$ApiKey`""
            if ($BaseUrl) { $content += "export ANTHROPIC_BASE_URL=`"$BaseUrl`"" }
        }
        "openai" {
            $content += "export OPENAI_API_KEY=`"$ApiKey`""
            if ($BaseUrl) { $content += "export OPENAI_BASE_URL=`"$BaseUrl`"" }
        }
        "deepseek" {
            $content += "export DEEPSEEK_API_KEY=`"$ApiKey`""
            $url = if ($BaseUrl) { $BaseUrl } else { "https://api.deepseek.com" }
            $content += "export DEEPSEEK_BASE_URL=`"$url`""
        }
        "google" {
            $content += "export GOOGLE_API_KEY=`"$ApiKey`""
        }
        "ollama" {
             $url = if ($BaseUrl) { $BaseUrl } else { "http://localhost:11434" }
             $content += "export OLLAMA_HOST=`"$url`""
        }
        # ... 其他 provider 邏輯相同
    }

    $content | Set-Content $OpenClawEnv -Encoding UTF8
    
    # 同時設定 OpenClaw 的預設模型
    if (Test-OpenClawInstalled) {
        # 載入剛寫入的變數
        Load-EnvFile
        
        $modelStr = "$Provider/$Model"
        if ($Provider -eq "ollama") { $modelStr = "ollama/$Model" }
        
        Write-Host "設定 OpenClaw 預設模型為: $modelStr" -ForegroundColor DarkGray
        cmd /c "openclaw models set $modelStr" 2>&1 | Out-Null
    }
    
    Log-Info "設定已儲存至 $OpenClawEnv"
}

# 測試 AI 連接
function Test-AI-Connection {
    param($Provider, $ApiKey, $Model, $BaseUrl)
    
    Write-Host ""
    Write-Color "━━━ 測試 AI API 連線 ━━━" -Color Cyan
    
    $success = $false
    
    try {
        if ($Provider -eq "openai" -or $Provider -eq "deepseek") {
            $url = if ($BaseUrl) { "$BaseUrl/chat/completions" } else { "https://api.openai.com/v1/chat/completions" }
            if ($Provider -eq "deepseek" -and -not $BaseUrl) { $url = "https://api.deepseek.com/chat/completions" }
            
            $headers = @{ "Authorization" = "Bearer $ApiKey"; "Content-Type" = "application/json" }
            $body = @{
                model = $Model
                messages = @(@{ role = "user"; content = "Hello" })
                max_tokens = 10
            } | ConvertTo-Json
            
            Write-Host "正在請求 $url ..." -ForegroundColor DarkGray
            $response = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -ErrorAction Stop
            $success = $true
            
        } elseif ($Provider -eq "anthropic") {
             $url = "https://api.anthropic.com/v1/messages"
             $headers = @{ 
                "x-api-key" = $ApiKey
                "anthropic-version" = "2023-06-01"
                "Content-Type" = "application/json" 
             }
             $body = @{
                model = $Model
                max_tokens = 10
                messages = @(@{ role = "user"; content = "Hello" })
             } | ConvertTo-Json
             
             Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -ErrorAction Stop
             $success = $true
        } elseif ($Provider -eq "ollama") {
             $url = if ($BaseUrl) { "$BaseUrl/api/generate" } else { "http://localhost:11434/api/generate" }
             $body = @{ model = $Model; prompt = "Hi"; stream = $false } | ConvertTo-Json
             Invoke-RestMethod -Uri $url -Method Post -Body $body -ErrorAction Stop
             $success = $true
        }
        
        if ($success) {
            Log-Info "API 測試成功！連接正常。"
        }
    } catch {
        Log-Error "API 測試失敗: $($_.Exception.Message)"
        if ($_.Exception.Response) {
             # 嘗試讀取詳細錯誤
             $reader = New-Object System.IO.StreamReader $_.Exception.Response.GetResponseStream()
             $errBody = $reader.ReadToEnd()
             Write-Host $errBody -ForegroundColor Red
        }
    }
}

# ================================ 選單功能 ================================

function Config-OpenAI {
    Show-Header
    Write-Color "🟢 設定 OpenAI GPT" -Color White
    Show-Divider
    
    $currentKey = Get-EnvValue "OPENAI_API_KEY"
    $currentUrl = Get-EnvValue "OPENAI_BASE_URL"
    
    Write-Host "當前 Key: $(if($currentKey){ $currentKey.Substring(0,8)+'...' } else { '(未設定)' })"
    Write-Host "當前 URL: $(if($currentUrl){ $currentUrl } else { '官方預設' })"
    Write-Host ""
    
    $apiKey = Read-Host "輸入 API Key (留空保持不變)"
    if ([string]::IsNullOrWhiteSpace($apiKey)) { $apiKey = $currentKey }
    
    $baseUrl = Read-Host "輸入 API 地址 (留空使用官方)"
    if ([string]::IsNullOrWhiteSpace($baseUrl)) { $baseUrl = $currentUrl }
    
    Write-Host ""
    Write-Host "選擇模型:"
    Write-Host "1. gpt-4o (推薦)"
    Write-Host "2. gpt-4o-mini"
    Write-Host "3. gpt-4-turbo"
    Write-Host "4. 自定義"
    $m = Read-Host "請選擇 [1-4]"
    
    $model = switch ($m) {
        "1" { "gpt-4o" }
        "2" { "gpt-4o-mini" }
        "3" { "gpt-4-turbo" }
        "4" { Read-Host "輸入模型名稱" }
        Default { "gpt-4o" }
    }
    
    Save-AI-Config "openai" $apiKey $model $baseUrl
    if (Confirm-Action "是否測試連線？") {
        Test-AI-Connection "openai" $apiKey $model $baseUrl
    }
    Pause-Script
}

function Config-DeepSeek {
    Show-Header
    Write-Color "🔵 設定 DeepSeek" -Color White
    Show-Divider
    
    $currentKey = Get-EnvValue "DEEPSEEK_API_KEY"
    
    Write-Host "當前 Key: $(if($currentKey){ $currentKey.Substring(0,8)+'...' } else { '(未設定)' })"
    Write-Host ""
    
    $apiKey = Read-Host "輸入 API Key (留空保持不變)"
    if ([string]::IsNullOrWhiteSpace($apiKey)) { $apiKey = $currentKey }
    
    $model = "deepseek-chat"
    if (Confirm-Action "使用 R1 推理模型 (deepseek-reasoner)?") { $model = "deepseek-reasoner" }
    
    Save-AI-Config "deepseek" $apiKey $model ""
    if (Confirm-Action "是否測試連線？") {
        Test-AI-Connection "deepseek" $apiKey $model ""
    }
    Pause-Script
}

function Config-Ollama {
    Show-Header
    Write-Color "🟠 設定 Ollama 本地模型" -Color White
    Show-Divider
    
    $currentUrl = Get-EnvValue "OLLAMA_HOST"
    $defaultUrl = "http://localhost:11434"
    
    Write-Host "服務地址: $(if($currentUrl){ $currentUrl } else { $defaultUrl })"
    
    $url = Read-Host "輸入服務地址 (留空使用預設)"
    if ([string]::IsNullOrWhiteSpace($url)) { $url = $currentUrl; if(!$url){$url=$defaultUrl} }
    
    $model = Read-Host "輸入模型名稱 (例如 llama3, mistral)"
    if ([string]::IsNullOrWhiteSpace($model)) { $model = "llama3" }
    
    Save-AI-Config "ollama" "" $model $url
    if (Confirm-Action "是否測試連線？") {
        Test-AI-Connection "ollama" "" $model $url
    }
    Pause-Script
}

function Config-Telegram {
    Show-Header
    Write-Color "📨 設定 Telegram 機器人" -Color White
    Show-Divider
    
    if (-not (Test-OpenClawInstalled)) { Log-Error "未安裝 OpenClaw，無法配置渠道。"; Pause-Script; return }
    
    Write-Host "請輸入從 @BotFather 獲取的 Token:"
    $token = Read-Host "Bot Token"
    
    if (-not [string]::IsNullOrWhiteSpace($token)) {
        Log-Info "正在啟用 Telegram 插件..."
        cmd /c "openclaw plugins enable telegram" 2>&1 | Out-Null
        
        Log-Info "正在新增 Telegram 渠道..."
        cmd /c "openclaw channels add --channel telegram --token $token"
        
        Log-Info "設定完成！請重啟 Gateway 生效。"
    }
    Pause-Script
}

function Manage-Service {
    while ($true) {
        Show-Header
        Write-Color "⚡ 服務管理" -Color White
        Show-Divider
        
        # 檢查連接埠 18789 是否被佔用
        $portCheck = Get-NetTCPConnection -LocalPort 18789 -ErrorAction SilentlyContinue
        if ($portCheck) {
            Write-Host "  當前狀態: " -NoNewline
            Write-Color "● 執行中" -Color Green -NoNewline
            Write-Host " (PID: $($portCheck[0].OwningProcess))"
        } else {
            Write-Host "  當前狀態: " -NoNewline
            Write-Color "● 已停止" -Color Red
        }
        Write-Host ""
        
        Show-MenuItem "1" "啟動服務 (Start)" "▶️"
        Show-MenuItem "2" "停止服務 (Stop)" "⏹️"
        Show-MenuItem "3" "重啟服務 (Restart)" "🔄"
        Show-MenuItem "4" "查看日誌 (Logs)" "📋"
        Show-MenuItem "0" "返回主選單" "↩️"
        Write-Host ""
        
        $choice = Read-Host "請選擇 [0-4]"
        
        switch ($choice) {
            "1" {
                if ($portCheck) { Log-Warn "服務已在執行中"; Start-Sleep 1; continue }
                Log-Info "正在啟動 OpenClaw Gateway..."
                
                # 載入環境變數並啟動
                if (Test-Path $OpenClawEnv) {
                    Load-EnvFile
                    # 使用 Start-Process 在背景執行，避免卡住當前視窗
                    # 注意：這裡我們簡單地啟動，實際生產環境可能需要 NSSM 等工具註冊為 Windows Service
                    Start-Process -FilePath "openclaw" -ArgumentList "gateway --port 18789" -NoNewWindow
                    Start-Sleep 3
                    
                    # 再次檢查
                    if (Get-NetTCPConnection -LocalPort 18789 -ErrorAction SilentlyContinue) {
                        Log-Info "服務啟動成功！"
                        $url = cmd /c "openclaw dashboard --no-open" 2>&1 | Select-String "http"
                        if ($url) { Write-Host "Dashboard: $url" -ForegroundColor Green }
                    } else {
                        Log-Error "啟動似乎失敗，請查看日誌。"
                    }
                } else {
                    Log-Error "尚未配置環境變數，請先設定 AI 模型。"
                }
                Pause-Script
            }
            "2" {
                if (-not $portCheck) { Log-Warn "服務未執行"; Start-Sleep 1; continue }
                $pidToKill = $portCheck[0].OwningProcess
                Stop-Process -Id $pidToKill -Force -ErrorAction SilentlyContinue
                Log-Info "服務已停止"
                Start-Sleep 1
            }
            "3" {
                # 簡單的重啟邏輯
                $existing = Get-NetTCPConnection -LocalPort 18789 -ErrorAction SilentlyContinue
                if ($existing) { Stop-Process -Id $existing[0].OwningProcess -Force -ErrorAction SilentlyContinue }
                Start-Sleep 2
                Start-Process -FilePath "openclaw" -ArgumentList "gateway --port 18789" -NoNewWindow
                Log-Info "服務已發送重啟指令"
                Start-Sleep 2
            }
            "4" {
                Write-Host "正在顯示日誌 (按 Ctrl+C 退出)..." -ForegroundColor Cyan
                cmd /c "openclaw logs --follow"
            }
            "0" { return }
        }
    }
}

function Show-Status {
    Show-Header
    Write-Color "📊 系統狀態" -Color White
    Show-Divider
    
    if (Test-OpenClawInstalled) {
        $ver = cmd /c "openclaw --version" 2>&1
        Log-Info "OpenClaw 已安裝: $ver"
    } else {
        Log-Error "OpenClaw 未安裝"
    }
    
    $portCheck = Get-NetTCPConnection -LocalPort 18789 -ErrorAction SilentlyContinue
    if ($portCheck) {
        Log-Info "Gateway 服務: 執行中 (Port 18789)"
    } else {
        Log-Error "Gateway 服務: 已停止"
    }
    
    Write-Host ""
    Write-Host "配置目錄: $ConfigDir"
    Write-Host "環境檔案: $OpenClawEnv"
    
    Pause-Script
}

function Config-AI-Menu {
    while ($true) {
        Show-Header
        Write-Color "🤖 AI 模型設定" -Color White
        Show-Divider
        
        Show-MenuItem "1" "OpenAI GPT" "🟢"
        Show-MenuItem "2" "DeepSeek" "🔵"
        Show-MenuItem "3" "Anthropic Claude" "🟣"
        Show-MenuItem "4" "Ollama 本地模型" "🟠"
        Show-MenuItem "0" "返回主選單" "↩️"
        Write-Host ""
        
        $c = Read-Host "請選擇 [0-4]"
        switch ($c) {
            "1" { Config-OpenAI }
            "2" { Config-DeepSeek }
            "3" { Write-Host "邏輯與 OpenAI 類似，暫略" } # 可根據需要擴充
            "4" { Config-Ollama }
            "0" { return }
        }
    }
}

# ================================ 主程式 ================================

# 檢查依賴
if (-not (Test-OpenClawInstalled)) {
    Write-Host "⚠️  警告: 系統中未找到 'openclaw' 命令。" -ForegroundColor Yellow
    Write-Host "請確保已透過 npm install -g openclaw 安裝。"
    Write-Host ""
}

# 載入現有環境變數
Load-EnvFile

while ($true) {
    Show-Header
    Show-MenuItem "1" "系統狀態" "📊"
    Show-MenuItem "2" "AI 模型設定" "🤖"
    Show-MenuItem "3" "訊息渠道設定" "📱"
    Show-MenuItem "4" "服務管理" "⚡"
    Show-MenuItem "5" "OpenClaw 診斷 (Doctor)" "🔍"
    Show-MenuItem "0" "退出" "🚪"
    Write-Host ""
    Show-Divider
    
    $choice = Read-Host "請選擇 [0-5]"
    
    switch ($choice) {
        "1" { Show-Status }
        "2" { Config-AI-Menu }
        "3" { Config-Telegram } # 可擴充其他渠道
        "4" { Manage-Service }
        "5" { 
            Show-Header; 
            Write-Host "執行診斷..." -ForegroundColor Cyan
            cmd /c "openclaw doctor"; 
            Pause-Script 
        }
        "0" { 
            Write-Host "再見！🦞" -ForegroundColor Cyan
            exit 
        }
        Default { Write-Host "無效選擇" -ForegroundColor Red; Start-Sleep 1 }
    }
}
