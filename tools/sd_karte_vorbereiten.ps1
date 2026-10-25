# Bereitet eine SD-Karte / einen Stick für den ROG Ally X vor:
# 1. formatiert das Laufwerk auf NTFS (Armoury Crate meldet bei exFAT-Karten vom PC oft „Ungültiges Dateiformat“)
# 2. kopiert die aktuelle Spiel-EXE aus export/windows als ScrapEmpire\ScrapEmpire.exe
# 3. legt Startskripte und LIES-MICH.txt dazu
# 4. wirft das Laufwerk sicher aus
# Aufruf (im Projektordner):  pwsh -File tools/sd_karte_vorbereiten.ps1 -Drive E
# ACHTUNG: Alles auf dem Laufwerk wird gelöscht.
param(
	[string]$Drive = "E",
	[switch]$NoFormat   # nur kopieren, nicht formatieren
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$Drive = $Drive.TrimEnd(":", "\").ToUpper()
if (-not (Test-Path "${Drive}:\")) { throw "Laufwerk ${Drive}: ist nicht eingebunden. Karte einstecken und noch einmal starten." }

$exe = Get-ChildItem (Join-Path $root "export\windows") -Filter "ScrapEmpire_v*.exe" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $exe) { throw "Keine EXE in export/windows gefunden. Erst build.ps1 ausführen." }
Write-Host "Nehme $($exe.Name)"

if (-not $NoFormat) {
	$disk = Get-Partition -DriveLetter $Drive | Get-Disk
	if ($disk.BusType -notin @("USB", "SD", "MMC")) { throw "Laufwerk ${Drive}: hängt an $($disk.BusType), nicht an USB/SD. Abbruch zur Sicherheit." }
	Write-Host "Formatiere ${Drive}: ($([math]::Round($disk.Size/1GB,1)) GB, $($disk.FriendlyName)) auf NTFS ..."
	Format-Volume -DriveLetter $Drive -FileSystem NTFS -NewFileSystemLabel "SCRAPEMPIRE" -Confirm:$false | Out-Null
}

$dir = "${Drive}:\ScrapEmpire"
New-Item -ItemType Directory -Force $dir | Out-Null
Copy-Item $exe.FullName (Join-Path $dir "ScrapEmpire.exe") -Force

$ascii = [System.Text.Encoding]::ASCII
[System.IO.File]::WriteAllText((Join-Path $dir "Scrap Empire starten.bat"), "@echo off`r`ncd /d `"%~dp0`"`r`nstart `"`" `"%~dp0ScrapEmpire.exe`"`r`n", $ascii)
[System.IO.File]::WriteAllText((Join-Path $dir "Scrap Empire starten (Kompatibilitaet).bat"), "@echo off`r`ncd /d `"%~dp0`"`r`nstart `"`" `"%~dp0ScrapEmpire.exe`" --rendering-method gl_compatibility`r`n", $ascii)
[System.IO.File]::WriteAllText((Join-Path $dir "Scrap Empire mit Log starten.bat"), "@echo off`r`ncd /d `"%~dp0`"`r`n`"%~dp0ScrapEmpire.exe`" --verbose > `"%~dp0log.txt`" 2>&1`r`necho Log liegt in log.txt`r`npause`r`n", $ascii)

$readme = @"
SCRAP EMPIRE $($exe.BaseName.Replace('ScrapEmpire_', '')) - Start auf dem ROG Ally X
==============================================

1. Ordner "ScrapEmpire" von der Karte auf den Ally kopieren (z. B. nach C:\Spiele\ScrapEmpire).
   Von der Karte aus starten geht auch, ist aber langsamer.

2. "ScrapEmpire.exe" im Windows-Explorer doppelt antippen (nicht in Armoury Crate).

3. Wenn Windows meldet "Der Computer wurde durch Windows geschuetzt":
   auf "Weitere Informationen" tippen, dann "Trotzdem ausfuehren".
   Das kommt, weil die EXE nicht signiert ist.

4. Wenn das Spiel gar nicht aufgeht oder nur kurz ein schwarzes Fenster zeigt:
   "Scrap Empire starten (Kompatibilitaet).bat" verwenden (OpenGL statt Vulkan).

5. Wenn es immer noch nicht laeuft:
   "Scrap Empire mit Log starten.bat" ausfuehren und log.txt an Claude schicken.

Steuerung: Controller wird automatisch erkannt (A/B/X/Y, Sticks, LB/RB, Select = Menue, Start = Pause).
WICHTIG: In Armoury Crate den Controller auf GAMEPAD-Modus stellen, nicht Desktop-Modus.
Im Desktop-Modus klickt A wie eine Maus und bestaetigt nichts. Erkennbar an der Hinweisleiste
unten im Spiel: "Stick / RT / Y" = richtig, "WASD / LMB / Tab" = Desktop-Modus.
Spielstand: automatisch alle 60 Sekunden und beim Beenden, unter
%APPDATA%\Godot\app_userdata\Scrap Empire\saves
"@
[System.IO.File]::WriteAllText((Join-Path $dir "LIES-MICH.txt"), $readme, (New-Object System.Text.UTF8Encoding $false))

Write-Host "Inhalt von ${dir}:"
Get-ChildItem $dir | ForEach-Object { Write-Host ("  {0,-45} {1,12:N0} Bytes" -f $_.Name, $_.Length) }
$h1 = (Get-FileHash $exe.FullName -Algorithm SHA256).Hash
$h2 = (Get-FileHash (Join-Path $dir "ScrapEmpire.exe") -Algorithm SHA256).Hash
if ($h1 -ne $h2) { throw "Kopie stimmt nicht mit dem Original überein!" }
Write-Host "Kopie geprüft (SHA256 identisch)."

(New-Object -ComObject Shell.Application).NameSpace(17).ParseName("${Drive}:\").InvokeVerb("Eject")
Start-Sleep 3
if (Test-Path "${Drive}:\") { Write-Host "Bitte Laufwerk ${Drive}: über das Tray-Symbol auswerfen." } else { Write-Host "Laufwerk ${Drive}: sicher ausgeworfen. Karte kann in den Ally." }
