# PowerShell Build Script for E-commerce SaaS - Windows Desktop
# Uses absolute paths throughout to avoid CWD issues
$ErrorActionPreference = "Continue"

$root = (Get-Location).Path
$exportDir = "C:\Users\fufhv\OneDrive\Desktop\AppBuilds\Desktop"
if (-not (Test-Path $exportDir)) {
    New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
}

$userAppDir = "$root\apps\user_app"

function Update-UserAppConfig($tenantId, $appId, $appName) {
    Write-Host "Updating Config to $tenantId ($appName)..." -ForegroundColor Yellow

    # 1. Overwrite app_config.dart
    $c1 = "class AppConfig {`n  static const String tenantId = '$tenantId';`n  static const int? defaultRegistrationPoints = null;`n}"
    $configPath = "$userAppDir\lib\core\config\app_config.dart"
    if (Test-Path $configPath) {
        [System.IO.File]::WriteAllText($configPath, $c1, [System.Text.Encoding]::UTF8)
    }
}

function Build-Windows($appPath, $exportName) {
    Write-Host "----------------------------------------------------" -ForegroundColor Gray
    Write-Host "Building Windows Desktop for $exportName..." -ForegroundColor Cyan
    Write-Host "Path: $appPath" -ForegroundColor Gray
    
    $currentDir = Get-Location
    Set-Location $appPath
    
    # 1. Clean and get dependencies
    Write-Host "Running flutter clean..." -ForegroundColor Gray
    flutter clean | Out-Null
    Write-Host "Running flutter pub get..." -ForegroundColor Gray
    flutter pub get | Out-Null
    
    # 2. Build Windows Release
    Write-Host "Running flutter build windows..." -ForegroundColor Yellow
    flutter build windows --release --no-tree-shake-icons
    
    $buildOutDir = "$appPath\build\windows\x64\runner\Release"
    if (Test-Path $buildOutDir) {
        $targetDir = "$exportDir\$exportName"
        if (Test-Path $targetDir) { Remove-Item $targetDir -Recurse -Force }
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        
        Write-Host "Copying build to $targetDir..." -ForegroundColor Green
        Copy-Item -Path "$buildOutDir\*" -Destination $targetDir -Recurse -Force
        Write-Host "Build SUCCESS: $exportName" -ForegroundColor Green
    }
    else {
        Write-Host "Build FAILED for $exportName" -ForegroundColor Red
        # Don't throw here, continue with other builds
    }
    
    Set-Location $currentDir
}

# Unicode sequences for Arabic names to avoid encoding issues
$aniqaName = [char]0x0623 + [char]0x0646 + [char]0x064a + [char]0x0642 + [char]0x0629 + " " + [char]0x0645 + [char]0x062f + [char]0x064a + [char]0x0646 + [char]0x062a + [char]0x064a
$londonName = [char]0x062f + [char]0x0627 + [char]0x0631 + " " + [char]0x0644 + [char]0x0646 + [char]0x062f + [char]0x0646

# ============================================================
# 1. POS App
# ============================================================
Build-Windows "$root\apps\pos_app" "POS"

# ============================================================
# 2. Store Admin
# ============================================================
Build-Windows "$root\apps\store_admin" "StoreAdmin"

# ============================================================
# 3. Super Admin
# ============================================================
Build-Windows "$root\apps\super_admin" "SuperAdmin"

# ============================================================
# 4. User App - Aniqa Madinati
# ============================================================
Update-UserAppConfig "anegmadenty" "com.nascent.anegmadenty" $aniqaName
Build-Windows "$root\apps\user_app" "UserApp_Aniqa"

# ============================================================
# 5. User App - Dar London
# ============================================================
Update-UserAppConfig "landan" "com.nascent.darlandan" $londonName
Build-Windows "$root\apps\user_app" "UserApp_London"

Write-Host "====================================================" -ForegroundColor White
Write-Host "All Windows builds completed!" -ForegroundColor Green
Write-Host "Builds exported to: $exportDir" -ForegroundColor White
