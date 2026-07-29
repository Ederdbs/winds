# Installs VS Code, Docker Desktop (via Chocolatey) and Positron (via winget,
# since Positron has no Chocolatey package as of this writing).

param([switch]$SkipDocker)

. "$PSScriptRoot\_helpers.ps1"
. "$PSScriptRoot\..\config.ps1"

Write-Step "Installing IDEs"
$packages = $Config.Ides.ChocoPackages
if ($SkipDocker) { $packages = $packages | Where-Object { $_ -ne 'docker-desktop' } }
Invoke-ChocoInstall -Packages $packages

if (Test-CommandExists 'winget') {
    Write-Host "  Installing Positron via winget" -ForegroundColor Yellow
    winget install --id $Config.Ides.PositronWingetId --silent --accept-package-agreements --accept-source-agreements
} else {
    Write-Fail "winget not found -- install Positron manually from https://github.com/posit-dev/positron/releases"
}

Write-Ok "IDEs installed"
