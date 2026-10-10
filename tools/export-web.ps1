param([string]$Godot = "$env:LOCALAPPDATA/Foldrunner/tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe")
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path $PSScriptRoot -Parent
$templatesPath = Join-Path $env:APPDATA 'Godot/export_templates/4.7.2.stable/web_nothreads_release.zip'
if (-not (Test-Path -LiteralPath $templatesPath)) {
    throw 'Web templates missing. Download the official 4.7.2-stable export_templates.tpz and run python tools/install_web_templates.py <archive>.'
}
$outputPath = Join-Path $projectPath 'builds/web/index.html'
New-Item -ItemType Directory -Path (Split-Path $outputPath -Parent) -Force | Out-Null
Set-Content -LiteralPath (Join-Path (Split-Path $outputPath -Parent) '.gdignore') -Value ''
$diagnostics = & $Godot --headless --path $projectPath --export-release Web $outputPath 2>&1
$diagnostics | ForEach-Object { Write-Output $_ }
if ($LASTEXITCODE -ne 0 -or ($diagnostics -join "`n") -match 'SCRIPT ERROR:|ERROR:') { throw 'Web export failed; see diagnostics above.' }
Write-Output "Web build: $outputPath"
Write-Output 'Serve builds/web over HTTP before opening it. Opening a browser uses the GPU.'
