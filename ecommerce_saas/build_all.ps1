# PowerShell Build Script for E-commerce SaaS
# Uses absolute paths throughout to avoid CWD issues
$ErrorActionPreference = "Continue"

$root = (Get-Location).Path
$exportDir = "C:\Users\fufhv\OneDrive\Desktop\AppBuilds"
if (-not (Test-Path $exportDir)) {
    New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
}

$userAppDir = "$root\apps\user_app"

function Invoke-IconRegen($logoPath) {
    Write-Host "Regenerating icons using $logoPath..." -ForegroundColor Yellow
    # Write icon config then regenerate
    $yaml = @"
flutter_launcher_icons:
  android: "launcher_icon"
  ios: false
  image_path: "$logoPath"
  min_sdk_android: 21
"@
    $yamlPath = "$userAppDir\flutter_launcher_icons.yaml"
    [System.IO.File]::WriteAllText($yamlPath, $yaml, [System.Text.Encoding]::UTF8)
    Set-Location $userAppDir
    flutter pub run flutter_launcher_icons:main
}

function Update-UserAppConfig($tenantId, $appId, $appName) {
    Write-Host "Updating Config to $tenantId ($appName)..." -ForegroundColor Yellow

    # 1. Overwrite app_config.dart
    $c1 = "class AppConfig {`n  static const String tenantId = '$tenantId';`n  static const int? defaultRegistrationPoints = null;`n}"
    [System.IO.File]::WriteAllText("$userAppDir\lib\core\config\app_config.dart", $c1, [System.Text.Encoding]::UTF8)

    # 2. Overwrite strings.xml (UTF-8 without BOM for Android)
    $xmlContent = "<?xml version=`"1.0`" encoding=`"utf-8`"?>`n<resources>`n    <string name=`"app_name`">$appName</string>`n</resources>"
    $xmlPath = [System.IO.Path]::Combine($userAppDir, "android", "app", "src", "main", "res", "values", "strings.xml")
    $utf8NoBOM = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($xmlPath, $xmlContent, $utf8NoBOM)

    # 3. Update build.gradle.kts applicationId
    $p2 = "$userAppDir\android\app\build.gradle.kts"
    $gradleContent = [System.IO.File]::ReadAllText($p2)
    $gradleContent = $gradleContent -replace 'applicationId = ".*"', "applicationId = `"$appId`""
    [System.IO.File]::WriteAllText($p2, $gradleContent, [System.Text.Encoding]::UTF8)
}

function Update-UserAppConfigIOS($appId, $appName) {
    Write-Host "Updating iOS Config to $appId ($appName)..." -ForegroundColor Yellow

    # 1. Update Info.plist Display Name
    $plistPath = "$userAppDir\ios\Runner\Info.plist"
    if (Test-Path $plistPath) {
        $plistContent = [System.IO.File]::ReadAllText($plistPath)
        # Regex to find <key>CFBundleDisplayName</key> followed by its <string> value
        $plistContent = $plistContent -replace '(<key>CFBundleDisplayName<\/key>\s*<string>)[^<]*(<\/string>)', "`$1$appName`$2"
        [System.IO.File]::WriteAllText($plistPath, $plistContent, [System.Text.Encoding]::UTF8)
    }

    # 2. Update project.pbxproj Bundle ID
    $pbxPath = "$userAppDir\ios\Runner.xcodeproj\project.pbxproj"
    if (Test-Path $pbxPath) {
        $pbxContent = [System.IO.File]::ReadAllText($pbxPath)
        $pbxContent = $pbxContent -replace 'PRODUCT_BUNDLE_IDENTIFIER = [^;]*;', "PRODUCT_BUNDLE_IDENTIFIER = $appId;"
        [System.IO.File]::WriteAllText($pbxPath, $pbxContent, [System.Text.Encoding]::UTF8)
    }
}

function Build-APK($exportName) {
    Write-Host "Building APK for $exportName..." -ForegroundColor Cyan
    Set-Location $userAppDir
    if (Test-Path "build\app\outputs\flutter-apk\app-release.apk") {
        Remove-Item "build\app\outputs\flutter-apk\app-release.apk"
    }
    flutter build apk --release --no-tree-shake-icons
    if (Test-Path "build\app\outputs\flutter-apk\app-release.apk") {
        Copy-Item "build\app\outputs\flutter-apk\app-release.apk" "$exportDir\$exportName.apk" -Force
        Write-Host "APK built and copied to $exportDir\$exportName.apk" -ForegroundColor Green
    }
    else {
        Write-Host "Build FAILED for $exportName" -ForegroundColor Red
        throw "Build Failed"
    }
}

function Install-APK($apkName) {
    Write-Host "Installing $apkName on device..." -ForegroundColor Magenta
    try {
        adb install -r "$exportDir\$apkName.apk"
        Write-Host "$apkName installed successfully." -ForegroundColor Green
    }
    catch {
        Write-Host "ADB install failed for ${apkName}: $_" -ForegroundColor Yellow
    }
}

# Unicode sequences for Arabic names to avoid encoding issues
$aniqaName = [char]0x0623 + [char]0x0646 + [char]0x064a + [char]0x0642 + [char]0x0629 + " " + [char]0x0645 + [char]0x062f + [char]0x064a + [char]0x0646 + [char]0x062a + [char]0x064a
$londonName = [char]0x062f + [char]0x0627 + [char]0x0631 + " " + [char]0x0644 + [char]0x0646 + [char]0x062f + [char]0x0646

# ============================================================
# 1. User App - Aniqa Madinati
# ============================================================
Set-Location $root
Invoke-IconRegen "assets/images/aniqa_logo.jpg"
Update-UserAppConfig "anegmadenty" "com.nascent.anegmadenty" $aniqaName
# Update-UserAppConfigIOS "com.nascent.anegmadenty" $aniqaName
Build-APK "UserApp-Aniqa"
Install-APK "UserApp-Aniqa"

# ============================================================
# 2. User App - Dar London
# ============================================================
Set-Location $root
Invoke-IconRegen "assets/images/landan_logo.png"
Update-UserAppConfig "landan" "com.nascent.darlandan" $londonName
# Update-UserAppConfigIOS "com.nascent.darlandan" $londonName
Build-APK "UserApp-London"
Install-APK "UserApp-London"

# ============================================================
# 3. Store Admin
# ============================================================
Set-Location $root
Write-Host "Building Store Admin Mobile App..." -ForegroundColor Cyan
Set-Location "$root\apps\store_admin"
flutter build apk --release --no-tree-shake-icons
if ($LASTEXITCODE -eq 0) {
    Copy-Item "build\app\outputs\flutter-apk\app-release.apk" "$exportDir\StoreAdmin.apk" -Force
    Install-APK "StoreAdmin"
}

# ============================================================
# 4. Super Admin
# ============================================================
Set-Location $root
Write-Host "Building Super Admin Mobile App..." -ForegroundColor Cyan
Set-Location "$root\apps\super_admin"
flutter build apk --release --no-tree-shake-icons
if ($LASTEXITCODE -eq 0) {
    Copy-Item "build\app\outputs\flutter-apk\app-release.apk" "$exportDir\SuperAdmin.apk" -Force
    Install-APK "SuperAdmin"
}

# ============================================================
# 5. POS App (Sales Program)
# ============================================================
Set-Location $root
Write-Host "Building POS Mobile App..." -ForegroundColor Cyan
Set-Location "$root\apps\pos_app"
flutter build apk --release --no-tree-shake-icons
if ($LASTEXITCODE -eq 0) {
    Copy-Item "build\app\outputs\flutter-apk\app-release.apk" "$exportDir\POS-App.apk" -Force
    Install-APK "POS-App"
}

# ============================================================
# 4. Reset to London (default config)
# ============================================================
Set-Location $root
Update-UserAppConfig "landan" "com.nascent.darlandan" $londonName
# Update-UserAppConfigIOS "com.nascent.darlandan" $londonName

Write-Host "All builds completed! APKs exported to: $exportDir" -ForegroundColor Green
Set-Location $root
