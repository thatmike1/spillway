$ErrorActionPreference = 'Stop'
$version = '4.7.2-stable'
$engineDir = Join-Path $env:LOCALAPPDATA 'Foldrunner/tools/godot-4.7.2'
$enginePath = Join-Path $engineDir "Godot_v$($version)_win64_console.exe"
if (Test-Path -LiteralPath $enginePath) { Write-Output $enginePath; exit 0 }
New-Item -ItemType Directory -Path $engineDir -Force | Out-Null
$release = Invoke-RestMethod "https://api.github.com/repos/godotengine/godot/releases/tags/$version"
$asset = $release.assets | Where-Object name -EQ "Godot_v$($version)_win64.exe.zip" | Select-Object -First 1
if (-not $asset) { throw 'Pinned official Godot release asset unavailable.' }
$archivePath = Join-Path $engineDir 'godot.zip'
& curl.exe --location --fail --silent --show-error $asset.browser_download_url --output $archivePath
if ($LASTEXITCODE -ne 0) { throw 'Godot download failed.' }
if ($asset.digest -and $asset.digest.StartsWith('sha256:')) {
    $actual = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $asset.digest.Substring(7)) { throw 'Official release checksum mismatch.' }
}
Expand-Archive -LiteralPath $archivePath -DestinationPath $engineDir -Force
& $enginePath --headless --version
if ($LASTEXITCODE -ne 0) { throw 'Engine smoke check failed.' }
