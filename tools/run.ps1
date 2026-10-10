param([string]$Godot = "$env:LOCALAPPDATA/Foldrunner/tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe")
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path $PSScriptRoot -Parent
if (-not (Test-Path -LiteralPath $Godot)) { throw 'Godot missing. Run tools/setup.ps1 first, or pass -Godot with your engine path.' }
# This launches an interactive GPU-rendered game. Only run when ready to play.
& $Godot --path $projectPath --max-fps 60
