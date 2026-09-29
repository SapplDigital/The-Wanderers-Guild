# Builds the external playtest package (M15): a release export plus the tester README and
# feedback form, zipped. Every tester gets the same zip.
#   powershell -ExecutionPolicy Bypass -File tools\package_playtest.ps1
# Needs the Godot 4.7.2 (mono) Windows export templates installed (Editor > Manage Export Templates).
param(
    [string]$Godot = "C:\Tools\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe"
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$build = Join-Path $root "export\windows"
$out = Join-Path $root "export\playtest"

New-Item -ItemType Directory -Force $build, $out | Out-Null
Remove-Item "$build\*" -Recurse -Force -ErrorAction SilentlyContinue

& $Godot --headless --path $root --export-release "Windows Playtest" "$build\WanderersGuild.exe"
if ($LASTEXITCODE -ne 0 -or -not (Test-Path "$build\WanderersGuild.exe")) { throw "export failed" }

Copy-Item "$root\docs\playtest\README.txt", "$root\docs\playtest\FEEDBACK.txt" $build
$commit = (git -C $root rev-parse --short HEAD).Trim()
$dirty = if (git -C $root status --porcelain) { "-dirty" } else { "" }
$zip = Join-Path $out ("WanderersGuild-playtest-{0}-{1}{2}.zip" -f (Get-Date -Format "yyyy-MM-dd"), $commit, $dirty)
Compress-Archive -Path "$build\*" -DestinationPath $zip -Force
Get-FileHash $zip -Algorithm SHA256 | Format-List Path, Hash
Write-Host "Package: $zip"
