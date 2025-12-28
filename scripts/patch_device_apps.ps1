<#
Patches the device_apps plugin in your local pub cache to remove the deprecated
`package="fr.g123k.deviceapps"` attribute and inject a namespace and compileSdk
so modern AGP versions can build.

Usage (from project root PowerShell):
  .\scripts\patch_device_apps.ps1    # makes changes, prints summary
  # then
  flutter clean
  flutter pub get
  flutter run

This script creates backups (*.bak) next to the files it modifies so you can revert.
#>

Set-StrictMode -Version Latest

$pubCacheRoot = Join-Path $env:USERPROFILE "AppData\Local\Pub\Cache\hosted\pub.dev"
if (-not (Test-Path $pubCacheRoot)) {
    Write-Error "Pub cache path not found: $pubCacheRoot"
    exit 1
}

# Find the device_apps folder (versioned dir like device_apps-2.2.0)
$deviceDir = Get-ChildItem -Path $pubCacheRoot -Directory | Where-Object { $_.Name -like 'device_apps*' } | Select-Object -First 1
if (-not $deviceDir) {
    Write-Error "device_apps package not found in pub cache ($pubCacheRoot). Run 'flutter pub get' first or check your pub cache location."
    exit 1
}

$devicePath = $deviceDir.FullName
Write-Host "Found device_apps at: $devicePath"

# Target files
$manifest = Join-Path $devicePath "android\src\main\AndroidManifest.xml"
$buildGroovy = Join-Path $devicePath "android\build.gradle"
$buildKts = Join-Path $devicePath "android\build.gradle.kts"

function Backup-File($path) {
    if (Test-Path $path) {
        $bak = "$path.bak"
        Copy-Item -Path $path -Destination $bak -Force
        Write-Host "Backed up: $path -> $bak"
        return $true
    }
    return $false
}

$modified = @()

# 1) Remove package="fr.g123k.deviceapps" from AndroidManifest.xml
if (Test-Path $manifest) {
    Backup-File $manifest | Out-Null
    $content = Get-Content $manifest -Raw -ErrorAction Stop
    if ($content -match 'package="fr\.g123k\.deviceapps"') {
        $new = $content -replace 'package="fr\.g123k\.deviceapps"', ''
        Set-Content -Path $manifest -Value $new -Encoding UTF8
        Write-Host "Patched AndroidManifest.xml: removed package attribute"
        $modified += $manifest
    } else {
        Write-Host "No package attribute found or already patched in AndroidManifest.xml"
    }
} else {
    Write-Warning "AndroidManifest.xml not found at expected location: $manifest"
}

# Helper to inject namespace / compileSdk into build files
function Patch-BuildGroovy($path) {
    if (-not (Test-Path $path)) { return }
    Backup-File $path | Out-Null
    $content = Get-Content $path -Raw -ErrorAction Stop
    $changed = $false

    # Add namespace if missing inside the android { block
    if ($content -match '(?ms)android\s*\{') {
        if ($content -notmatch '(?m)^\s*namespace\s+['""'`']') {
            $content = $content -replace '(?m)^\s*android\s*\{', "android {\n    namespace 'fr.g123k.deviceapps'"
            $changed = $true
            Write-Host "Inserted namespace into build.gradle"
        } else {
            Write-Host "namespace already set in build.gradle"
        }

        # Ensure compileSdkVersion is present (Groovy style)
        if ($content -notmatch '(?m)^\s*compileSdkVersion\s*\d+') {
            $content = $content -replace '(?m)^\s*android\s*\{', "android {\n    compileSdkVersion 36"
            $changed = $true
            Write-Host "Inserted compileSdkVersion into build.gradle"
        } else {
            Write-Host "compileSdkVersion already set in build.gradle"
        }
    }

    if ($changed) { Set-Content -Path $path -Value $content -Encoding UTF8; $modified += $path }
}

function Patch-BuildKts($path) {
    if (-not (Test-Path $path)) { return }
    Backup-File $path | Out-Null
    $content = Get-Content $path -Raw -ErrorAction Stop
    $changed = $false

    if ($content -match '(?ms)android\s*\{') {
        if ($content -notmatch '(?m)^\s*namespace\s*=') {
            # KTS style: namespace = "..."
            $content = $content -replace '(?m)^\s*android\s*\{', "android {\n    namespace = \"fr.g123k.deviceapps\""
            $changed = $true
            Write-Host "Inserted namespace into build.gradle.kts"
        } else { Write-Host "namespace already set in build.gradle.kts" }

        if ($content -notmatch '(?m)^\s*compileSdk\s*=\s*\d+') {
            $content = $content -replace '(?m)^\s*android\s*\{', "android {\n    compileSdk = 36"
            $changed = $true
            Write-Host "Inserted compileSdk into build.gradle.kts"
        } else { Write-Host "compileSdk already set in build.gradle.kts" }
    }

    if ($changed) { Set-Content -Path $path -Value $content -Encoding UTF8; $modified += $path }
}

Patch-BuildGroovy $buildGroovy
Patch-BuildKts $buildKts

if ($modified.Count -eq 0) {
    Write-Host "No files were modified. Either plugin already compatible or files not found."
} else {
    Write-Host "Modified files:" -ForegroundColor Green
    $modified | ForEach-Object { Write-Host " - $_" }
}

Write-Host "Done. Now run:`n flutter clean`n flutter pub get`n flutter run" -ForegroundColor Cyan
