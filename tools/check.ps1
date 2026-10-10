param([string]$Godot = "$env:LOCALAPPDATA/Foldrunner/tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe")
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path $PSScriptRoot -Parent
if (-not (Test-Path -LiteralPath $Godot)) { throw 'Godot missing. Run tools/setup.ps1 first, or pass -Godot with your engine path.' }
$importOutput = & $Godot --headless --path $projectPath --editor --import --quit 2>&1
$importOutput | ForEach-Object { Write-Output $_ }
if ($LASTEXITCODE -ne 0 -or ($importOutput -join "`n") -match 'SCRIPT ERROR:|ERROR:') { throw 'Headless import failed; see diagnostics above.' }
foreach ($suite in @('test_player', 'test_world', 'test_city', 'test_integration', 'test_traversal')) {
    & $Godot --headless --path $projectPath --script "res://tests/$suite.gd"
    if ($LASTEXITCODE -ne 0) { throw "$suite failed: $LASTEXITCODE" }
}
