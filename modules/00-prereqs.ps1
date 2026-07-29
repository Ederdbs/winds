# Bootstraps Chocolatey (if missing) and installs baseline system tools.

. "$PSScriptRoot\_helpers.ps1"
. "$PSScriptRoot\..\config.ps1"

Write-Step "Checking prerequisites"

if (-not (Test-CommandExists 'choco')) {
    Write-Host "  Installing Chocolatey..." -ForegroundColor Yellow
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')
} else {
    Write-Skip "Chocolatey already installed"
}

Invoke-ChocoInstall -Packages $Config.Prereqs.ChocoPackages
Write-Ok "Prerequisites ready"
