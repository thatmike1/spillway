param(
    [string]$Godot = "$env:LOCALAPPDATA/Foldrunner/tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe",
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$GameArgs
)
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path $PSScriptRoot -Parent
if (-not (Test-Path -LiteralPath $Godot)) {
    & "$PSScriptRoot/setup.ps1"
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $Godot)) { throw 'Godot setup failed. Run tools/setup.ps1 or pass -Godot with your engine path.' }
}
# import scripts and resources before launching a fresh checkout.
$importOutput = & $Godot --headless --path $projectPath --editor --import --quit 2>&1
$importOutput | ForEach-Object { Write-Output $_ }
if ($LASTEXITCODE -ne 0 -or ($importOutput -join "`n") -match 'SCRIPT ERROR:|ERROR:') { throw 'Godot import failed; see diagnostics above.' }
& $Godot --path $projectPath --max-fps 120 @GameArgs
exit $LASTEXITCODE
