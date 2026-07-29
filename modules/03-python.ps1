# Installs Python, creates a project-local venv, and installs packages.
# First run installs from requirements.txt and freezes a lockfile;
# later runs restore from that lockfile for reproducibility.

. "$PSScriptRoot\_helpers.ps1"
. "$PSScriptRoot\..\config.ps1"

Write-Step "Installing Python"
Invoke-ChocoInstall -Packages $Config.Python.ChocoPackages

$venvPath = $Config.Python.VenvPath
if (-not (Test-Path $venvPath)) {
    Write-Host "  Creating virtual environment at $venvPath" -ForegroundColor Yellow
    python -m venv $venvPath
} else {
    Write-Skip "Virtual environment already exists at $venvPath"
}

$pip = Join-Path $venvPath 'Scripts\pip.exe'
$reqFile = "$PSScriptRoot\..\python\requirements.txt"
$lockFile = "$PSScriptRoot\..\python\requirements.lock.txt"

Write-Step "Installing Python packages"
if (Test-Path $lockFile) {
    Write-Host "  Installing from requirements.lock.txt (pinned)" -ForegroundColor Yellow
    & $pip install -r $lockFile
} else {
    Write-Host "  Installing from requirements.txt (first run)" -ForegroundColor Yellow
    & $pip install -r $reqFile
    & $pip freeze | Out-File -Encoding utf8 $lockFile
    Write-Ok "Pinned versions written to requirements.lock.txt -- commit it for reproducibility"
}

Write-Ok "Python environment ready ($venvPath)"
