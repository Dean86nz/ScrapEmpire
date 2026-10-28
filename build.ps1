# Baut die Windows-EXE nach export/windows/ScrapEmpire_v<version>.exe (PCK eingebettet).
# Die Version kommt aus project.godot (config/version). Versionierte Namen vermeiden
# Sperren durch ein noch laufendes Spiel und erlauben mehrere Stände nebeneinander.
# Voraussetzung: Export-Templates 4.7.2 unter %APPDATA%\Godot\export_templates\4.7.2.stable\
$ErrorActionPreference = "Stop"
$godot = Join-Path $PSScriptRoot "Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
$outDir = Join-Path $PSScriptRoot "export\windows"
New-Item -ItemType Directory -Force $outDir | Out-Null

$projectFile = Join-Path $PSScriptRoot "project.godot"
$versionLine = Get-Content $projectFile | Where-Object { $_ -match '^config/version="(.+)"$' } | Select-Object -First 1
$version = if ($versionLine -match '"(.+)"') { $Matches[1] } else { "dev" }
# Seit MS55 zwei EXEs: Release (Steam, ohne Cheat-Menü) und Debug (mit Cheat-Menü, nur zum Testen).
& $godot --headless --path $PSScriptRoot --import | Out-Null
foreach ($kind in @("release", "debug")) {
	$exeName = if ($kind -eq "release") { "ScrapEmpire_v$version.exe" } else { "ScrapEmpire_v${version}_DEBUG.exe" }
	$exeRel = "export/windows/$exeName"
	& $godot --headless --path $PSScriptRoot "--export-$kind" "Windows Desktop" $exeRel
	if ($LASTEXITCODE -ne 0) { throw "Export ($kind) fehlgeschlagen (Exit $LASTEXITCODE)" }
	$exe = Join-Path $outDir $exeName
	if (-not (Test-Path $exe)) { throw "EXE wurde nicht erzeugt: $exe" }
	$size = [math]::Round((Get-Item $exe).Length / 1MB, 1)
	Write-Host "Build fertig ($kind): $exe ($size MB)"
}
