$ErrorActionPreference = "Stop"
Write-Host "Creating C:\src directory..." -ForegroundColor Cyan
if (-not (Test-Path "C:\src")) {
    New-Item -ItemType Directory -Path "C:\src" -Force | Out-Null
}

$flutterZipPath = "$env:TEMP\flutter.zip"
$flutterUrl = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.29.0-stable.zip"

Write-Host "Downloading Flutter SDK (this may take a few minutes)..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $flutterUrl -OutFile $flutterZipPath

Write-Host "Extracting Flutter SDK..." -ForegroundColor Cyan
if (Test-Path "C:\src\flutter") {
    Remove-Item "C:\src\flutter" -Recurse -Force
}
Expand-Archive -Path $flutterZipPath -DestinationPath "C:\src" -Force

Write-Host "Adding Flutter to User PATH..." -ForegroundColor Cyan
$oldPath = [Environment]::GetEnvironmentVariable("Path", "User")
$flutterBin = "C:\src\flutter\bin"

if ($oldPath -notmatch [regex]::Escape($flutterBin)) {
    $newPath = $oldPath + ";" + $flutterBin
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    Write-Host "Flutter added to User PATH successfully." -ForegroundColor Green
} else {
    Write-Host "Flutter is already in User PATH." -ForegroundColor Yellow
}

Write-Host "Cleaning up..." -ForegroundColor Cyan
Remove-Item $flutterZipPath -Force

Write-Host "Flutter SDK Installation Complete!" -ForegroundColor Green
