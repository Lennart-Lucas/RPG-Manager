# Builds Flutter web and copies it to backend/static/web for the API Docker image.
$ErrorActionPreference = "Stop"

$backendRoot = Split-Path $PSScriptRoot -Parent
$repoRoot = Split-Path $backendRoot -Parent
$frontendRoot = Join-Path $repoRoot "frontend"
$webOut = Join-Path $frontendRoot "build\web"
$staticWeb = Join-Path $backendRoot "static\web"

$flutter = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutter) {
    throw "flutter is not on PATH. Install Flutter and ensure 'flutter' works in this shell."
}

if (-not (Test-Path (Join-Path $frontendRoot "pubspec.yaml"))) {
    throw "Frontend not found at $frontendRoot"
}

Write-Host "==> Building Flutter web (release, same-origin API)..."
Push-Location $frontendRoot
try {
    & flutter build web --release --dart-define=API_BASE_URL=
    if ($LASTEXITCODE -ne 0) {
        throw "flutter build web failed (exit code $LASTEXITCODE)."
    }
}
finally {
    Pop-Location
}

if (-not (Test-Path (Join-Path $webOut "index.html"))) {
    throw "Expected $webOut\index.html after flutter build web."
}

Write-Host "==> Copying web build to backend/static/web..."
if (Test-Path $staticWeb) {
    Remove-Item -Recurse -Force $staticWeb
}
New-Item -ItemType Directory -Path $staticWeb -Force | Out-Null
Copy-Item -Path (Join-Path $webOut "*") -Destination $staticWeb -Recurse -Force

if (-not (Test-Path (Join-Path $staticWeb "index.html"))) {
    throw "Copy failed: missing $staticWeb\index.html"
}

Write-Host "==> Web build ready at backend/static/web"
