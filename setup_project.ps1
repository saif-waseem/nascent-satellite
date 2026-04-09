$ErrorActionPreference = "Continue"

Write-Host "Setting up project dependencies..." -ForegroundColor Cyan

# Update PATH for this session just in case
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

$root = (Get-Location).Path
$pubspecFiles = Get-ChildItem -Path "$root\ecommerce_saas" -Filter "pubspec.yaml" -Recurse

foreach ($file in $pubspecFiles) {
    if ($file.DirectoryName -match "\\build\\|\.dart_tool|\.symlinks") {
        continue
    }
    Write-Host "Running 'flutter pub get' in $($file.DirectoryName)..." -ForegroundColor Yellow
    Set-Location $file.DirectoryName
    flutter pub get
}

Set-Location $root
Write-Host "All dependencies installed!" -ForegroundColor Green
