# Baut die Windows-EXE nach export/windows/ScrapEmpire.exe (PCK eingebettet).
# Voraussetzung: Export-Templates 4.7.2 unter %APPDATA%\Godot\export_templates\4.7.2.stable\
$ErrorActionPreference = "Stop"
$godot = Join-Path $PSScriptRoot "Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
$outDir = Join-Path $PSScriptRoot "export\windows"
New-Item -ItemType Directory -Force $outDir | Out-Null

& $godot --headless --path $PSScriptRoot --import | Out-Null
& $godot --headless --path $PSScriptRoot --export-release "Windows Desktop" "export/windows/ScrapEmpire.exe"
if ($LASTEXITCODE -ne 0) { throw "Export fehlgeschlagen (Exit $LASTEXITCODE)" }

$exe = Join-Path $outDir "ScrapEmpire.exe"
if (-not (Test-Path $exe)) { throw "EXE wurde nicht erzeugt: $exe" }
$size = [math]::Round((Get-Item $exe).Length / 1MB, 1)
Write-Host "Build fertig: $exe ($size MB)"
